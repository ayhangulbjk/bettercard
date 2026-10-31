import 'package:meta/meta.dart';

import '../rules/rule_violation.dart';
import 'game_command.dart';

/// The result of submitting a command to an engine.
@immutable
sealed class CommandOutcome<S> {
  const CommandOutcome();
}

/// The command was legal; [state] is the resulting snapshot.
final class CommandAccepted<S> extends CommandOutcome<S> {
  const CommandAccepted(this.state);

  final S state;
}

/// The command was refused and no state changed.
final class CommandRejected<S> extends CommandOutcome<S> {
  const CommandRejected(this.violation);

  final RuleViolation violation;
}

/// A deterministic, UI-free game engine over immutable state snapshots.
///
/// Contract for every implementation:
///
/// * `apply` is a pure function of `(state, command)` -- no clock, no
///   `dart:io`, no global randomness. Any randomness is carried inside the
///   state as a seeded generator snapshot, so a state plus a command list
///   replays identically on any machine.
/// * `apply` never mutates [state]; it returns a new snapshot.
/// * `apply` validates independently of whoever called it. Illegal input
///   returns [CommandRejected], never a thrown exception and never a corrupt
///   state. Broken *invariants* (as opposed to illegal player input) do throw,
///   because they are programming errors.
/// * `legalCommands` and `apply` agree: a command in the former is always
///   accepted by the latter from the same state.
abstract interface class GameEngine<S> {
  /// Every command [seat] may legally issue from [state].
  List<GameCommand> legalCommands(S state, int seat);

  /// Validates and applies [command].
  CommandOutcome<S> apply(S state, GameCommand command);

  /// Whether [state] is a finished position.
  bool isTerminal(S state);

  /// The seat due to act, or null when [state] is terminal or waiting on
  /// nobody.
  int? seatToAct(S state);
}
