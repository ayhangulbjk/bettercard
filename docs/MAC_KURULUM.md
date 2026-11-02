# Mac'te kurulum ve ilk görsel test

Windows geliştirme makinesinde uygulamayı çalıştırmanın yolu yok (bkz. D-14 ve
`ROADMAP.md`). iOS, projenin iki hedef platformundan biri olduğu için Mac'teki
test "idare eder" değil, **gerçek testin kendisi**.

> **Bu dosya Mac'teki Claude Code oturumu için yazılmıştır.** Windows'taki
> oturum Mac'te komut çalıştıramıyor. Sahibi her build için çıktı kopyalayan
> bir kanal olmasın diye Mac'e Claude Code kuruluyor ve kurulumun geri kalanı
> orada yürütülüyor. Aşağıdaki sıra bağlayıcıdır: 7. adımdaki doğrulama
> zinciri geçmeden uygulamayı çalıştırmaya geçme.

Kod GitHub'da: <https://github.com/ayhangulbjk/bettercard> — **depo private.**

Makine: Apple Silicon (arm64), macOS 26.5.1 (25F80), Xcode kurulu değil.

---

## 0. Elle yapılacak iki şey

Geri kalan her şeyi Mac'teki Claude Code yapabilir. Yalnızca bu ikisi insan
eli ister, çünkü biri App Store arayüzü, diğeri tarayıcıda oturum açma:

1. **Xcode indirmesini başlat** (1. adım) — zincirin en uzun parçası, ilk bu
   başlasın.
2. **Claude Code'u kur ve giriş yap** (2. adım).

Sonrası Mac'teki Claude'a devredilir.

## 1. Xcode (GUI, ~10-15 GB)

App Store → "Xcode" → İndir. İndirme sürerken 2. adıma geç, bekleme.
Xcode'un bu macOS'a uyan sürümünü App Store kendisi seçer; elle sürüm
seçmeye çalışma.

Kurulduktan sonra bir kez aç ve ek bileşenleri kurmasına izin ver. Sonra bu
üç komut — **üçü de yönetici parolası ister**, o yüzden betiğe gömülmüyor,
elle çalıştırılıyor:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

> Yalnızca `xcode-select --install` (Command Line Tools) **yetmez**: Flutter
> iOS derlemesi için tam Xcode gerekir. Buna karşılık `git`, Command Line
> Tools ile birlikte geldiği için Xcode kurulduğunda hazır olur.

## 2. Claude Code

Anthropic'in önerdiği yerel kurulum. **sudo gerekmez**, binary
`~/.local/bin/claude` altına iner:

```bash
curl -fsSL https://claude.ai/install.sh | bash
source ~/.zshrc
claude --version
```

Sonra bir dizin açıp başlat:

```bash
mkdir -p ~/dev && cd ~/dev
claude
```

İlk açılışta tarayıcıdan Claude hesabıyla giriş yapmanı ister.

Açılan oturuma verilecek ilk yönlendirme:

```
Proje: https://github.com/ayhangulbjk/bettercard (PRIVATE depo, gh ile yetki gerekir)
Hedef: iOS'ta ilk gorsel test. Depoyu ~/dev/bettercard'a klonla, sonra
docs/MAC_KURULUM.md ve CLAUDE.md'yi oku ve 3. adimdan itibaren uygula.
flutter test +160 vermeli; vermezse durup bana soyle.
```

## 3. Homebrew ve gh

Depo private olduğu için klonlamak yetkilendirme ister. Parolayla HTTPS artık
çalışmıyor; en temiz yol `gh auth login`'in tarayıcı akışı, çünkü kabuk
geçmişine hiçbir gizli anahtar yazılmıyor.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install gh cocoapods
gh auth login     # GitHub.com -> HTTPS -> tarayıcıda oturum aç
```

> Homebrew kurulumu yönetici parolası ister. Bu Mac'te yönetici yetkisi yoksa
> haber ver: Homebrew'suz da ilerlenebilir (Flutter git ile, `gh` tarball
> olarak `~/.local/bin`'e), ama Xcode'un kendisi de yönetici istediği için o
> durumda iOS yolu tamamen kapanır.
>
> **CocoaPods artık gerekli.** 2026-11-02'de `path_provider` eklendi (uygulama
> kendi dosyalarını nereye yazacağını sormak için; ağ açmaz, izin istemez —
> bkz. `docs/DECISIONS.md` D-18). Yerel eklenti geldiği için `flutter create`
> sonrası `ios/` altında `pod install` çalışır. `flutter run` bunu kendisi
> tetikler; elle çalıştırmak gerekirse `cd ios && pod install`.
>
> İlk `pod install` CocoaPods'un spec deposunu indirir ve birkaç dakika
> sürebilir; bu **kurulum** anında internet ister, uygulamanın kendisi hâlâ
> tamamen çevrimdışıdır.

## 4. Depoyu al

```bash
gh repo clone ayhangulbjk/bettercard ~/dev/bettercard
cd ~/dev/bettercard
```

## 5. Flutter SDK — sürüm sabitli

Windows'ta doğrulanan sürüm **3.47.9 / Dart 3.13.7**. İlk görsel testte
değişken sayısını azaltmak için aynı sürüme sabitleniyor; `brew install --cask
flutter` en son stable'ı getirir ve farklı davranabilir.

```bash
git clone https://github.com/flutter/flutter.git -b 3.47.9 ~/development/flutter
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
export PATH="$HOME/development/flutter/bin:$PATH"
flutter --version        # 3.47.9 / Dart 3.13.7 dogrula
```

Sığ klon (`--depth 1`) **kullanma**: Flutter sürüm bilgisini git geçmişinden
okur, sığ klonda bu bozulabilir.

Projenin ilkesi gereği telemetriyi kapat:

```bash
flutter --disable-analytics
dart --disable-analytics
```

Sonra:

```bash
flutter doctor -v
```

`[✓] Xcode` ve `[✓] Flutter` görünmeli. **Android toolchain ve Chrome eksik
olabilir, önemli değil** — iOS testi için gerekmez.

## 6. iOS klasörünü üret

`ios/` klasörü **depoda yok** (`.gitignore`'da `/ios/` ve `/android/` var),
üretilmesi gerekiyor:

```bash
cd ~/dev/bettercard
flutter create . --platforms=ios --project-name batak_king --org com.batakking
```

⚠️ **Hemen ardından şunu sil:**

```bash
rm -f test/widget_test.dart
git status --short        # baska bir sey degismis mi, bak
```

`flutter create` her çalıştığında var olmayan bir sayaç uygulaması için şablon
test ekliyor; derlenmez ve test paketini kırar. Windows'ta **iki kez** oldu,
ikincisinde olacağı bilinmesine rağmen kontrol atlandı ve ancak doğrulama
zinciri yakaladı. Silmeyi atlama.

`flutter create` ayrıca `analysis_options.yaml`'a platform `exclude` satırları
ekler — **onlar kalsın**. `pubspec.yaml` ve `lib/main.dart`'a dokunmaz.

```bash
flutter pub get
```

## 7. Doğrulama zinciri — Mac'te de geçmeli

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

**Beklenen sırayla:** çıktı yok / `No issues found!` / `+160: All tests
passed!`

Bu adım kritik: geçerse alan modelinin platformdan bağımsız olduğu kanıtlanır
(`lib/core/` Flutter'a hiç dokunmuyor, ilke böyleydi). Geçmezse **dur** ve
çıktıyı bildir; platforma özgü gerçek bir fark bulunmuş olur ve arayüz işinden
önce o çözülür.

```bash
dart run tool/benchmarks/run_baseline.dart --hands 2000
```

**Beklenen:** `Illegal: 0` ve `OK: no illegal commands, all invariants held.`
Koltuk ortalamaları toplamı tam **13.0** olmalı (13 el dört koltuğa dağılıyor).

## 8. Simulator'de çalıştır

Fiziksel cihazdan önce Simulator: imzalama, Apple ID, Geliştirici Modu derdi
yok ve uygulamayı **ilk kez görmek** için yeterli.

```bash
open -a Simulator
flutter devices          # simulator'un adini gor
flutter run
```

Simulator'de **File → Open Simulator** altından bir iPhone seç. Uygulama
portre zorunlu, yatay çevirmeyi denemeye gerek yok.

## 9. Fiziksel iPhone (ikinci tur)

Ücretli Apple Developer hesabı **gerekmez**; ücretsiz Apple ID ile 7 günlük
imzalama yeterli.

1. iPhone'u USB ile bağla, "Bu bilgisayara güven" de.
2. `open ios/Runner.xcworkspace` → Runner hedefi → **Signing & Capabilities**
   → Team olarak kendi Apple ID'ni seç. Bundle id `com.batakking.batakKing`
   ücretsiz imzalamada tekil olmalı; çakışırsa Xcode söyler ve sonuna bir ek
   yapılır.
3. iPhone: Ayarlar → Gizlilik ve Güvenlik → **Geliştirici Modu** → açık
   (telefon yeniden başlar). **Bu menü, cihaz Xcode'a ilk kez bağlanıp bir
   geliştirici derlemesi denenmeden önce görünmez**; yoksa önce 4. adımı dene,
   sonra menüye dön.
4. `flutter run -d <cihaz-adı>`

---

## Ne göreceksin

**Hiçbir modu oynayamayacaksın** — bu kasıtlı ve ekranda yazıyor
(`GameMode.isPlayable` hepsinde `false`; sahte işlevsellik yasak).

| Ekran | Durum |
|---|---|
| Ana ekran, beş mod | Hepsi **"Hazır değil"** rozetli |
| Oyun kurulumu | Kural denetimi **"Kural seti tutarlı."** demeli |
| Masa önizlemesi | Gerçek motordan gelen bir pozisyon, ama **etkileşimsiz** |
| Ayarlar | Çalışır, ama kayıt yalnızca bellekte |
| İstatistikler | Boş (uydurma sayı yok) |
| YZ laboratuvarı | **Gerçekten çalışıyor** — 50/250/1000 el benchmark koşturur |

Koz Maça'nın alan katmanı (puanlama, maç durumu, motor) bitti ve 22 testle
doğrulandı, ama arayüz hâlâ statik önizlemeye bağlı; bu yüzden mod oynanabilir
işaretlenmedi.

## Özellikle bakılacaklar

- [ ] **Kart sembolleri — iOS'ta ilk bakılacak şey.** Maça, kupa, karo ve
      sinek, paketlenmiş bir fonttan değil **Unicode metin** olarak çiziliyor
      (`'♠'`, `'♥'`, `'♦'`, `'♣'`; `game_mode_card.dart` ve `suit.dart`), yani
      görünümleri tamamen sistemin yedek fontuna kalıyor. iOS'ta bunlar
      **renkli emoji** olarak çizilebilir; o durumda kupa/karo kırmızı emoji,
      maça/sinek siyah emoji olur ve uygulamanın kendi renk düzeni
      yok sayılır. Düz tipografik pik mi, emoji mi — ekran görüntüsü al.
      Emoji çıkıyorsa çözüm ya font paketlemek ya da pikleri `CustomPaint`
      ile çizmek; cihazda görmeden hangisi gerektiği bilinemez.
- [ ] **Koltuk panelleri (T-1) — karar bekliyor.** Windows'ta alınan
      ekran görüntüsünde üç rakip panelinde isim `Oyu…` diye kesiliyor,
      ikinci satır `0 el - …` oluyor. Yani panel yatay düzende okunmuyor;
      dikey düzene geçmek gerekiyor. Cihazda doğrula ve kararı ver.
- [ ] **Diakritikler.** "Hazır değil", "Başlangıç", "Koz Maça", "Rıfkı" doğru
      render ediliyor mu, kutu/soru işareti çıkıyor mu? (Windows'taki
      headless render'da hepsi doğru çıktı, yani kaynak metin sağlam.)
- [ ] **Metin taşması.** Büyük sistem yazı tipinde (Ayarlar → Erişilebilirlik →
      Görüntü ve Metin Boyutu) bir şey ekrandan taşıyor mu? Ölçekleme 1.35x'te
      sabitleniyor, ama test edilmedi.
- [ ] **Kaydırma.** Ana ekranda beşinci mod ve alttaki kısayollar rahat
      erişilebiliyor mu (tek elle kullanım hedefi).

Ekran görüntüsü: Simulator'de **⌘S**, fiziksel cihazda yan tuş + ses açma.

---

## Cihazsız ekran görüntüsü

Her ekranı cihaz olmadan PNG olarak almak için:

```bash
flutter test tool/screenshots/capture_test.dart
```

Çıktı `build/screenshots/` altına yazılır. Widget test harness'ı gerçek Skia
ile rasterleştirdiği için düzen, taşma ve kesilme burada görünür — Windows
makinesinde uygulamayı çalıştırmanın başka yolu olmadığı için yazıldı, ama
Mac'te de çalışır ve bir düzen değişikliğinin etkisini cihaza kurmadan
göstermeye yarar.

Sınırı şu: harness yalnızca Roboto ve MaterialIcons yükler, **sistem yedek
font zinciri yoktur**. Kart sembolleri orada kutu çıkar; bu bir ürün hatası
değil, tam olarak cihazda bakılması gereken şeyin harness'ta görünmeyen
kısmıdır.
