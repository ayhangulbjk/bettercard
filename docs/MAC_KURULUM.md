# Mac'te kurulum ve ilk görsel test

Windows geliştirme makinesinde uygulamayı çalıştırmanın yolu yok (bkz. D-14 ve
`ROADMAP.md`). iOS, projenin iki hedef platformundan biri olduğu için Mac'teki
test "idare eder" değil, **gerçek testin kendisi**.

Kod GitHub'da: <https://github.com/ayhangulbjk/bettercard>

---

## 1. Xcode (en uzun adım, önce başlat)

App Store'dan **Xcode**'u kur (~10-15 GB). İndirme uzun sürer, o yüzden ilk
bunu başlat ve beklerken 2. adıma geç.

Kurulduktan sonra bir kez aç ve ek bileşenleri kurmasına izin ver. Sonra:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

> Yalnızca `xcode-select --install` (Command Line Tools) **yetmez**. Flutter
> iOS derlemesi için tam Xcode gerekir.

## 2. Flutter SDK

Apple Silicon (M serisi) ya da Intel, `flutter` kendisi halleder.

```bash
# Homebrew varsa:
brew install --cask flutter

# Yoksa elle:
cd ~/development
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.9-stable.zip
unzip flutter_macos_arm64_3.47.9-stable.zip
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Intel Mac'te dosya adı `flutter_macos_3.47.9-stable.zip` (arm64 olmadan).

Windows'ta doğrulanan sürüm **3.47.9 / Dart 3.13.7**. Aynısını kullanmak en
güvenlisi, ama `pubspec.yaml` `>=3.22.0` kabul ediyor.

Projenin ilkesi gereği telemetriyi kapat:

```bash
flutter --disable-analytics
dart --disable-analytics
```

## 3. CocoaPods

iOS bağımlılık yöneticisi, Flutter iOS derlemesi için zorunlu.

```bash
sudo gem install cocoapods
# Apple Silicon'da sorun çıkarsa:
brew install cocoapods
```

## 4. Doğrula

```bash
flutter doctor -v
```

`[✓] Xcode`, `[✓] CocoaPods` ve `[✓] Flutter` görmen gerekiyor. Android
toolchain ve Chrome eksik olabilir, **önemli değil** — iOS testi için gerekmez.

---

## 5. Projeyi al ve iOS klasörünü üret

```bash
git clone https://github.com/ayhangulbjk/bettercard.git
cd bettercard
```

`ios/` klasörü **depoda yok** (`.gitignore`'da), üretilmesi gerekiyor:

```bash
flutter create . --platforms=ios --project-name batak_king --org com.batakking
```

⚠️ **Hemen ardından şunu sil:**

```bash
rm -f test/widget_test.dart
```

`flutter create` her çalıştığında var olmayan bir sayaç uygulaması için şablon
test ekliyor; derlenmez ve testleri kırar. (Windows'ta iki kez başıma geldi.)

```bash
flutter pub get
```

## 6. Testleri çalıştır — Mac'te de geçmeli

```bash
flutter test
```

**Beklenen: `+138: All tests passed!`**

Bu adım kritik: geçerse alan modelinin platformdan bağımsız olduğu kanıtlanır.
Geçmezse bana çıktıyı gönder — platforma özgü bir fark bulmuş oluruz.

```bash
dart run tool/benchmarks/run_baseline.dart --hands 2000
```

**Beklenen: `Illegal: 0` ve `OK: no illegal commands, all invariants held.`**
Koltuk ortalamaları toplamı tam **13.0** olmalı.

## 7. Simulator'de çalıştır

Fiziksel cihazdan önce Simulator'i dene — imzalama derdi yok.

```bash
open -a Simulator
flutter run
```

Simulator'de **Window → Device** menüsünden bir iPhone seç (ör. iPhone 15).

## 8. Fiziksel iPhone'da çalıştır (opsiyonel)

Ücretli Apple Developer hesabı **gerekmez**; ücretsiz Apple ID ile 7 günlük
imzalama yeterli.

1. iPhone'u USB ile bağla, "Bu bilgisayara güven" de
2. iPhone: Ayarlar → Gizlilik ve Güvenlik → **Geliştirici Modu** → açık (yeniden başlatır)
3. `open ios/Runner.xcworkspace` → Runner hedefi → **Signing & Capabilities**
   → Team olarak kendi Apple ID'ni seç
4. `flutter run -d <cihaz-adı>` (`flutter devices` ile adı gör)

---

## Ne göreceksin

**Hiçbir modu oynayamayacaksın** — bu kasıtlı ve ekranda yazıyor.

| Ekran | Durum |
|---|---|
| Ana ekran, beş mod | Hepsi **"Hazır değil"** rozetli |
| Oyun kurulumu | Kural denetimi **"Kural seti tutarlı."** demeli |
| Masa önizlemesi | Gerçek motordan gelen bir pozisyon, ama **etkileşimsiz** |
| Ayarlar | Çalışır, ama kayıt yalnızca bellekte |
| İstatistikler | Boş (uydurma sayı yok) |
| YZ laboratuvarı | **Gerçekten çalışıyor** — 50/250/1000 el benchmark koşturur |

## Özellikle bakmanı istediğim şeyler

- [ ] **Koltuk panelleri (T-1).** Masa önizlemesinde üç rakip paneline telefon
      genişliğinde ~80 px kalıyor. İsimler `Bat…` diye kesiliyor mu? Taşma
      bandı (sarı-siyah çizgili) var mı? Dikey düzene geçmek gerekiyor mu?
- [ ] **Diakritikler.** "Hazır değil", "Başlangıç", "Koz Maça", "Rıfkı"
      doğru render ediliyor mu, kutu/soru işareti çıkıyor mu?
- [ ] **Metin taşması.** Büyük sistem yazı tipinde (Ayarlar → Erişilebilirlik →
      Görüntü ve Metin Boyutu) bir şey ekrandan taşıyor mu? Ölçekleme 1.35x'te
      sabitleniyor, ama test edilmedi.
- [ ] **Kaydırma.** Ana ekranda beşinci mod ve alttaki kısayollar rahat
      erişilebiliyor mu (tek elle kullanım hedefi).
