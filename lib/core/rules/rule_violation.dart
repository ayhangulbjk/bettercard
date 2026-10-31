import 'package:meta/meta.dart';

/// Why the engine refused a command.
///
/// Codes, not sentences: the domain layer stays free of presentation, and the
/// UI maps each code to Turkish copy. That also keeps rejections comparable in
/// tests and countable in AI benchmarks (an agent that produces any
/// [RuleViolationCode] at all has a bug).
enum RuleViolationCode {
  /// It is a different seat's turn.
  notYourTurn,

  /// The seat does not hold the card it tried to play.
  cardNotInHand,

  /// The seat holds the lead suit and must follow it.
  mustFollowSuit,

  /// The seat is void in the lead suit and must play a trump.
  mustPlayTrump,

  /// The seat must beat the highest trump already in the trick.
  mustOvertrump,

  /// The seat must beat the highest lead-suit card already in the trick.
  mustBeatLeadSuit,

  /// Trump may not be led until it has been broken.
  trumpNotBroken,

  /// The command does not apply in the current phase (e.g. playing a card
  /// during the auction).
  wrongPhase,

  /// A bid outside the configured range, or not higher than the standing bid.
  invalidBid,

  /// A contract that is not available to this seat under its remaining quota.
  contractUnavailable,

  /// The wrong number of cards was buried, or a restricted card was buried.
  invalidBury,
}

/// A refused command, with optional machine-readable detail for diagnostics.
@immutable
class RuleViolation {
  const RuleViolation(this.code, {this.detail});

  final RuleViolationCode code;

  /// Developer-facing context. Never shown to players.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is RuleViolation && other.code == code && other.detail == detail;

  @override
  int get hashCode => Object.hash(code, detail);

  @override
  String toString() =>
      'RuleViolation(${code.name}${detail == null ? '' : ': $detail'})';
}
