import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/persistence/saved_match.dart';
import '../../core/statistics/match_record.dart';
import 'match_session.dart';

/// Writes the match in progress, and the record of a finished one.
///
/// Separated from the controller because it answers a different question: the
/// controller decides what the game does next, this decides what survives the
/// app being closed. It also keeps the controller free of the write
/// bookkeeping below.
///
/// Writes are coalesced rather than queued. A save is a complete picture of
/// the match, so when a newer one arrives while an older is still being
/// written, the older has nothing left to contribute and is dropped. The
/// alternative -- a queue -- would write every ply of a fast hand to disk in
/// order, all but the last of them already stale.
final class MatchPersistence {
  MatchPersistence(this._ref);

  final Ref _ref;

  SavedMatch? _pending;
  bool _writing = false;

  /// The save that would restore [session] right now.
  ///
  /// [nowMillis] is passed in rather than read here, so the one clock reading
  /// per write happens in the layer that is allowed to have one.
  static SavedMatch saveOf(
    MatchSession session,
    List<int> moves, {
    required int nowMillis,
  }) =>
      SavedMatch(
        matchId: session.matchId,
        ruleProfile: session.profile,
        dealSeed: session.dealSeed,
        savedAtEpochMillis: nowMillis,
        humanSeat: session.humanSeat,
        difficulty: session.difficulty,
        moves: moves,
        handsPlayed: session.match.handsPlayed,
        scores: session.match.totals,
      );

  /// The history entry for a finished [session].
  static MatchRecord recordOf(
    MatchSession session, {
    required int nowMillis,
  }) =>
      MatchRecord(
        matchId: session.matchId,
        modeId: session.profile.mode.id,
        profileId: session.profile.id,
        difficulty: session.difficulty,
        finishedAtEpochMillis: nowMillis,
        humanSeat: session.humanSeat,
        scores: session.match.totals,
        handsPlayed: session.match.handsPlayed,
        humanTricks: session.humanTricksTotal,
      );

  /// Stores [save], replacing any save not yet written.
  void scheduleSave(SavedMatch save) {
    _pending = save;
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_writing) {
      return;
    }
    _writing = true;
    try {
      while (_pending != null) {
        final SavedMatch save = _pending!;
        _pending = null;
        await _ref.read(matchArchiveProvider).save(save);
      }
      _ref.invalidate(savedMatchProvider);
    } on Object {
      // Storage failures must not reach the table. A match that cannot be
      // saved is still a match that can be played, and there is nothing the
      // player could do about a full disk mid-trick.
    } finally {
      _writing = false;
    }
  }

  /// Files [record] and drops the match in progress.
  ///
  /// Both happen together, and in that order: a finished match must never be
  /// left resumable, and a record that was written is never lost by the clear
  /// that follows failing.
  Future<void> recordFinished(MatchRecord record) async {
    _pending = null;
    try {
      await _ref.read(matchHistoryRepositoryProvider).append(record);
      _ref.invalidate(matchHistoryProvider);
    } on Object {
      // Statistics are a convenience; a failure here must not stop the table
      // from showing the result.
    }
    await clear();
  }

  /// Drops the match in progress, so nothing offers to resume it.
  Future<void> clear() async {
    _pending = null;
    try {
      await _ref.read(matchArchiveProvider).clear();
    } on Object {
      // Same reasoning as a failed write.
    }
    _ref.invalidate(savedMatchProvider);
  }
}
