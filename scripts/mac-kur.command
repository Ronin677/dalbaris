#!/bin/bash
# dalbaris.com — Mac kurulumu (bir kez çift tıkla)
# Masaüstüne "dalbaris Fotoğraflar" klasörü koyar; içine atılan fotoğraflar kendiliğinden siteye gider.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
DEPO="$HOME/dalbaris"
KISAYOL="$HOME/Desktop/dalbaris Fotoğraflar"
AJAN="com.dal.dalbaris-yukle"
PLIST="$HOME/Library/LaunchAgents/$AJAN.plist"
GUNLUK="$HOME/Library/Logs/dalbaris-yukle.log"

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

echo "2/4 Masaüstü klasörü oluşturuluyor…"
if [ -e "$KISAYOL" ] && [ ! -L "$KISAYOL" ]; then
  hata "Masaüstünde zaten '$(basename "$KISAYOL")' adında gerçek bir klasör var. Onu taşıyıp tekrar dene."
fi
ln -sfn "$DEPO/fotograflar" "$KISAYOL"

echo "3/4 Otomatik gönderim açılıyor…"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$AJAN</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$DEPO/scripts/otomatik-yukle.sh</string></array>
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
launchctl bootstrap "gui/$(id -u)" "$PLIST" || hata "Otomatik gönderim başlatılamadı."

echo "4/4 Kontrol ediliyor…"
sleep 2
launchctl print "gui/$(id -u)/$AJAN" >/dev/null 2>&1 || hata "Otomatik gönderim çalışmıyor."

osascript -e 'display notification "Masaüstündeki klasöre fotoğraf at, siteye kendiliğinden gider." with title "dalbaris.com" subtitle "Kurulum tamam"' >/dev/null 2>&1
open "$KISAYOL"
open -e "$KISAYOL/NASIL KULLANILIR.txt" 2>/dev/null

echo
echo "✓ Kurulum tamam."
echo "  Masaüstünde 'dalbaris Fotoğraflar' klasörü hazır."
echo "  İçine seri klasörü açıp fotoğrafları sürükle; Mac her dakika bakıp siteye gönderir."
echo "  Kayıt: $GUNLUK"
echo
# Kurulum dosyası masaüstünden çalıştırıldıysa kendini kaldırır
case "$0" in "$HOME/Desktop/"*) rm -f -- "$0" ;; esac
echo "Bu pencereyi kapatabilirsin."
