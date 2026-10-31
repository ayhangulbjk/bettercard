import 'app_strings.dart';

/// Turkish copy.
///
/// Written for players, not for developers: short labels, no jargon, and no
/// English loanwords where a natural Turkish term exists.
final class TurkishStrings implements AppStrings {
  const TurkishStrings();

  @override
  String get localeCode => 'tr';

  @override
  String get appTitle => 'Batak & King';

  @override
  String get appTagline => 'Tamamen cevrimdisi Turk kagit oyunlari';

  @override
  String get homePlayTitle => 'Oyun Sec';

  @override
  String get homeContinueMatch => 'Devam Et';

  @override
  String get homeSettings => 'Ayarlar';

  @override
  String get homeStatistics => 'Istatistikler';

  @override
  String get homeRules => 'Kurallar';

  @override
  String get homeAiLab => 'Yapay Zeka Laboratuvari';

  @override
  String get homeOfflineBadge => 'Internet gerekmez';

  @override
  String get modeNotPlayableBadge => 'Hazir degil';

  @override
  String get modeNotPlayableExplanation =>
      'Bu oyun modunun kurallari ve yapay zekasi henuz tamamlanmadi. Simdilik '
      'yalnizca masa duzenini onizleyebilirsiniz.';

  @override
  String get previewTableTitle => 'Masa Onizlemesi';

  @override
  String get setupTitle => 'Oyun Kurulumu';

  @override
  String get setupRuleProfile => 'Kural Seti';

  @override
  String get setupDifficulty => 'Zorluk';

  @override
  String get setupStart => 'Basla';

  @override
  String get setupRuleIssuesTitle => 'Kural Denetimi';

  @override
  String get setupNoIssues => 'Kural seti tutarli.';

  @override
  String get setupPlayerCount => 'Oyuncu sayisi';

  @override
  String get setupTricksPerHand => 'El basina oyun sayisi';

  @override
  String get gameplayTrickLabel => 'El';

  @override
  String get gameplayYourTurn => 'Sira sizde';

  @override
  String get gameplayWaiting => 'Bekleniyor';

  @override
  String get gameplayTrumpLabel => 'Koz';

  @override
  String get gameplayNoTrump => 'Kozsuz';

  @override
  String get gameplayScoreLabel => 'Puan';

  @override
  String get gameplayLeaveMatch => 'Masadan ayril';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsGeneral => 'Genel';

  @override
  String get settingsPresentation => 'Gorunum';

  @override
  String get settingsAnimationSpeed => 'Animasyon hizi';

  @override
  String get settingsSound => 'Ses';

  @override
  String get settingsHaptics => 'Titresim';

  @override
  String get settingsPlayerName => 'Oyuncu adi';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsAiDifficulty => 'Yapay zeka zorlugu';

  @override
  String get settingsQuickPlay => 'Hizli oyun';

  @override
  String get speedSlow => 'Yavas';

  @override
  String get speedNormal => 'Normal';

  @override
  String get speedFast => 'Hizli';

  @override
  String get speedInstant => 'Animasyonsuz';

  @override
  String get statisticsTitle => 'Istatistikler';

  @override
  String get statisticsEmpty =>
      'Henuz tamamlanmis parti yok. Oyun modlari oynanabilir hale geldiginde '
      'istatistikleriniz burada birikecek.';

  @override
  String get rulesTitle => 'Kurallar';

  @override
  String get rulesOpenQuestionsTitle => 'Acik kural sorulari';

  @override
  String get aiLabTitle => 'Yapay Zeka Laboratuvari';

  @override
  String get aiLabRunBaseline => 'Temel cizgiyi calistir';

  @override
  String get aiLabRunning => 'Calisiyor...';

  @override
  String get aiLabHandCount => 'El sayisi';

  @override
  String get aiLabNoStrengthClaim =>
      'Su anda yalnizca kurallara uyan rastgele oyuncu uygulanmistir. Daha '
      'guclu seviyeler henuz yok; buradaki sonuclar bir guc iddiasi degildir.';

  @override
  String get commonBack => 'Geri';

  @override
  String get commonCancel => 'Vazgec';

  @override
  String get commonClose => 'Kapat';

  @override
  String get commonOn => 'Acik';

  @override
  String get commonOff => 'Kapali';

  @override
  String seatName(int seat) => seat == 0 ? 'Siz' : 'Oyuncu ${seat + 1}';

  @override
  String trickProgress(int current, int total) => 'El $current / $total';

  @override
  String contractSummary(int tricks) => '$tricks el ihale';
}
