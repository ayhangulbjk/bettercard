# Yol Haritası ve Görev Listesi

Son güncelleme: **2026-11-02**

---

## Şu an neredeyiz

**Koz Maça oynanabilir.** Dağıt, oyna, puanla, sonraki dağıtım, parti sonu —
hepsi gerçek motor üzerinden, karttan anlayan rakiplerle. Diğer dört mod hâlâ
ihale/gömme/sözleşme yaşam döngüsünden yoksun ve üründe öyle etiketli.

Sezgisel oyuncunun gücü ölçüldü: rastgele temel çizgiye karşı
**+1,27 ± 0,03 el/dağıtım** (1500 dağıtım, dört koltuğa döndürülmüş,
eşleştirilmiş). Başlangıç seviyesi +0,84 ± 0,03. Kontrol koşusu
(rastgele vs rastgele) sıfırı içeriyor, yani ölçüm düzeneği doğru.

| Ölçüm | Değer |
|---|---|
| `lib/` | 76 Dart dosyası, 9.827 satır |
| `test/` | 16 dosya, 2.390 satır, **166 test** |
| `tool/` | 2 benchmark CLI + kayıt doğrulama + ekran görüntüsü aracı |
| Araç zinciri | Flutter 3.47.9 · Dart 3.13.7 · Android SDK 36 · NDK 28.2 · JDK 21 |
| Paket adı | `com.batakking.batak_king` |
| `flutter analyze` | 0 sorun |
| En büyük dosya | 374 satır (`tool/screenshots/capture_test.dart`); `lib/` içinde 303 |

### Bir sonraki oturum buradan başlasın

**Durum:** 1. ve 2. kilometre taşı bitti, `main`'e gönderildi. Koz Maça
oynanabilir, kaydediliyor, istatistikler birikiyor.

**Paralel yürüyen iş:** Mac'te cihaz testi (yukarıdaki liste). Cihazdan bir
sorun gelirse **o önceliklidir** — iki makinede aynı dosyaya paralel
dokunmamak için, Mac'teki oturum kod değiştirecekse önce burada konuşulur.

**Sıradaki geliştirme:** 3. kilometre taşı, ihale yaşam döngüsü. Ortak bir
ihale motoru (artırma/pas/koz ilanı) yazılıp önce `auction_batak`, sonra
`partnership_batak` üzerine kurulacak. Koz Maça'nın dikey dilimi şablon:
`SpadesBatakEngine` + `MatchController` + `MatchTurn` + `MatchPersistence`
aynı şekilde tekrarlanır, yalnızca ihale fazı eklenir.

**İhale gelince dikkat edilecek iki şey:**

1. `HeuristicPolicy` **yalnızca el sayısını** büyütmeye çalışır. İhaleli
   modlarda savunmacı, ihaleyi batırmaya oynar; bu farklı bir değerlendirme
   fonksiyonudur ve politikanın belgelerinde de öyle yazıyor. Koz Maça
   politikasını ihaleli moda bağlamak "kanıtsız güç iddiası" olur.
2. `SavedMatch` hamle günlüğü tutuyor (D-19). İhale de bir komut olduğu için
   günlüğe **ihale komutları da** girmeli, yoksa yarım kalmış bir ihale geri
   yüklenemez.

---

## Sıradaki adım: uygulamayı ilk kez çalıştırmak

Geliştirme Windows'ta, **çalıştırma Mac'te.** Bu bir tercih değil, iki
kısıtın sonucu: bu makinede yazılım kurulumu politikayla engelli (admin
token'u var ama VS yükleyicisi 16389 ile reddediliyor), ve web hedefi
64-bit PRNG yüzünden derlenemiyor (D-14).

### Windows'ta çalışan ve çalışmaya devam edecek işler

Bunlar admin gerektirmiyor, hepsi doğrulandı:

- [x] `dart format .` · `flutter analyze` · `flutter test` (166 test)
- [x] `flutter test tool/screenshots/capture_test.dart` — 14 ekran PNG olarak
      (`build/screenshots/`), canlı maçı gerçekten sürerek
- [x] `dart run tool/checks/save_roundtrip.dart 150` — kayıt/geri yükleme
- [x] `dart run tool/benchmarks/run_baseline.dart --hands 2000`
- [x] `flutter build apk --debug` (APK üretiliyor, cihaz gerekmiyor)

Yani kod yazmak, test etmek ve benchmark almak için Mac'e ihtiyaç yok.

### Mac'te yapılacak ilk görsel test

Mac kuruldu (Xcode + Claude), ilk tur **yapıldı**. Depoyu klonladıktan
sonra:

```bash
flutter create . --platforms=android,ios --project-name batak_king --org com.batakking
rm -f test/widget_test.dart   # flutter create her seferinde geri ekler
flutter pub get
flutter test                  # 166 test burada da geçmeli
open -a Simulator             # ya da iPhone'u USB ile bağla
flutter run                   # ilk pod install birkaç dakika surebilir
```

Cihazda doğrulanacaklar:

- [x] Kart sembolleri ve Türkçe diakritikler doğru render ediliyor
- [x] Koz Maça uçtan uca oynanıyor: dokunarak **ve sürükleyerek** kart oynama
- [x] Yalnızca oynanabilir kartlar vurgulanıyor
- [x] Uygulamayı tamamen kapatıp açınca **"Devam Et"** aynı yerden sürdürüyor
- [ ] Biten parti İstatistikler ekranında görünüyor
- [ ] YZ laboratuvarı: 50/250/1000 el benchmark gerçekten koşuyor

İlk cihaz testinden çıkanlar (2026-11-03, hepsi giderildi):

- **Koz kesme zorunlu değildi.** Elinde kozu olan ve renkten yoksul bir
  oyuncuya çöp atma hakkı veriliyordu, yerdeki kozun üstüne çıkma da zorunlu
  değildi. `TrickRules.kozMaca` iki bayrağı da kapalı taşıyordu; ikisi de
  açıldı, B-3 buna göre güncellendi.
- **Koltuk paneli (T-1)** çözüldü: üç rakip tepede tek sıra yerine masanın
  sol, karşı ve sağ kenarına oturuyor, oyuncu altta.
- Ana sayfa sadeleşti: kaydırma yok, oyun başına tek satır.
- Rakipler artık rastgele Türk isimleriyle oturuyor (maç tohumundan
  türetiliyor, yani kayıttan dönünce aynı masa).
- Ortaya atılan kartlar üst üste yığılıyor, el sinek/karo/maça/kupa sırasına
  göre diziliyor.

İkinci cihaz turundan çıkanlar (2026-11-03, hepsi giderildi):

- **El artık sağdan dönüyor.** 1. koltuk masanın sağına çizilir; oyun yönü
  oyuncudan sağa doğrudur.
- Biten el, kazanan oyuncunun önüne doğru toplanarak gidiyor; kim aldığı
  animasyondan görülüyor.
- Koltuk panelinde kart sayısı kaldırıldı; isim altında "alınan / söz" var.
- Üstteki puan şeridi kaldırıldı. Puan durumu sağ üstteki simgenin arkasında.
- **Koz Maça'da söz (ihale) turu eklendi.** Her elin başında dört oyuncu da
  kaç el alacağını söyler; sözünü tutan artı, tutamayan eksi alır, "el almaz"
  +50/-50. Kurallar `DeclarationRules`'ta, açık sorular K-4..K-6.

> `ios/` ve `android/` klasörleri kasıtlı olarak depoda değil, commit edilmez.
> `.flutter-plugins-dependencies` de üretilen bir dosya; `.gitignore`'da.

---

## 1. kilometre taşı — temel ✅

Gönderildi:

- [x] Saf Dart kart modeli, deterministik `SeededRandom`, tohumlu dağıtım
- [x] Oturma düzeni, eşli oyun desteğiyle
- [x] Ortak el çekirdeği: el, kazanan çözümleyici, kurallı hamle üreteci,
      değişmez durum, komut doğrulayan yetkili motor
- [x] Beş modun kural profilleri + doğrulama + 6 belgelenmiş hazır set
- [x] YZ bilgi sınırı: gözlem filtresi, kart takipçisi, gizli el örnekleyici,
      politika arayüzü, kurallı-rastgele temel çizgi, karar servisi dikişi
- [x] Başsız simülatör: gecikme ve güven aralığı raporlaması
- [x] Ayarlar modeli, JSON kodlayıcılar, donmuş kural profilli kayıt modeli
- [x] `AppStrings` dikişi üzerinden Türkçe arayüz: ana ekran, kural denetimli
      oyun kurulumu, etiketli masa önizlemesi, ayarlar, kurallar, istatistik,
      YZ laboratuvarı
- [x] Birim, entegrasyon ve simülasyon testleri; benchmark CLI
- [x] **Araç zinciri kurulumu ve uçtan uca doğrulama** (2026-10-31)

Gönderilmedi ve üründe öyle etiketli:

- Hiçbir mod oynanabilir değildi — `GameMode.isPlayable` her yerde `false`
  (2. kilometre taşında Koz Maça için açıldı)
- İhale, sözleşme seçimi, gömme veya puanlama yaşam döngüsü yok
- Kurallı-rastgele temel çizginin üstünde YZ yok (2. kilometre taşında geldi)
- Diske kayıt yok (yalnızca bellek içi depo) — **hâlâ böyle**
- Ses, titreşim veya kart animasyonu yok (titreşim 2. kilometre taşında geldi)

---

## 2. kilometre taşı — ilk oynanabilir mod
**Hedef: Koz Maça, uçtan uca.** En basit mod (ihale yok), bu yüzden ihale
yaşam döngüsü olmadan tüm dikey dilimi sınar.

### Alan modeli ✅ (2026-10-31)

- [x] `lib/games/spades_batak/spades_batak_scorer.dart` — el puanlaması
- [x] `lib/games/spades_batak/spades_batak_match_state.dart` — değişmez maç
      anlık görüntüsü, değişmez denetimi dahil
- [x] `lib/games/spades_batak/spades_batak_engine.dart` — dağıt → oyna →
      puanla → sonraki el → parti sonu, tek `apply` içinde
- [x] 22 yeni test: tam 8 ellik maç her hamlede değişmez kontrolüyle,
      tohum tekrarlanabilirliği, hedef-puan bitişi, reddetmeler

Üç tasarım kararı:

1. **İhaleyi alan yok, uydurulmadı.** `BatakScoringRules` bir declarer
   etrafında kurulu ama Koz Maça'da ihale yok; puanlayıcı o alanları
   kasıtlı yok sayıyor, geçerli tek alan `pointsPerTrickForOthers`.
2. **Sonraki el `apply` içinde dağıtılır**, ayrı adım yok — yarım geçiş
   oluşması imkânsız.
3. **Tohum `baseSeed + turIndex`** — motor saf kalır, replay çalışır.

El açma sırası her elde döner (`handIndex % playerCount`); puanlama kuralı
değil usul olduğu için `RuleProfile` seçeneği yapılmadı.

### Oynanabilirlik ✅ (2026-11-02)

- [x] Riverpod maç denetleyicisi (`MatchController`), komutları motora iletir
- [x] Canlı masa (`MatchScreen`): skor şeridi, dikey rakip panelleri, el sonu
      puan kâğıdı, parti sonu paneli
- [x] İnsan oyuncu için dokunarak **ve sürükleyerek** kart oynama
- [x] `HeuristicPolicy` (Normal) ve Başlangıç için zayıflatılmış varyantı
- [x] İlk gerçek benchmark girdisi: `tool/benchmarks/run_matchup.dart`,
      eşleştirilmiş dağıtımlar ve döndürülmüş koltuklar
- [x] `GameMode.isPlayable` yalnızca Koz Maça için `true`; rozet testi
      bilinçli güncellendi (artık moda göre iddia ediyor)
- [x] Uygulanmamış zorluk seviyeleri (Zor, Uzman, Efsane) arayüzde kapalı
- [x] Boşta duran ayarlar bağlandı: hızlı oyun, kart vurgusu, sürükleme,
      titreşim. Ses bu sürümde yok, bu yüzden anahtarı kapalı ve öyle yazıyor.

### Kalıcılık ve istatistik ✅ (2026-11-02)

- [x] Diske kayıt: tek eklenti (`path_provider`), `lib/platform/` altında
      JSON dosyaları, atomik yazma (D-18)
- [x] Her karttan sonra otomatik kayıt; ana ekranda **"Devam Et"** kartı
- [x] Maç kaydı hamle günlüğü olarak tutuluyor, geri yükleme motor üzerinden
      tekrar oynatılarak yapılıyor (D-19) — bozuk veya elle düzenlenmiş kayıt
      reddediliyor
- [x] Tamamlanan partiler kaydediliyor; istatistik ekranı gerçek verilerle:
      oynanan/kazanılan/berabere/kaybedilen, kazanma oranı, ortalama puan,
      dağıtım başına ortalama el, en yüksek puan, en iyi fark, seriler,
      mod bazında kırılım, sıfırlama
- [x] Yeni parti kayıtlı partinin üzerine yazacaksa önce soruluyor
- [x] `tool/checks/save_roundtrip.dart`: gerçek diskte kaydet → oku →
      tekrar oynat, konum birebir aynı; iki sahte kayıt reddediliyor

### Kalan işler

- [ ] Kart hareketi animasyonu (şu an tempo var, hareket yok)
- [ ] Cihazda ilk çalıştırma (Mac + Xcode hazır)

**Bitti sayılma koşulu:** tam bir Koz Maça partisi oynanıp devam
ettirilebiliyor, ve sezgisel politika rastgeleyi sıfırı dışlayan bir güven
aralığıyla yeniyor.

---

## 3. kilometre taşı — ihaleli modlar

- [ ] İhale yaşam döngüsü: artırma, pas, herkes pas geçerse çözüm, koz ilanı
- [ ] `lib/games/auction_batak/` ve `lib/games/partnership_batak/`
- [ ] `BidEvaluator` ve `ContractSelector`
- [ ] Eşli Batak için `PartnershipStrategy`
- [ ] İhale arayüzü: artırma merdiveni, koz seçici, sözleşme göstergesi
- [ ] Benchmark: zorluk başına sözleşme tutturma oranı

---

## 4. kilometre taşı — arama ve gerçek zorluk

- [ ] Isolate destekli `AiDecisionService`: iptal ve zaman aşımı ile
- [ ] `HiddenHandSampler` dünyaları üzerinde `MonteCarloPolicy`
- [ ] Son birkaç el için `EndgameSolver`
- [ ] Uzman ve Efsane seviyelerini gerçek bütçelere bağlamak
- [ ] Temsili bir orta seviye Android cihazda gecikme ölçümü
- [ ] Her seviye için iki temel çizgiye karşı benchmark girdisi

> Uzman ve Efsane, benchmark girdileri var olana kadar arayüzde **kapalı**
> kalır. Bu, "kanıtsız güç iddiası yok" ilkesinin uygulanması.

---

## 5. kilometre taşı — kalan modlar

- [ ] `lib/games/buried_batak/`: üç koltuk, artan kart, gömme arayüzü ve
      kısıtları
- [ ] `lib/games/king/`: kotalara karşı sözleşme seçimi, sözleşme başına
      puanlama, uzun parti durumu
- [ ] King'e özgü YZ: ceza sözleşmesi oyunu el almaktan **temelden** farklıdır
      ve kendi değerlendirmesini gerektirir
- [ ] Açık kural sorularını oyuncularla çözmek: **B-4**, **K-1**, **K-2**

---

## 6. kilometre taşı — cilalama

- [ ] İstatistikler: mod başına geçmiş, sözleşme başarısı, seriler
- [ ] Kişiselleştirme: masa temaları, kart arkaları, avatarlar, isimler, düzen
- [ ] Ses ve titreşim
- [ ] Animasyon cilası, animasyon atlama ve hızlı oyun yolları
- [ ] Erişilebilirlik: ekran okuyucu etiketleri, kontrast, ölçekleme denetimi
- [ ] Performans: orta seviye cihazda 60 fps, destekleyen yerde 120 fps
- [ ] İngilizce yerelleştirme (ikinci bir `AppStrings` uygulaması + dil
      değiştirici; üçüncü dil gelirse ARB'ye geçilir)
- [ ] Prosedürel çizimi geçiyorsa illüstrasyonlu kart görselleri

---

## Bekleyen tasarım kararları

| # | Konu | Durum |
|---|---|---|
| T-1 | **Koltuk paneli düzeni.** Telefon genişliğinde üç rakip paneline ~80px kalıyor; isim `Bat…` diye kesiliyor. | **Çözüldü** (2026-11-02): `SeatPanel(vertical: true)` — avatar üstte, isim altta. Ayrıca toplamlar ortak skor şeridine taşındı. Ekran görüntüsünde isimler tam sığıyor. |
| T-2 | Türkçe diakritikler | Yapılacak — yukarıdaki "sıradaki adım" |
| T-3 | `adb` çakışması: `C:\Users\TCAYGUL\platform-tools` ile SDK'nın kopyası | Zararsız uyarı; cihaz algılama sorunu çıkarsa eskisi PATH'ten çıkarılır |

---

## Açık kural soruları

Bunlar **uydurulmadı**; oyunculara sorulması gerekiyor. Tamamı için
`RULE_PROFILES.md`:

- **B-4** — Üçlü Gömmeli Batak'ta kaç kart gömülür ve bu kartlar kimin
  hesabına yazılır?
- **K-1** — King'de her oyuncu kaç sözleşme seçer ve hangi karışımda?
  (Şu an 20 elli ve 8 elli iki hazır set var; parti uzunluğu kotalardan
  **türetiliyor**, sabit yazılmadı.)
- **K-2** — Rıfkı ve Son İki her masada standart mı?

---

## Kasıtlı olarak kapsam dışı

Çevrimiçi çok oyuncu, hesaplar, reklamlar, uygulama içi satın alma, analitik,
bulut YZ, yatay düzen. Her biri açıkça belirtilmiş bir ürün gereksinimini
ihlal ederdi.
