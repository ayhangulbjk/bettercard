# Rule profiles

Turkish Batak is a family of house rules, not one game. King varies too,
especially in how many contracts a match contains. This project therefore
treats a rule set as **data** (`RuleProfile`) rather than code, ships
documented presets, validates every combination, and records what it does not
know instead of guessing.

**The standing rule: no invented rules.** Where sources disagree, the preset
takes the most commonly reported reading, the alternative stays available as a
setting, and the disagreement is logged below as an open question.

## How a profile is put together

| Part | Covers |
|---|---|
| `TrickRules` | Following suit, compulsory trump, overtrumping, trump leads |
| `BiddingRules` | Bid range, pass-out resolution, who names trump |
| `BatakScoringRules` | Declarer payoff and penalty, others' trick points, match end |
| `BuryRules` | Surplus cards, how many are buried, restrictions, who they score for |
| `KingRules` | Contract set, point values, per-player quotas (match length is derived) |
| `fixedTrump` | A trump set by the rules rather than chosen |
| `deckExclusions` | Reduced-deck variants |

`RuleProfileValidator` runs on every change. Errors block a match; warnings are
shown but allow play. Validation codes are stable strings so tests and the UI
can refer to them.

## Trick-play options

These are what actually differ between tables, and each changes the legal move
set.

| Flag | Effect when true |
|---|---|
| `mustFollowSuit` | Holding the lead suit obliges playing it |
| `mustPlayTrumpWhenVoid` | A void seat must trump if it can (koz kesme zorunlulugu) |
| `mustOvertrumpWhenPossible` | Trumping into a trumped trick must beat the best trump |
| `mustBeatLeadSuitWhenPossible` | Following suit must beat the best card so far, if able |
| `trumpLeadRule: onlyAfterBroken` | Trump may not be led until trump has been played |

Every restriction yields when a seat cannot satisfy it: a trump-only hand may
lead trump even unbroken, and a seat that cannot overtrump may still play a low
trump. The legal move set is never empty for a non-empty hand, and that is
tested.

## The five modes

### 1. Herkes Tek Ihaleli Batak (`auction_batak`)

Four players, each for themselves. 52 cards, 13 each, 13 tricks. Bids run 5 to
13; the auction winner names trump and must take at least its bid.

Preset `auction_batak_standard`: compulsory trump when void, compulsory
overtrump, declarer scores tricks taken, failure scores minus the bid, other
seats score one per trick, 8 hands.

### 2. Esli Ihaleli Batak (`partnership_batak`)

As above, but seats 0+2 play against 1+3 (partners sit opposite). Card play is
identical; the contract and the score belong to the partnership.

Preset `partnership_batak_standard`.

### 3. Koz Maca (`spades_batak`)

Four players, spades permanently trump, no auction. Trump may not be led until
broken.

Cutting is compulsory: a seat void in the lead suit must play a spade if it
holds one, and must overcut a spade already in the trick if it can
(`mustPlayTrumpWhenVoid` and `mustOvertrumpWhenPossible` are both on). This is
where Turkish Koz Maca parts company with international Spades, where a void
seat may discard freely. See open question B-3; both flags stay adjustable, so
a table that plays the permissive reading changes a setting rather than the
code.

Preset `spades_batak_standard`.

### 4. Uclu Gommeli Batak (`buried_batak`)

Three players on the **full 52-card deck**. 17 cards each uses 51, leaving one
over; the auction winner takes it and buries one, so every seat plays 17
tricks. Bids run 9 to 17.

The deck is deliberately not divisible by three. The surplus is what the bury
resolves, which is why the validator checks
`deckSize - playerCount * tricksPerHand == cardsToBury` rather than demanding
an even deck.

Preset `buried_batak_standard`, 6 hands.

### 5. King (`king`)

Four players, 13 tricks per hand, a match made of several contracts. Penalty
contracts are played without trump; only Koz has a trump.

| Contract | Turkish | Measures | Preset value |
|---|---|---|---|
| `trumpTricks` | Koz | Each trick taken | +50 |
| `noTricks` | El Almaz | Each trick taken | -50 |
| `queens` | Kiz Almaz | Each queen taken | -100 |
| `jacksAndKings` | Erkek Almaz | Each jack and king taken | -60 |
| `heartsKing` | Rifki | The king of hearts | -320 |
| `lastTwoTricks` | Son Iki | Each of the last two tricks | -180 |

**Match length is derived, not declared.** `KingRules.totalHands` is
`playerCount * sum(quotaPerPlayer)`. That is the only way a configurable
contract set can stay internally consistent, and it is why this app does not
assume the familiar 20-hand table.

- `king_classic_20`: Koz x2, El Almaz x1, Kiz Almaz x1, Erkek Almaz x1 per
  player = 20 hands. Rifki and Son Iki are present at quota 0 so the UI can
  offer them without silently changing the match length.
- `king_short_8`: Koz x1, El Almaz x1 per player = 8 hands.

The validator enforces the sign of each point value against the contract's
nature, so a penalty contract cannot be configured to pay.

## Open questions

These are real ambiguities. They are **not resolved** by this project; each has
a configurable setting and a documented default. The Turkish rules screen shows
them to players.

| Id | Question | Current default | Setting |
|---|---|---|---|
| B-1 | Does a declarer who takes more than its bid score the overtricks? | Yes, tricks taken | `declarerSuccess` |
| B-2 | Is a failed contract minus the bid, or double? | Minus the bid | `declarerFailure` |
| B-3 | Is trumping when void compulsory at every table? | Yes, in every mode including Koz Maca | `mustPlayTrumpWhenVoid` |
| B-4 | In three-player buried Batak, how many cards are buried, and do they score for the declarer? | One buried, credited to the declarer | `BuryRules` |
| B-5 | Must a seat following suit beat the best card so far? | No | `mustBeatLeadSuitWhenPossible` |
| B-6 | When everyone passes, is it a redeal or must the dealer bid? | Dealer must bid | `passOutRule` |
| B-7 | Does the maximum bid score as an all-or-nothing hand? | No | `maximumBidIsShootTheMoon` |
| K-1 | How many contracts does each player declare, and in what mix? | Koz x2 plus three penalties | `quotaPerPlayer` |
| K-2 | Are Rifki and Son Iki part of a standard match? | Available at quota 0 | `quotaPerPlayer` |
| K-3 | Exact point values per contract | See the table above | `pointsPerUnit` |

### How to resolve one

1. Confirm the custom with the players this build targets.
2. Change the preset's default, or add a second preset if both customs are
   common.
3. Add or adjust a validator rule if the change creates a new way to be
   inconsistent.
4. Update the table above and move the row out of "open".
5. Add a test in `test/unit/rule_validation_test.dart`.

A profile change needs a `schemaVersion` bump whenever an existing field is
reinterpreted, so old saves migrate explicitly rather than being
misinterpreted.
