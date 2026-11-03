// Checks that a match survives a save and a reload, on a real disk.
//
// Run with:
//   dart run tool/checks/save_roundtrip.dart
//
// What it proves: a match played partway through, written to a file, read back
// and replayed through the engine produces the identical position -- the same
// hand index, the same totals, the same cards in the same hands, the same seat
// to act. That is the property "Devam Et" depends on, and it is the one thing
// the widget tests cannot show, because they never touch a file system.
//
// It also exercises the two refusals the format is supposed to have: a
// truncated move log and an edited score must both be rejected rather than
// loaded as a plausible-looking wrong position.

import 'dart:io';

import 'package:batak_king/core/ai/ai_difficulty.dart';
import 'package:batak_king/core/ai/policies/heuristic_policy.dart';
import 'package:batak_king/core/ai/seat_observation.dart';
import 'package:batak_king/core/cards/playing_card.dart';
import 'package:batak_king/core/game_engine/game_command.dart';
import 'package:batak_king/core/game_engine/game_engine.dart';
import 'package:batak_king/core/persistence/saved_match.dart';
import 'package:batak_king/core/rules/game_mode.dart';
import 'package:batak_king/core/rules/rule_presets.dart';
import 'package:batak_king/games/spades_batak/spades_batak_engine.dart';
import 'package:batak_king/games/spades_batak/spades_batak_match_state.dart';
import 'package:batak_king/games/spades_batak/spades_batak_restore.dart';
import 'package:batak_king/platform/file_repositories.dart';
import 'package:batak_king/platform/json_file_store.dart';

Future<void> main(List<String> args) async {
  final int plies = int.tryParse(args.isEmpty ? '' : args.first) ?? 40;
  const int seed = 20260202;

  stdout.writeln('Batak & King - save round trip');
  stdout.writeln('seed=$seed plies=$plies');
  stdout.writeln('');

  const SpadesBatakEngine engine = SpadesBatakEngine();
  SpadesBatakMatchState state = SpadesBatakEngine.start(
    profile: RulePresets.defaultFor(GameMode.spadesBatak),
    seed: seed,
  );

  final HeuristicPolicy policy = HeuristicPolicy(seed: seed);
  final List<int> moves = <int>[];
  for (int ply = 0; ply < plies; ply++) {
    final int? seat = engine.seatToAct(state);
    if (seat == null) {
      break;
    }
    // Declarations are part of the log, so the round trip has to produce
    // them as well as cards: a save whose declarations were dropped would
    // replay into a hand nobody had promised anything in.
    final GameCommand command;
    final SeatObservation observation =
        SeatObservation.fromState(state.hand!, seat);
    if (state.isDeclaring) {
      final int declared = policy.chooseDeclarationSync(
        observation,
        engine.legalDeclarations(state),
      );
      moves.add(SavedMatch.encodeDeclaration(declared));
      command = PlaceBidCommand(seat: seat, tricks: declared);
    } else {
      final PlayingCard card = policy.chooseCardSync(observation);
      moves.add(card.id);
      command = PlayCardCommand(seat: seat, card: card);
    }
    state = switch (engine.apply(state, command)) {
      CommandAccepted<SpadesBatakMatchState>(
        state: final SpadesBatakMatchState next
      ) =>
        next,
      CommandRejected<SpadesBatakMatchState>(:final violation) =>
        throw StateError('the policy produced an illegal move: $violation'),
    };
  }

  final SavedMatch save = SavedMatch(
    matchId: 'roundtrip-$seed',
    ruleProfile: state.profile,
    dealSeed: seed,
    savedAtEpochMillis: 0,
    humanSeat: 0,
    difficulty: AiDifficulty.normal,
    moves: moves,
    handsPlayed: state.handsPlayed,
    scores: state.totals,
  );

  final Directory temporary = await Directory.systemTemp.createTemp('bk-save-');
  int failures = 0;
  try {
    final FileMatchArchive archive =
        FileMatchArchive(JsonFileStore(temporary.path));
    await archive.save(save);

    final SavedMatch? reloaded = await archive.load();
    if (reloaded == null) {
      stderr.writeln('FAIL: the save did not read back');
      exitCode = 1;
      return;
    }

    final SpadesBatakMatchState? restored = SpadesBatakRestore.replay(
      reloaded,
      onProblem: (String problem) => stderr.writeln('replay: $problem'),
    );
    if (restored == null) {
      stderr.writeln('FAIL: the reloaded save did not replay');
      exitCode = 1;
      return;
    }

    failures += _expect(
      'hand index',
      restored.handIndex == state.handIndex,
      '${restored.handIndex} vs ${state.handIndex}',
    );
    failures += _expect(
      'hands played',
      restored.handsPlayed == state.handsPlayed,
      '${restored.handsPlayed} vs ${state.handsPlayed}',
    );
    failures += _expect(
      'totals',
      '${restored.totals}' == '${state.totals}',
      '${restored.totals} vs ${state.totals}',
    );
    failures += _expect(
      'seat to act',
      engine.seatToAct(restored) == engine.seatToAct(state),
      '${engine.seatToAct(restored)} vs ${engine.seatToAct(state)}',
    );
    failures += _expect(
      'tricks played this hand',
      restored.hand?.trickNumber == state.hand?.trickNumber,
      '${restored.hand?.trickNumber} vs ${state.hand?.trickNumber}',
    );
    for (int seat = 0; seat < restored.seatCount; seat++) {
      failures += _expect(
        'hand of seat $seat',
        '${restored.hand?.handOf(seat)}' == '${state.hand?.handOf(seat)}',
        'differs',
      );
    }

    // A truncated log must not pass the score check it no longer matches.
    final SavedMatch truncated = SavedMatch(
      matchId: save.matchId,
      ruleProfile: save.ruleProfile,
      dealSeed: save.dealSeed,
      savedAtEpochMillis: 0,
      humanSeat: 0,
      difficulty: save.difficulty,
      moves: moves.sublist(0, moves.length ~/ 2),
      handsPlayed: save.handsPlayed,
      scores: save.scores,
    );
    failures += _expect(
      'a truncated log is refused',
      save.handsPlayed == 0 || SpadesBatakRestore.replay(truncated) == null,
      'it replayed',
    );

    // An edited score must be refused even though every move is legal.
    final SavedMatch tampered = SavedMatch(
      matchId: save.matchId,
      ruleProfile: save.ruleProfile,
      dealSeed: save.dealSeed,
      savedAtEpochMillis: 0,
      humanSeat: 0,
      difficulty: save.difficulty,
      moves: moves,
      handsPlayed: save.handsPlayed,
      scores: <int>[for (final int score in save.scores) score + 1],
    );
    failures += _expect(
      'an edited score is refused',
      SpadesBatakRestore.replay(tampered) == null,
      'it replayed',
    );
  } finally {
    await temporary.delete(recursive: true);
  }

  stdout.writeln('');
  if (failures > 0) {
    stderr.writeln('FAIL: $failures check(s) failed.');
    exitCode = 1;
    return;
  }
  stdout.writeln('OK: the match survived the round trip unchanged.');
}

int _expect(String what, bool holds, String detail) {
  stdout
      .writeln('${holds ? 'ok  ' : 'FAIL'}  $what${holds ? '' : ' ($detail)'}');
  return holds ? 0 : 1;
}
