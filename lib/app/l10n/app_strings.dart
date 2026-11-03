import '../../core/rules/auction_scoring_rules.dart';
import '../../core/rules/bidding_rules.dart';
import '../../core/rules/rule_violation.dart';

/// The application's user-visible text, as an interface.
///
/// Turkish ships first. Rather than hard-coding Turkish into widgets and
/// retrofitting localisation later, every string goes through this interface
/// from day one, so adding English means adding one implementation and a
/// locale switch -- not auditing every widget.
///
/// Deliberately not `intl` / ARB yet: code generation adds a build step and a
/// dependency, and with one locale it would buy nothing. The seam below is
/// what makes that swap cheap when a second locale actually arrives. See
/// docs/DECISIONS.md, D-6.
abstract interface class AppStrings {
  String get localeCode;

  // App level.
  String get appTitle;

  // Home.
  String get homeContinueMatch;
  String get homeSettings;
  String get homeStatistics;
  String get homeRules;
  String get homeAiLab;

  // Mode availability.
  String get modeNotPlayableBadge;
  String get modeNotPlayableExplanation;
  String get previewTableTitle;

  // Game setup.
  String get setupTitle;
  String get setupRuleProfile;
  String get setupDifficulty;
  String get setupStart;
  String get setupOverwriteTitle;
  String get setupOverwriteMessage;
  String get setupOverwriteAction;
  String get setupRuleIssuesTitle;
  String get setupNoIssues;

  /// Heading for the match length choice.
  String get setupRoundCount;

  /// `9 dağıtım`.
  String roundCountOption(int rounds);

  /// Heading for the "what happens when everybody passes" choice.
  String get setupPassOutTitle;

  /// One option of that choice.
  String passOutOption(PassOutRule rule);

  /// Explains the forced contract the choice produces.
  String setupPassOutHint(int forcedBid);

  /// Heading for the "what does a defender with no tricks pay" choice.
  String get setupDefenderNilTitle;

  /// One option of that choice. [flat] is the fixed charge, when it applies.
  String defenderNilOption(DefenderNilPenalty penalty, int flat);

  /// Explains what the choice above is for.
  String get setupDefenderNilHint;

  /// Heading for the "how many extra tricks sink a made word" choice.
  String get setupOvertrickBustTitle;

  /// Explains what the choice above decides.
  String get setupOvertrickBustHint;

  /// The option for a table where extras never sink a hand.
  String get setupOvertrickBustNever;

  /// `3 yan`: the option that busts on that many extras.
  String overtrickBustOption(int extras);

  // Gameplay - the auction.

  /// Title of the panel that asks the player for a contract.
  String get gameplayBidTitle;

  /// Shown above the grid when nobody has bid yet.
  String get gameplayNoBidYet;

  /// `Selin 6 dedi`: who holds the standing contract, and for how much.
  String gameplayStandingBid(String name, int tricks);

  /// The button that withdraws a seat from the auction.
  String get gameplayPass;

  /// `Pas` next to a seat that has withdrawn.
  String get gameplayPassed;

  /// Title of the panel that asks the contract winner for a trump.
  String get gameplayTrumpTitle;

  /// `7 el sözünüz var`: the contract the trump has to make.
  String gameplayYourContract(int tricks);

  /// The same, when nobody bid and the contract was forced.
  String gameplayForcedContract(int tricks);

  /// `İhale: Selin 7` on the table while the hand is played.
  String gameplayContractLine(String name, int tricks);

  /// Status line while an opponent is bidding.
  String get gameplayWaitingForBids;

  /// Status line while the contract winner is choosing a trump.
  String get gameplayWaitingForTrump;

  // Gameplay.
  String get gameplayTrickLabel;
  String get gameplayYourTurn;
  String get gameplayWaiting;

  // Declarations.
  String get gameplayDeclarePrompt;
  String get gameplayDeclareHint;
  String get gameplayNilLabel;
  String get gameplayDeclaring;
  String get gameplayScoreboardTitle;
  String get gameplayScoreboardTooltip;

  /// The word for a trick, e.g. `el`.
  String get gameplayTrickWord;

  /// `2 / 5 el`: tricks taken against the number declared.
  String declarationProgress(int taken, int declared);

  /// `Soz: 5`, or the nil label.
  String declarationLabel(int declared);
  String get gameplayTrumpLabel;
  String get gameplayNoTrump;
  String get gameplayScoreLabel;
  String get gameplayLeaveMatch;
  String get gameplayHandSummaryTitle;
  String get gameplayNextHand;
  String get gameplayMatchOverTitle;
  String get gameplayYouWon;
  String get gameplayYouLost;
  String get gameplayDraw;
  String get gameplayRematch;
  String get gameplayDeclarationColumn;
  String get gameplayTricksColumn;
  String get gameplayPointsColumn;
  String get gameplayTotalColumn;
  String get gameplayLeaveConfirmTitle;
  String get gameplayLeaveConfirmMessage;
  String get gameplayLeaveConfirmAction;

  // Settings.
  String get settingsTitle;
  String get settingsGeneral;
  String get settingsPresentation;
  String get settingsAnimationSpeed;
  String get settingsSound;
  String get settingsHaptics;
  String get settingsPlayerName;
  String get settingsLanguage;
  String get settingsAiDifficulty;
  String get settingsQuickPlay;
  String get settingsLegalHints;
  String get settingsLegalHintsDetail;
  String get settingsDragToPlay;
  String get settingsSoundUnavailable;

  // Animation speeds.
  String get speedSlow;
  String get speedNormal;
  String get speedFast;
  String get speedInstant;

  // Statistics.
  String get statisticsTitle;
  String get statisticsEmpty;
  String get statisticsOverall;
  String get statisticsByMode;
  String get statisticsPlayed;
  String get statisticsWon;
  String get statisticsDrawn;
  String get statisticsLost;
  String get statisticsWinRate;
  String get statisticsAveragePoints;
  String get statisticsAverageTricks;
  String get statisticsBestScore;
  String get statisticsBestMargin;
  String get statisticsCurrentStreak;
  String get statisticsLongestStreak;
  String get statisticsReset;
  String get statisticsResetConfirm;

  // Rules screen.
  String get rulesTitle;
  String get rulesOpenQuestionsTitle;

  // AI lab.
  String get aiLabTitle;
  String get aiLabRunBaseline;
  String get aiLabRunning;
  String get aiLabHandCount;
  String get aiLabNoStrengthClaim;

  // Generic.
  String get commonBack;
  String get commonCancel;
  String get commonClose;
  String get commonOn;
  String get commonOff;

  /// The player's own seat label, `Siz`. The opponents are named from the
  /// match seed instead; see `SeatNames`.
  String get seatSelf;

  /// `El 3 / 13`.
  String trickProgress(int current, int total);

  /// `Dagitim 3`, or `Dagitim 3 / 8` when the match has a fixed length.
  String handProgress(int current, int? total);

  /// `Hedef 101 puan`, for a match that ends on a score rather than a count.
  String targetScore(int points);

  /// `Oyuncu 2 kazandi`.
  String winnerLine(String name);

  /// Why the engine refused a move. One sentence, aimed at the player.
  String moveRejected(RuleViolationCode code);

  /// `5 el tuttu` style contract summary.
  String contractSummary(int tricks);

  /// Sub-line of the resume card: `Koz Maca - Dagitim 3 - Puan 12`.
  String resumeSummary(String mode, int hand, int score);
}
