import '../../core/rules/auction_scoring_rules.dart';
import '../../core/rules/bidding_rules.dart';
import '../../core/rules/partnership_rules.dart';
import '../../core/rules/rule_profile.dart';
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
  String get setupRoundCount => 'Dağıtım sayısı';

  @override
  String roundCountOption(int rounds) => '$rounds dağıtım';

  @override
  String get setupPassOutTitle => 'Herkes pas derse';

  @override
  String passOutOption(PassOutRule rule) => switch (rule) {
        PassOutRule.openerMustBid => 'İhaleyi açan tutar',
        PassOutRule.dealerMustBid => 'Dağıtan tutar',
        PassOutRule.redeal => 'Yeniden dağıtılır',
      };

  @override
  String setupPassOutHint(int forcedBid) =>
      'Zorunlu ihale $forcedBid eldir; kimse istemediği için en düşük '
      'gönüllü ihaleden küçüktür.';

  @override
  String get setupDefenderNilTitle => 'Hiç el alamayan savunma';

  @override
  String defenderNilOption(DefenderNilPenalty penalty, int flat) =>
      switch (penalty) {
        DefenderNilPenalty.contractValue => 'İhale kadar batar',
        DefenderNilPenalty.flat => '$flat batar',
        DefenderNilPenalty.none => 'Batmaz',
      };

  @override
  String get setupDefenderNilHint =>
      'Yan batma. Açıkken savunmadaki herkesin en az bir el alma derdi olur.';

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
  String get gameplayBidTitle => 'İhaleniz?';

  @override
  String get gameplayNoBidYet => 'Henüz kimse ihale vermedi.';

  @override
  String gameplayStandingBid(String name, int tricks) =>
      '$name $tricks dedi. Üstüne çıkın ya da pas geçin.';

  @override
  String get gameplayPass => 'Pas';

  @override
  String get gameplayPassed => 'Pas';

  @override
  String get gameplayTrumpTitle => 'Kozu seçin';

  @override
  String gameplayYourContract(int tricks) => 'İhale sizde: $tricks el.';

  @override
  String gameplayForcedContract(int tricks) =>
      'Kimse ihale vermedi; $tricks el zorunlu olarak sizde.';

  @override
  String gameplayContractLine(String name, int tricks) =>
      'İhale: $name $tricks';

  @override
  String get gameplayWaitingForBids => 'İhale sürüyor';

  @override
  String get gameplayWaitingForTrump => 'Koz seçiliyor';

  @override
  String get teamOursLabel => 'SİZ';

  @override
  String get teamTheirsLabel => 'RAKİP';

  @override
  String teamContractLine(String name, int tricks, bool ours) =>
      'İhale: $name $tricks (${ours ? 'bizde' : 'rakipte'})';

  @override
  String teamTrickSplit(int ours, int theirs) => 'Biz $ours - Onlar $theirs';

  @override
  String teamTricksLeft(int tricks) => 'Kalan $tricks';

  @override
  String dummyPartnerCaption(String name) => 'Eşiniz $name - açık el';

  @override
  String dummyPartnerTurnCaption(String name) =>
      'Eşiniz $name - sıra onda, kartı siz seçin';

  @override
  String dummyYoursCaption(String name) => 'Kartlarınız açık - $name oynuyor';

  @override
  String get gameplayYouAreDummy =>
      'İhaleyi eşiniz aldı; açık el sizsiniz, kartlarınızı o oynuyor.';

  @override
  String get gameplayPlayingDummy => 'Eşinizin açık elinden kart seçin';

  @override
  String get handResultKing => 'KING! 13 ihale, 13 el';

  @override
  String get handResultSweep => '13 yukarı / 13 aşağı';

  @override
  String get setupPartnershipModeTitle => 'Eşli tür';

  @override
  String partnershipModeOption(PartnershipMode mode) => switch (mode) {
        PartnershipMode.openDummy => 'Açık eş',
        PartnershipMode.closedPartnership => 'Kapalı eş',
      };

  @override
  String get setupPartnershipModeHint =>
      'Açık eşte koz seçildikten sonra ihalecinin eşinin 13 kartı masaya '
      'açılır ve o kartları ihaleci oynar. Kapalı eşte herkes kendi kartını '
      'oynar, hiçbir el açılmaz.';

  @override
  String get setupDummyControlTitle => 'Açık el sizde kalsın';

  @override
  String get setupDummyControlHint =>
      'Klasik kuralda açık eli ihaleci oynar; ihaleyi bot alırsa sizin '
      'kartlarınızı da o oynar. Bu seçenek açıkken kendi açık elinizi siz '
      'oynarsınız. Özelleştirilmiş moddur.';

  @override
  String get setupTargetScore => 'Bitiş puanı';

  @override
  String targetScoreOption(int points) => '$points puan';

  @override
  String get setupDefenderFloorTitle => 'Savunmanın en az lövesi';

  @override
  String defenderFloorOption(int tricks) => '$tricks el';

  @override
  String get setupDefenderFloorHint =>
      'Savunma takımı bu sayıya ulaşamazsa ihale kadar eksi yazar. Sayı '
      'takımın toplamıdır; iki oyuncunun ayrı ayrı alması gerekmez.';

  @override
  String get setupSpecialResultsTitle => 'Özel sonuçlar';

  @override
  String get setupKingLabel => 'KING (13 ihale + 13 el)';

  @override
  String get setupKingEndsMatchLabel => 'KING partiyi bitirir';

  @override
  String get setupSweepLabel => '13 yukarı / 13 aşağı';

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
  String get rulesHowToPlayTitle => 'Nasıl oynanır?';

  @override
  List<RuleGuideEntry> partnershipGuide(RuleProfile profile) {
    final int tricks = profile.tricksPerHand;
    final int minimum = profile.biddingRules.minimumBid;
    final int maximum = profile.biddingRules.maximumBid;
    final int forced = profile.biddingRules.effectiveForcedBid;
    final int floor = profile.partnershipScoringRules.defenderMinimumTricks;
    final int target = profile.scoringRules.targetScore;
    final bool open = profile.partnershipRules.revealsDummy;
    return <RuleGuideEntry>[
      const RuleGuideEntry(
        'Eşli İhaleli Batak nedir?',
        'Dört oyuncu iki takım olur. Bir oyuncu ihaleyi alır, kozu seçer ve '
            'takımı o ihaleyi tutmaya çalışır. Puan oyuncuya değil takıma '
            'yazılır.',
      ),
      const RuleGuideEntry(
        'Takımlar nasıl oluşur?',
        'Eşler karşı karşıya oturur. Siz ve karşınızdaki oyuncu bir takımsınız; '
            'sağınızdaki ve solunuzdaki oyuncu diğer takımdır. Takımlar parti '
            'boyunca değişmez.',
      ),
      RuleGuideEntry(
        'Kartlar nasıl dağıtılır?',
        '52 kartlık deste kullanılır, joker yoktur. Herkese $tricks kart '
            'dağıtılır, artan kart kalmaz. Bir dağıtım tam $tricks lövedir. '
            'Dağıtıcılık her dağıtımda değişir.',
      ),
      const RuleGuideEntry(
        'İhale nasıl yapılır?',
        'İhale dağıtıcının sağındaki oyuncudan başlar. Sıra size geldiğinde '
            'ya mevcut teklifin üstüne çıkarsınız ya da pas dersiniz. Bir kez '
            'pas diyen o dağıtımın ihalesine geri dönemez. Tek aktif teklif '
            'sahibi kalınca ihale kapanır.',
      ),
      RuleGuideEntry(
        'Minimum ihale neden $minimum?',
        'Çünkü ihaleyi bir takım tutar, bir kişi değil. İki el birlikte '
            'oynadığı için masa $tricks lövenin $minimum tanesinden aşağısını '
            'dinlemez. En yüksek ihale $maximum olabilir.',
      ),
      RuleGuideEntry(
        'Herkes pas derse ne olur?',
        'İhaleyi açan oyuncu $forced el zorunlu ihale alır. Bu sayı '
            'gönüllü en düşük ihaleden ($minimum) küçüktür: kimse istemediği '
            'bir eli, seçilebilecek en küçüğü kadar ağır saymak doğru olmaz. '
            'Bu kuralı oyun kurulumundan değiştirebilirsiniz.',
      ),
      const RuleGuideEntry(
        'Kozu kim seçer?',
        'İhaleyi kazanan oyuncu. Dört renkten birini seçer ve koz dağıtım '
            'boyunca değişmez.',
      ),
      RuleGuideEntry(
        'Açık eşli oyun nedir?',
        open
            ? 'Koz seçildikten sonra ihalecinin eşinin $tricks kartı masaya '
                'açılır. Bu kartları herkes görür, ama onları ihaleci oynar. '
                'İhaleci böylece iki eli tek bir plan içinde yönetir.'
            : 'Bu kural setinde kapalı eşli oynanıyor: hiçbir el açılmaz. '
                'Açık eşliyi oyun kurulumundan seçebilirsiniz.',
      ),
      const RuleGuideEntry(
        'İhalecinin eşinin kartları ne zaman açılır?',
        'Yalnızca koz kesinleştikten sonra. Dağıtım, ihale ve koz seçimi '
            'boyunca kapalı kalır; yoksa ihaleci kozu eşinin kartlarını '
            'bilerek seçmiş olurdu.',
      ),
      const RuleGuideEntry(
        'Açık el kartlarını kim oynar?',
        'İhaleci. Kart gerçek sahibinin elinden çıkar ve löveyi o koltuk '
            'kazanır; ihaleci yalnızca hangi kartın oynanacağına karar verir. '
            'İhaleyi bot alıp siz onun eşi olursanız kendi kartlarınızı bot '
            'oynar. İsterseniz kurulumdan "Açık el sizde kalsın" seçeneğini '
            'açarak kendi açık elinizi kendiniz oynayabilirsiniz.',
      ),
      const RuleGuideEntry(
        'Renk takip etme nedir?',
        'Löve hangi renkle açıldıysa elinizde o renkten kart varsa onu '
            'oynamak zorundasınız.',
      ),
      const RuleGuideEntry(
        'Yükseltme zorunluluğu nedir?',
        'Açılan renkten yerdeki en büyük kartı geçebiliyorsanız geçmek '
            'zorundasınız. En büyük kartınızı atmanız gerekmez, geçmeye yeten '
            'herhangi biri olur. Löve daha önce kozla kesilmişse bu zorunluluk '
            'kalkar.',
      ),
      const RuleGuideEntry(
        'Koz kesme nedir?',
        'Elinizde açılan renkten kart yoksa ve kozunuz varsa koz oynamak '
            'zorundasınız. Yerde koz varsa ve geçebiliyorsanız onu da geçmek '
            'zorundasınız.',
      ),
      const RuleGuideEntry(
        'Kozla açma nasıl yapılır?',
        'Eşli Batak\'ta serbesttir: koz kırılmasını beklemeden ilk löveyi '
            'kozla açabilirsiniz. Bu, Herkes Tek İhaleli Batak\'tan önemli '
            'bir farktır.',
      ),
      const RuleGuideEntry(
        'Löveyi kim kazanır?',
        'Lövede koz varsa en büyük koz, yoksa açılan rengin en büyüğü. '
            'Kazanan sonraki löveyi açar. Açık el kazanırsa sonraki löveyi de '
            'onun koltuğu açar; kartı yine ihaleci seçer.',
      ),
      const RuleGuideEntry(
        'Takım puanları nasıl hesaplanır?',
        'İhaleci takım söylediği kadar veya daha fazla löve alırsa aldığı '
            'löve kadar artı yazar. Savunma takımı da aldığı löve kadar artı '
            'yazar. İki oyuncunun löveleri birlikte sayılır; ayrı ayrı bir '
            'hedefi yoktur.',
      ),
      const RuleGuideEntry(
        'İhaleci takım ne zaman batar?',
        'Söylediğinden az löve aldığında. O zaman ihale kadar eksi yazar; '
            'bir el mi eksik on el mi eksik fark etmez. Fazla löve almak '
            'batırmaz.',
      ),
      RuleGuideEntry(
        'Savunma takımı neden en az $floor löve almalı?',
        'Almazsa ihale kadar eksi yazar. Böylece savunmadaki iki oyuncunun da '
            'eli boş kalmasın diye uğraşması gerekir. Bu sayı takımın '
            'toplamıdır: iki oyuncunun ayrı ayrı $floor löve alması gerekmez.',
      ),
      RuleGuideEntry(
        'KING nedir?',
        'İhaleci takım $maximum ihale verip $tricks lövenin tamamını alırsa '
            'KING olur: $tricks artı, karşı takıma $tricks eksi. Varsayılan '
            'ayarda parti o anda biter.',
      ),
      RuleGuideEntry(
        '13 yukarı / 13 aşağı nedir?',
        'Bir takım $maximum ihale vermeden $tricks lövenin tamamını alırsa '
            'yine $tricks artı yazar, diğer takım $tricks eksi. Savunma '
            'takımının bütün löveleri alması da buna dahildir. Bu hesap normal '
            'puanlamadan önce yapılır ve normal puanlama ikinci kez '
            'uygulanmaz.',
      ),
      RuleGuideEntry(
        'Parti nasıl kazanılır?',
        '$target puana ulaşan takım kazanır. Aynı dağıtımda iki takım da '
            'hedefe ulaşırsa yüksek puanlı takım kazanır; puanlar eşitse bir '
            'dağıtım daha oynanır. KING varsayılan olarak partiyi anında '
            'bitirir.',
      ),
      const RuleGuideEntry(
        'Açık ve kapalı eşli farkı nedir?',
        'Açık eşlide ihalecinin eşinin kartları masaya açılır ve iki eli '
            'ihaleci oynar. Kapalı eşlide hiçbir el açılmaz, herkes kendi '
            'kartını oynar ve eşler yalnızca ihaleden ve oynanan kartlardan '
            'çıkarım yaparak işbirliği kurar.',
      ),
    ];
  }

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
