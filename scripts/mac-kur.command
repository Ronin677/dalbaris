#!/bin/bash
# dalbaris.com — Mac kurulumu (bir kez çift tıkla)
# iCloud Drive'da "dalbaris Fotoğraflar" klasörü açar, masaüstüne kısayolunu koyar.
# Klasöre Mac'ten ya da iPhone'dan (Dosyalar, Lightroom, Leica FOTOS/LUX → Dosyalara Kaydet) atılan
# fotoğraflar kendiliğinden siteye gider.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
DEPO="$HOME/dalbaris"
KISAYOL="$HOME/Desktop/dalbaris Fotoğraflar"
AJAN="com.dal.dalbaris-yukle"
PLIST="$HOME/Library/LaunchAgents/$AJAN.plist"
GUNLUK="$HOME/Library/Logs/dalbaris-yukle.log"
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
BULUT="$ICLOUD/dalbaris Fotoğraflar"
UYGULAMA="$HOME/Applications/dalbaris Yükleyici.app"

hata() { echo; echo "✘ $1"; osascript -e "display dialog \"$1\" with title \"dalbaris.com kurulumu\" buttons {\"Tamam\"} with icon stop" >/dev/null 2>&1; exit 1; }

clear
echo "dalbaris.com fotoğraf klasörü kuruluyor…"
echo

command -v git >/dev/null || hata "git bulunamadı. Terminal'de 'xcode-select --install' çalıştırıp tekrar dene."
command -v gh  >/dev/null || hata "GitHub aracı (gh) bulunamadı."
gh auth status >/dev/null 2>&1 || hata "GitHub girişi yok. Terminal'de 'gh auth login' ile Ronin677 hesabına gir, sonra tekrar çift tıkla."
gh auth setup-git >/dev/null 2>&1

echo "1/4 Site deposu indiriliyor…"
if [ -d "$DEPO/.git" ]; then
  git -C "$DEPO" pull -q --rebase --autostash origin main || hata "Depo güncellenemedi. İnternet bağlantısını kontrol et."
else
  [ -e "$DEPO" ] && hata "$DEPO adında bir klasör zaten var. Adını değiştirip tekrar dene."
  gh repo clone Ronin677/dalbaris "$DEPO" -- -q || hata "Depo indirilemedi. GitHub'da Ronin677 hesabına girili olduğundan emin ol."
fi
git -C "$DEPO" config user.name  "Barış Dal"
git -C "$DEPO" config user.email "ben@dalbaris.com"
git -C "$DEPO" config pull.rebase true
chmod +x "$DEPO/scripts/otomatik-yukle.sh"

echo "2/4 iCloud klasörü hazırlanıyor…"
if [ -d "$ICLOUD" ]; then
  mkdir -p "$BULUT"
  # Sitede zaten olan fotoğrafları iCloud klasörüne taşı (klasör boşsa)
  if [ -z "$(ls -A "$BULUT" 2>/dev/null | grep -v '^\.DS_Store$')" ]; then
    rsync -a --exclude '.gitignore' --exclude '.gitkeep' --exclude '.DS_Store' "$DEPO/fotograflar/" "$BULUT/"
  fi
  [ -e "$BULUT/NASIL KULLANILIR.txt" ] || cp "$DEPO/fotograflar/NASIL KULLANILIR.txt" "$BULUT/"
  HEDEF="$BULUT"
else
  echo "  ! Bu Mac'te iCloud Drive kapalı; klasör yalnız bu Mac'te olacak (telefondan atılamaz)."
  echo "    Sonra açmak istersen: Sistem Ayarları → Apple Hesabı → iCloud → iCloud Drive, ardından bu dosyayı tekrar çalıştır."
  HEDEF="$DEPO/fotograflar"
fi
if [ -e "$KISAYOL" ] && [ ! -L "$KISAYOL" ]; then
  hata "Masaüstünde zaten '$(basename "$KISAYOL")' adında gerçek bir klasör var. Onu taşıyıp tekrar dene."
fi
ln -sfn "$HEDEF" "$KISAYOL"

echo "3/4 Otomatik gönderim açılıyor…"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs" "$HOME/Applications"
# Küçük bir arka plan uygulaması: macOS iCloud Drive iznini ona bir kez sorar
rm -rf "$UYGULAMA"
osacompile -o "$UYGULAMA" -e 'do shell script "/bin/bash \"$HOME/dalbaris/scripts/otomatik-yukle.sh\" >> \"$HOME/Library/Logs/dalbaris-yukle.log\" 2>&1 || true"' \
  || hata "Arka plan uygulaması oluşturulamadı."
plutil -replace LSUIElement -bool true "$UYGULAMA/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "com.dal.dalbaris-yukleyici" "$UYGULAMA/Contents/Info.plist"
codesign --force --deep -s - "$UYGULAMA" >/dev/null 2>&1
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$AJAN</string>
  <key>ProgramArguments</key>
  <array><string>$UYGULAMA/Contents/MacOS/applet</string></array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>LowPriorityIO</key><true/>
  <key>StandardOutPath</key><string>$GUNLUK</string>
  <key>StandardErrorPath</key><string>$GUNLUK</string>
</dict>
</plist>
PL
launchctl bootout "gui/$(id -u)/$AJAN" >/dev/null 2>&1
if [ -d "$ICLOUD" ]; then
  echo
  echo "  → Birazdan macOS '\"dalbaris Yükleyici\" iCloud Drive'daki dosyalara erişmek istiyor' diye sorabilir."
  echo "    İzin Ver'e bas. (Sadece bir kez sorar.)"
  echo
  open -W "$UYGULAMA"
fi
launchctl bootstrap "gui/$(id -u)" "$PLIST" || hata "Otomatik gönderim başlatılamadı."

echo "4/4 Kontrol ediliyor…"
sleep 2
launchctl print "gui/$(id -u)/$AJAN" >/dev/null 2>&1 || hata "Otomatik gönderim çalışmıyor."

sleep 3
if grep -q "iCloud klasörü okunamadı" "$GUNLUK" 2>/dev/null && [ -n "$(find "$GUNLUK" -mmin -1)" ]; then
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
  hata "iCloud Drive izni verilmedi. Açılan pencerede 'dalbaris Yükleyici' için iCloud Drive'ı aç, sonra bu dosyayı tekrar çalıştır."
fi
osascript -e 'display notification "Klasöre Mac ya da iPhone'\''dan fotoğraf at, siteye kendiliğinden gider." with title "dalbaris.com" subtitle "Kurulum tamam"' >/dev/null 2>&1
open "$KISAYOL"
open -e "$KISAYOL/NASIL KULLANILIR.txt" 2>/dev/null

echo
echo "✓ Kurulum tamam."
echo "  Masaüstünde 'dalbaris Fotoğraflar' klasörü hazır (iCloud Drive'da)."
echo "  iPhone'da: Dosyalar → iCloud Drive → dalbaris Fotoğraflar."
echo "  İçine seri klasörü açıp fotoğrafları at; Mac her dakika bakıp siteye gönderir."
echo "  Kayıt: $GUNLUK"
echo
# Kurulum dosyası masaüstünden çalıştırıldıysa kendini kaldırır
case "$0" in "$HOME/Desktop/"*) rm -f -- "$0" ;; esac
echo "Bu pencereyi kapatabilirsin."
