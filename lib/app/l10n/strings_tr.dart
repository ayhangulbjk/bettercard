import '../../core/rules/rule_violation.dart';
import 'app_strings.dart';

/// Turkish copy.
///
/// Written for players, not for developers: short labels, no jargon, and no
/// English loanwords where a natural Turkish term exists.
///
/// Full diacritics. The earlier ASCII-only restriction (D-7) existed because
/// the authoring toolchain could not write UTF-8 reliably; that is no longer
/// true and was verified before this file was rewritten.
final class TurkishStrings implements AppStrings {
  const TurkishStrings();

  @override
  String get localeCode => 'tr';

  @override
  String get appTitle => 'Batak & King';

  @override
  String get homeContinueMatch => 'Devam Et';

  @override
  String get homeSettings => 'Ayarlar';

  @override
  String get homeStatistics => 'İstatistikler';

  @override
  String get homeRules => 'Kurallar';

  @override
  String get homeAiLab => 'Yapay Zeka Laboratuvarı';

  @override
  String get modeNotPlayableBadge => 'Hazır değil';

  @override
  String get modeNotPlayableExplanation =>
      'Bu oyun modunun kuralları ve yapay zekası henüz tamamlanmadı. Şimdilik '
      'yalnızca masa düzenini önizleyebilirsiniz.';

  @override
  String get previewTableTitle => 'Masa Önizlemesi';

  @override
  String get setupTitle => 'Oyun Kurulumu';

  @override
  String get setupRuleProfile => 'Kural Seti';

  @override
  String get setupDifficulty => 'Zorluk';

  @override
  String get setupStart => 'Başla';

  @override
  String get setupOverwriteTitle => 'Kayıtlı parti var';

  @override
  String get setupOverwriteMessage =>
      'Yarım kalmış bir partiniz var. Yeni parti başlatırsanız o parti '
      'silinir.';

  @override
  String get setupOverwriteAction => 'Yeni parti başlat';

  @override
  String get setupRuleIssuesTitle => 'Kural Denetimi';

  @override
  String get setupNoIssues => 'Kural seti tutarlı.';

  @override
  String get setupOvertrickBustTitle => 'Kaç yanda batılır?';

  @override
  String get setupOvertrickBustHint =>
      'Sözden fazla alınan her el bir "yan"dır; seçtiğiniz sayıya '
      'ulaşınca el batar.';

  @override
  String get setupOvertrickBustNever => 'Batmaz';

  @override
  String overtrickBustOption(int extras) => '$extras yan';

  @override
  String get gameplayTrickLabel => 'El';

  @override
  String get gameplayYourTurn => 'Sıra sizde';

  @override
  String get gameplayWaiting => 'Bekleniyor';

  @override
  String get gameplayDeclarePrompt => 'Kaç el alacaksınız?';

  @override
  String get gameplayDeclareHint =>
      'Sözünüzü tutarsanız söylediğiniz kadar artı, tutamazsanız o kadar '
      'eksi puan alırsınız.';

  @override
  String get gameplayNilLabel => 'El almaz';

  @override
  String get gameplayDeclaring => 'Sözler veriliyor';

  @override
  String get gameplayScoreboardTitle => 'Puan durumu';

  @override
  String get gameplayScoreboardTooltip => 'Puan durumunu göster';

  @override
  String get gameplayTrickWord => 'el';

  @override
  String declarationProgress(int taken, int declared) =>
      declared == 0 ? '$taken / el almaz' : '$taken / $declared el';

  @override
  String declarationLabel(int declared) =>
      declared == 0 ? gameplayNilLabel : 'Söz: $declared';

  @override
  String get gameplayTrumpLabel => 'Koz';

  @override
  String get gameplayNoTrump => 'Kozsuz';

  @override
  String get gameplayScoreLabel => 'Puan';

  @override
  String get gameplayLeaveMatch => 'Masadan ayrıl';

  @override
  String get gameplayHandSummaryTitle => 'Dağıtım bitti';

  @override
  String get gameplayNextHand => 'Sonraki dağıtım';

  @override
  String get gameplayMatchOverTitle => 'Parti bitti';

  @override
  String get gameplayYouWon => 'Kazandınız!';

  @override
  String get gameplayYouLost => 'Bu partiyi kaybettiniz';

  @override
  String get gameplayDraw => 'Berabere';

  @override
  String get gameplayRematch => 'Yeniden oyna';

  @override
  String get gameplayDeclarationColumn => 'Söz';

  @override
  String get gameplayTricksColumn => 'El';

  @override
  String get gameplayPointsColumn => 'Puan';

  @override
  String get gameplayTotalColumn => 'Toplam';

  @override
  String get gameplayLeaveConfirmTitle => 'Masadan ayrılınsın mı?';

  @override
  String get gameplayLeaveConfirmMessage =>
      'Parti kaydedilir. Ana ekrandaki "Devam Et" ile kaldığınız yerden '
      'sürdürebilirsiniz.';

  @override
  String get gameplayLeaveConfirmAction => 'Ayrıl';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsGeneral => 'Genel';

  @override
  String get settingsPresentation => 'Görünüm';

  @override
  String get settingsAnimationSpeed => 'Animasyon hızı';

  @override
  String get settingsSound => 'Ses';

  @override
  String get settingsHaptics => 'Titreşim';

  @override
  String get settingsPlayerName => 'Oyuncu adı';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsAiDifficulty => 'Yapay zeka zorluğu';

  @override
  String get settingsQuickPlay => 'Hızlı oyun';

  @override
  String get settingsLegalHints => 'Oynanabilir kart vurgusu';

  @override
  String get settingsLegalHintsDetail =>
      'Yalnızca kuralların size zaten izin verdiği kartları gösterir; '
      'rakip eli asla açığa çıkarmaz.';

  @override
  String get settingsDragToPlay => 'Sürükleyerek oyna';

  @override
  String get settingsSoundUnavailable => 'Bu sürümde ses yok.';

  @override
  String get speedSlow => 'Yavaş';

  @override
  String get speedNormal => 'Normal';

  @override
  String get speedFast => 'Hızlı';

  @override
  String get speedInstant => 'Animasyonsuz';

  @override
  String get statisticsTitle => 'İstatistikler';

  @override
  String get statisticsEmpty =>
      'Henüz tamamlanmış parti yok. Oyun modları oynanabilir hâle geldiğinde '
      'istatistikleriniz burada birikecek.';

  @override
  String get statisticsOverall => 'Genel';

  @override
  String get statisticsByMode => 'Modlara göre';

  @override
  String get statisticsPlayed => 'Oynanan parti';

  @override
  String get statisticsWon => 'Kazanılan';

  @override
  String get statisticsDrawn => 'Berabere';

  @override
  String get statisticsLost => 'Kaybedilen';

  @override
  String get statisticsWinRate => 'Kazanma oranı';

  @override
  String get statisticsAveragePoints => 'Parti başına ortalama puan';

  @override
  String get statisticsAverageTricks => 'Dağıtım başına ortalama el';

  @override
  String get statisticsBestScore => 'En yüksek puan';

  @override
  String get statisticsBestMargin => 'En iyi fark';

  @override
  String get statisticsCurrentStreak => 'Güncel galibiyet serisi';

  @override
  String get statisticsLongestStreak => 'En uzun seri';

  @override
  String get statisticsReset => 'İstatistikleri sıfırla';

  @override
  String get statisticsResetConfirm =>
      'Tüm parti geçmişi silinecek. Bu geri alınamaz.';

  @override
  String get rulesTitle => 'Kurallar';

  @override
  String get rulesOpenQuestionsTitle => 'Açık kural soruları';

  @override
  String get aiLabTitle => 'Yapay Zeka Laboratuvarı';

  @override
  String get aiLabRunBaseline => 'Temel çizgiyi çalıştır';

  @override
  String get aiLabRunning => 'Çalışıyor...';

  @override
  String get aiLabHandCount => 'El sayısı';

  @override
  String get aiLabNoStrengthClaim =>
      'Şu anda yalnızca kurallara uyan rastgele oyuncu uygulanmıştır. Daha '
      'güçlü seviyeler henüz yok; buradaki sonuçlar bir güç iddiası değildir.';

  @override
  String get commonBack => 'Geri';

  @override
  String get commonCancel => 'Vazgeç';

  @override
  String get commonClose => 'Kapat';

  @override
  String get commonOn => 'Açık';

  @override
  String get commonOff => 'Kapalı';

  @override
  String get seatSelf => 'Siz';

  @override
  String trickProgress(int current, int total) => 'El $current / $total';

  @override
  String contractSummary(int tricks) => '$tricks el ihale';

  @override
  String resumeSummary(String mode, int hand, int score) =>
      '$mode  ·  Dağıtım $hand  ·  $gameplayScoreLabel $score';

  @override
  String handProgress(int current, int? total) =>
      total == null ? 'Dağıtım $current' : 'Dağıtım $current / $total';

  @override
  String targetScore(int points) => 'Hedef $points puan';

  @override
  String winnerLine(String name) => '$name kazandı';

  @override
  String moveRejected(RuleViolationCode code) => switch (code) {
        RuleViolationCode.notYourTurn => 'Sıra sizde değil.',
        RuleViolationCode.cardNotInHand => 'Bu kart elinizde değil.',
        RuleViolationCode.mustFollowSuit =>
          'Yerden gelen renge uymanız gerekiyor.',
        RuleViolationCode.mustPlayTrump =>
          'Bu renk elinizde yok, koz oynamanız gerekiyor.',
        RuleViolationCode.mustOvertrump =>
          'Yerdeki kozdan büyük bir koz oynamanız gerekiyor.',
        RuleViolationCode.mustBeatLeadSuit =>
          'Yerdeki karttan büyük oynamanız gerekiyor.',
        RuleViolationCode.trumpNotBroken =>
          'Koz henüz kırılmadı, koz çıkamazsınız.',
        RuleViolationCode.wrongPhase => 'Bu hamle şu anda yapılamaz.',
        RuleViolationCode.invalidBid ||
        RuleViolationCode.contractUnavailable ||
        RuleViolationCode.invalidBury =>
          'Bu hamle kurallara uygun değil.',
      };
}
