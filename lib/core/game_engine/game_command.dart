import 'package:meta/meta.dart';

import '../cards/playing_card.dart';
import '../cards/suit.dart';

/// Every player- or AI-originated intent, as a validated command.
///
/// Nothing mutates game state except by passing one of these to an engine.
/// The engine re-validates each command against the authoritative state, so a
/// buggy UI or a buggy AI can produce a rejection but never an illegal game.
@immutable
sealed class GameCommand {
  const GameCommand({required this.seat});

  /// The seat issuing the command.
  final int seat;
}

/// Play [card] to the current trick.
final class PlayCardCommand extends GameCommand {
  const PlayCardCommand({required super.seat, required this.card});

  final PlayingCard card;

  @override
  bool operator ==(Object other) =>
      other is PlayCardCommand && other.seat == seat && other.card == card;

  @override
  int get hashCode => Object.hash(runtimeType, seat, card);

  @override
  String toString() => 'PlayCard(seat: $seat, card: $card)';
}

/// Bid [tricks] during an auction.
final class PlaceBidCommand extends GameCommand {
  const PlaceBidCommand({required super.seat, required this.tricks});

  final int tricks;

  @override
  bool operator ==(Object other) =>
      other is PlaceBidCommand && other.seat == seat && other.tricks == tricks;

  @override
  int get hashCode => Object.hash(runtimeType, seat, tricks);

  @override
  String toString() => 'PlaceBid(seat: $seat, tricks: $tricks)';
}

/// Decline to bid.
final class PassBidCommand extends GameCommand {
  const PassBidCommand({required super.seat});

  @override
  bool operator ==(Object other) =>
      other is PassBidCommand && other.seat == seat;

  @override
  int get hashCode => Object.hash(runtimeType, seat);

  @override
  String toString() => 'PassBid(seat: $seat)';
}

/// Name the trump suit after winning an auction. [trump] is null for a
/// no-trump declaration.
final class DeclareTrumpCommand extends GameCommand {
  const DeclareTrumpCommand({required super.seat, required this.trump});

  final Suit? trump;

  @override
  bool operator ==(Object other) =>
      other is DeclareTrumpCommand &&
      other.seat == seat &&
      other.trump == trump;

  @override
  int get hashCode => Object.hash(runtimeType, seat, trump);

  @override
  String toString() => 'DeclareTrump(seat: $seat, trump: ${trump?.name})';
}

/// Put [cards] face down out of play (three-player buried Batak).
final class BuryCardsCommand extends GameCommand {
  BuryCardsCommand({required super.seat, required List<PlayingCard> cards})
      : cards = List<PlayingCard>.unmodifiable(cards);

  final List<PlayingCard> cards;

  @override
  bool operator ==(Object other) =>
      other is BuryCardsCommand &&
      other.seat == seat &&
      other.cards.length == cards.length &&
      other.cards.every(cards.contains);

  @override
  int get hashCode => Object.hash(runtimeType, seat, Object.hashAll(cards));

  @override
  String toString() => 'BuryCards(seat: $seat, count: ${cards.length})';
}

/// Choose a King contract for the upcoming hand.
final class SelectContractCommand extends GameCommand {
  const SelectContractCommand({required super.seat, required this.contractId});

  /// Identifier of a `KingContract`, kept as a string so this command stays
  /// independent of King-specific enums.
  final String contractId;

  @override
  bool operator ==(Object other) =>
      other is SelectContractCommand &&
      other.seat == seat &&
      other.contractId == contractId;

  @override
  int get hashCode => Object.hash(runtimeType, seat, contractId);

  @override
  String toString() => 'SelectContract(seat: $seat, contract: $contractId)';
}
