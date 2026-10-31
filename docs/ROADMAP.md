# Yol Haritası ve Görev Listesi

Son güncelleme: **2026-10-31**

---

## Şu an neredeyiz

**1. kilometre taşı tamamlandı ve doğrulandı.** Araç zinciri kurulu, kod
derleniyor, 138 test geçiyor, APK üretiliyor. **Hiçbir oyun modu henüz
oynanabilir değil** — bu kasıtlı ve üründe etiketli.

| Ölçüm | Değer |
|---|---|
| `lib/` | 65 Dart dosyası, 7.338 satır |
| `test/` | 14 dosya, 2.034 satır, **138 test** |
| `tool/` | 1 benchmark CLI |
| Araç zinciri | Flutter 3.47.9 · Dart 3.13.7 · Android SDK 36 · NDK 28.2 · JDK 21 |
| Paket adı | `com.batakking.batak_king` |
| `flutter analyze` | 0 sorun |
| En büyük dosya | 302 satır (`docs/` hariç 296) |

---

## Sıradaki adım: uygulamayı ilk kez çalıştırmak

Geliştirme Windows'ta, **çalıştırma Mac'te.** Bu bir tercih değil, iki
kısıtın sonucu: bu makinede yazılım kurulumu politikayla engelli (admin
token'u var ama VS yükleyicisi 16389 ile reddediliyor), ve web hedefi
64-bit PRNG yüzünden derlenemiyor (D-14).

### Windows'ta çalışan ve çalışmaya devam edecek işler

Bunlar admin gerektirmiyor, hepsi doğrulandı:

- [x] `dart format .` · `flutter analyze` · `flutter test` (138 test)
- [x] `dart run tool/benchmarks/run_baseline.dart --hands 2000`
- [x] `flutter build apk --debug` (APK üretiliyor, cihaz gerekmiyor)

Yani kod yazmak, test etmek ve benchmark almak için Mac'e ihtiyaç yok.

### Mac'te yapılacak ilk görsel test

Depoyu Mac'e klonladıktan sonra:

```bash
flutter create . --platforms=ios --project-name batak_king --org com.batakking
flutter pub get
flutter test                 # 138 test burada da geçmeli
open -a Simulator            # ya da iPhone'u USB ile bağla
flutter run
```

- [ ] Beş modlu ana ekran, hepsi "Hazır değil" rozetli
- [ ] Kural denetimi: "Kural seti tutarlı." görünmeli
- [ ] Masa önizlemesi (etkileşimsiz, etiketli)
- [ ] YZ laboratuvarı: 50/250/1000 el benchmark gerçekten koşuyor
- [ ] **Koltuk paneli (T-1) değerlendirmesi** — gerçek telefonda isimler
      `Bat…` diye kesiliyor mu, dikey düzene geçmek gerekiyor mu
- [ ] Diakritiklerin cihazda doğru render edildiği

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

- Hiçbir mod oynanabilir değil — `GameMode.isPlayable` her yerde `false`
- İhale, sözleşme seçimi, gömme veya puanlama yaşam döngüsü yok
- Kurallı-rastgele temel çizginin üstünde YZ yok
- Diske kayıt yok (yalnızca bellek içi depo)
- Ses, titreşim veya kart animasyonu yok

---

## 2. kilometre taşı — ilk oynanabilir mod

**Hedef: Koz Maça, uçtan uca.** En basit mod (ihale yok), bu yüzden ihale
yaşam döngüsü olmadan tüm dikey dilimi sınar.

- [ ] `lib/games/spades_batak/`: tur durumu, motor, puanlayıcı
- [ ] Maç denetleyicisi: dağıt → oyna → puanla → sonraki el → parti sonu
- [ ] Masayı canlı duruma bağlamak; dokunarak ve sürükleyerek kart oynamak
- [ ] Yapılandırılan hızda el animasyonları
- [ ] `HeuristicPolicy` (Normal için), Başlangıç için zayıflatılmış varyantı
- [ ] Diske kayıt: `shared_preferences` veya JSON dosyası,
      `SettingsRepository` arkasında; otomatik kayıt ve hızlı devam
- [ ] İlk gerçek benchmark girdisi: sezgisel vs rastgele, **eşleştirilmiş
      dağıtımlar ve döndürülmüş koltuklar** ile
- [ ] `GameMode.isPlayable`'ı yalnızca Koz Maça için `true` yapmak ve
      `test/integration/app_navigation_test.dart` rozet testini bilinçli
      güncellemek

**Bitti sayılma koşulu:** tam bir Koz Maça partisi oynanabiliyor ve devam
ettirilebiliyor; sezgisel politika rastgeleyi **sıfırı dışlayan bir güven
aralığıyla** yeniyor.

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
| T-1 | **Koltuk paneli düzeni.** Telefon genişliğinde üç rakip paneline ~80px kalıyor; isim `Bat…` diye kesiliyor. Dikey düzen (avatar üstte, isim altta) ya da istatistikleri ortak bir skor şeridine taşımak. | **Dikey düzen onaylandı**, uygulama ilk kez görüldükten sonra yapılacak |
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
