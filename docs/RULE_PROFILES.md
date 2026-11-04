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
| `DeclarationRules` | Per-seat trick promises: what they stake, what extras pay, when extras bust |
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
| `mustBeatLeadSuitWhenPossible` | Following suit must beat the best card so far, if able (yukseltme zorunlu) |
| `trumpLeadRule: onlyAfterBroken` | Trump may not be led until trump has been played |

Every restriction yields when a seat cannot satisfy it: a trump-only hand may
lead trump even unbroken, and a seat that cannot overtrump may still play a low
trump. The legal move set is never empty for a non-empty hand, and that is
tested.

`mustBeatLeadSuitWhenPossible` has one further exemption, and it is not a
setting: **once the trick has been cut, the obligation to raise lapses.** If
diamonds are led and someone trumps with a spade, no diamond can win the trick
any more, so a seat holding diamonds may follow with any of them. Enforcing
the raise after a cut would make a player throw a high card away for nothing,
and no table plays it that way. The exemption lives in `TrickLegalMoves`
rather than in `TrickRules` because it depends on the trick in hand, not on
the rule set. It does not apply when trump is itself the lead suit -- raising
a trump lead is the overtrump rule.

## The five modes

### 1. Herkes Tek Ihaleli Batak (`auction_batak`)

Four players, each for themselves. 52 cards, 13 each, 13 tricks. Bids run 5 to
13; the auction winner names trump and must take at least its bid.

Preset `auction_batak_standard`: compulsory trump when void, compulsory
overtrump, declarer scores tricks taken, failure scores minus the bid, other
seats score one per trick, 8 hands.

### 2. Esli Ihaleli Batak (`partnership_batak`)

Seats 0+2 play against 1+3; partners sit opposite. Four things differ from
Herkes Tek Ihaleli, and every one of them would be a bug if carried across.

**The contract belongs to a side.** One seat wins the auction and names the
trump, but the tricks that count are the partnership's: its two hands add up.
Bids run 8 to 13, higher than the solo floor of 5, because two hands are
playing for them. A passed-out hand forces 7 on the seat that opened the
auction.

**Trump may be led from the first trick.** In the solo mode the declarer waits
for trump to be broken. Here it does not: drawing the opponents' trumps while
an open hand sits opposite is most of the plan. `TrickRules.partnershipBatak`
is `batakStandard` with the restriction lifted; see B-8.

**The defending side's floor is a team floor.** Two tricks *between* the
partners, not two each, and missing it costs the contract's value. The solo
mode's "yan batma" charges each defender separately and has no equivalent
here.

**Extras never sink a hand.** A declaring side that makes its contract scores
every trick it took. Koz Maca's "yan 3 batar" does not exist in this mode.

Two all-thirteen results sit above the ordinary payoff and are resolved before
it, never in addition to it:

| Result | Condition | Pays | Ends the match |
|---|---|---|---|
| KING | the whole hand bid **and** the whole hand taken | +13 / -13 | yes, by default |
| 13 yukari / 13 asagi | every trick to one side without having bid them all, from either side | +13 / -13 | no, by default |

Presets: `partnership_batak_open` (the default, acik esli) and
`partnership_batak_closed` (kapali esli). They differ in exactly one field --
`PartnershipRules.mode` -- and in nothing else.

#### The open hand

In acik esli, the declarer's partner lays its thirteen cards face up **after
the trump is named**, and the declarer plays them. Three things are kept
apart in the engine and must stay apart:

| Concept | Who | Where it lives |
|---|---|---|
| whose turn it is, and whose trick it becomes | the card's owner | `TrickPlayState.turnSeat` |
| who chooses the card | the declarer, for the open hand | `controllerOf` |
| whose hands the chooser may read | itself plus anything face up | `visibleHandsFor` |

Cards never move between hands. A trick the open hand wins is credited to the
open hand and led next from its seat.

The ordering is a fairness rule rather than a presentation detail: the
declarer names the trump without seeing what is opposite it, and
`isDummyRevealed` is derived from `trump != null` so the two facts cannot get
out of step. `checkInvariants` asserts it directly.

### 3. Koz Maca (`spades_batak`)

Four players, spades permanently trump, no auction. Trump may not be led until
broken.

Cutting is compulsory: a seat void in the lead suit must play a spade if it
holds one, and must overcut a spade already in the trick if it can
(`mustPlayTrumpWhenVoid` and `mustOvertrumpWhenPossible` are both on). This is
where Turkish Koz Maca parts company with international Spades, where a void
seat may discard freely. B-3 is settled in favour of the compulsory reading,
and both flags stay adjustable, so a table that plays the permissive reading
changes a setting rather than the code.

Raising is compulsory in the plain suits too (`mustBeatLeadSuitWhenPossible`,
"yukseltme zorunlu"): a seat following suit must beat the best card of that
suit already in the trick if it holds one. Diamond 5 led and a hand holding
the 3 and the 6 may only play the 6. The obligation ends the moment the trick
is cut -- see the exemption described under trick-play options -- so after a
spade lands on that diamond 5 either diamond is legal. B-5 is settled in
favour of the compulsory reading for Koz Maca; the auction modes still carry
the permissive default, pending the owner's word on them.

**Her el söz verilir.** Oyuncular kartlarını gördükten sonra, ilk kart
atılmadan önce sırayla kaç el alacaklarını söyler. Sıra, ilk eli açacak
oyuncudan başlar. Bu bir ihale değildir: kimse kimseyi artırmaz, dolayısıyla
`BiddingRules` değil `DeclarationRules` geçerlidir.

**Puanlama.** Söz başına 10 puan yazılır; bu yüzden masada "5 dedim" demek 50
puanı ortaya koymak demektir.

| Durum | Sonuç | Örnek |
|---|---|---|
| Sözünü tutar | +söz x 10, artı her yan için 1 puan | 5 dedi, 6 aldı: **51** |
| Sözünü tutamaz | -söz x 10 | 5 dedi, 3 aldı: **-50** |
| Çok yan toplar | -söz x 10 | 5 dedi, 8 aldı (3 yan): **-50** |
| "El almaz" tutar | +50 | hiç el almadı: **+50** |
| "El almaz" bozulur | -50 | bir el aldı: **-50** |

Sözün üstüne alınan fazla eller **yan**dır ve tanesi 1 puandır: 5 deyip 7 alan
52 yazar. Kaç yanda batılacağı masadan masaya değişir, bu yüzden oyun kurulum
ekranında seçilir (`overtrickBustThreshold`): varsayılan **3 yan**, seçenekler
2, 3, 4 ve "batmaz". Seçim o partinin kural profiline dondurulur, yani ayarı
sonradan değiştirmek süren bir partiyi etkilemez.

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
| B-4 | In three-player buried Batak, how many cards are buried, and do they score for the declarer? | One buried, credited to the declarer | `BuryRules` |
| B-6 | When everyone passes, is it a redeal or must the dealer bid? | Dealer must bid | `passOutRule` |
| B-7 | Does the maximum bid score as an all-or-nothing hand? | No | `maximumBidIsShootTheMoon` |
| B-8 | In Esli Batak, may trump be led before it is broken? | Yes, freely | `trumpLeadRule` |
| B-9 | Is Esli Batak played with the partner's hand open or closed? | Open (acik esli) | `PartnershipRules.mode` |
| B-10 | Should the forced contract be 7 when the voluntary floor is 8? | Yes, 7 -- but see below | `forcedBid` |
| K-1 | How many contracts does each player declare, and in what mix? | Koz x2 plus three penalties | `quotaPerPlayer` |
| K-2 | Are Rifki and Son Iki part of a standard match? | Available at quota 0 | `quotaPerPlayer` |
| K-3 | Exact point values per contract | See the table above | `pointsPerUnit` |
| K-5 | What does "el almaz" pay, and does a broken nil cost per trick? | +50 / -50, flat | `nilBonus` |
| K-6 | May the four declarations sum to the trick count? | Yes, nothing forbids it | none yet; would need a new flag |

### Resolved

The owner plays at a table that settles these, and the presets now follow it.
Each remains a setting, so a table that plays otherwise changes a profile
rather than the code.

| Id | Question | Answer | Setting |
|---|---|---|---|
| B-1 | Does a kept word score the tricks above it? | Yes: each extra ("yan") pays 1 on top of `soz x 10`, so 5 said and 7 taken writes 52 | `overtrickRule`, `pointsPerOvertrick` |
| B-2 | What does a broken word cost? | The same stake it would have paid: `soz x 10`. 5 said and missed is -50 | `pointsPerDeclaredTrick` |
| B-3 | Is trumping when void compulsory at every table? | Yes, in every mode including Koz Maca | `mustPlayTrumpWhenVoid` |
| B-5 | Must a seat following suit beat the best card so far? | Yes in Koz Maca, until the trick is cut. Still off in the auction modes, which are not playable yet | `mustBeatLeadSuitWhenPossible` |
| K-4 | Are tricks above a kept word worth anything (ciz / torba)? | Yes, 1 each -- **but** collecting too many sinks the hand. The number of extras that busts is chosen per match; the default is 3 | `overtrickBustThreshold` |

B-1 and B-2 were answered for the **declaration** round, which is the only
place either currently applies: Koz Maca has no auction, and the auction modes
are not playable yet. `BatakScoringRules.declarerSuccess` and
`declarerFailure` are therefore unchanged, and the auction's own payoff is
still to be confirmed with the owner before those modes are built.

### A measurement that B-10 should be read against

With the shipped defaults -- a floor of 8 and a forced 7 -- the bots pass out
**61% of hands** over 6,000 deals (`tool/checks/partnership_probe.dart`,
3,000 per mode). That is not timidity in the bidder. A contract nobody chose
is genuinely easier than the smallest one anybody may choose, so declining the
auction is the better play, and the bidder is reading the payoff correctly.

The rule set produces it, so the rule set is where it is recorded rather than
being tuned away in the AI. `RuleProfileValidator` raises
`partnership.forced_far_below_minimum` as a **warning** on any profile where
the forced contract is more than one below the floor, with the consequence
spelled out, and the setup screen shows it. A table that would rather see
fewer forced hands raises `forcedBid` to 8, or switches the pass-out rule, and
both are one tap away.

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
