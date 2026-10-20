#!/bin/bash
# dalbaris.com — Mac'teki fotograflar klasörünü GitHub'a otomatik gönderir.
# launchd (com.dal.dalbaris-yukle) her dakika çalıştırır. Değişiklik yoksa hiçbir şey yapmaz.
# Kopyalama sürerken göndermez: dosyalar 20 sn boyunca değişmeden durunca gönderir.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG="tr_TR.UTF-8"
DEPO="$HOME/dalbaris"
KLASOR="fotograflar"
DURUM="$HOME/Library/Application Support/dalbaris-yukle"
mkdir -p "$DURUM"

cd "$DEPO" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Aynı anda iki kopya çalışmasın
KILIT="$DURUM/kilit"
if ! mkdir "$KILIT" 2>/dev/null; then
  # 15 dakikadan eski kilit kalmışsa (çökme vb.) temizle
  [ -n "$(find "$KILIT" -maxdepth 0 -mmin +15 2>/dev/null)" ] && rmdir "$KILIT" 2>/dev/null
  exit 0
fi
trap 'rmdir "$KILIT" 2>/dev/null' EXIT

bildir() { osascript -e "display notification \"$2\" with title \"dalbaris.com\" subtitle \"$1\"" >/dev/null 2>&1; }
gunluk() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Desteklenmeyen dosyalar (DNG, HEIC, video...) için bir kez uyar
ATLANAN="$(git status --porcelain --ignored -- "$KLASOR" 2>/dev/null | grep '^!!' | grep -v '\.DS_Store' | sed 's/^!! //')"
if [ -n "$ATLANAN" ]; then
  IZ="$(printf '%s' "$ATLANAN" | md5 -q)"
  if [ "$IZ" != "$(cat "$DURUM/atlanan" 2>/dev/null)" ]; then
    ADET="$(printf '%s\n' "$ATLANAN" | wc -l | tr -d ' ')"
    bildir "$ADET dosya gönderilmedi" "Sadece JPEG/PNG/TIFF gider. DNG ve HEIC için Lightroom'dan JPEG çıkar."
    gunluk "Desteklenmeyen dosyalar: $ATLANAN"
    printf '%s' "$IZ" > "$DURUM/atlanan"
  fi
fi

# Değişiklik yoksa çık
[ -z "$(git status --porcelain -- "$KLASOR")" ] && exit 0

# Kopyalama bitti mi? 20 sn arayla iki ölçüm aynı olmalı
olcum() { find "$KLASOR" -type f ! -name '.DS_Store' -exec stat -f '%N %z %m' {} + 2>/dev/null | sort | md5 -q; }
ILK="$(olcum)"; sleep 20; [ "$ILK" != "$(olcum)" ] && exit 0

# GitHub'ın dosya sınırı 100 MB — büyükleri gönderme
BUYUK="$(find "$KLASOR" -type f -size +95M 2>/dev/null)"

git add -A -- "$KLASOR"
if [ -n "$BUYUK" ]; then
  while IFS= read -r f; do git reset -q -- "$f"; done <<< "$BUYUK"
  bildir "Çok büyük dosya atlandı" "95 MB üstü dosyalar gönderilmez. Lightroom'da uzun kenar 4000 px, kalite 95 ile çıkar."
  gunluk "Büyük dosyalar atlandı: $BUYUK"
fi
git diff --cached --quiet && exit 0

EKLENEN="$(git diff --cached --name-only --diff-filter=AM -- "$KLASOR" | grep -viE '\.(txt|gitignore|gitkeep)$' | wc -l | tr -d ' ')"
SILINEN="$(git diff --cached --name-only --diff-filter=D -- "$KLASOR" | grep -viE '\.(txt|gitignore|gitkeep)$' | wc -l | tr -d ' ')"
OZET=""
[ "$EKLENEN" != "0" ] && OZET="$EKLENEN fotoğraf eklendi/güncellendi"
[ "$SILINEN" != "0" ] && OZET="${OZET:+$OZET, }$SILINEN fotoğraf kaldırıldı"
[ -z "$OZET" ] && OZET="seri bilgileri güncellendi"

git commit -q -m "Fotoğraflar: $OZET" -m "Mac'teki dalbaris Fotoğraflar klasöründen otomatik gönderildi."

# GitHub sitesinden de yükleme yapılmışsa önce onları al, sonra gönder
DENEME=0
until git pull -q --rebase --autostash origin main && git push -q origin HEAD:main; do
  DENEME=$((DENEME+1))
  if [ "$DENEME" -ge 3 ]; then
    git rebase --abort >/dev/null 2>&1
    bildir "Gönderilemedi" "İnternet ya da GitHub girişini kontrol et. Bir dakika sonra tekrar denenecek."
    gunluk "HATA: push başarısız, commit yerelde bekliyor"
    # commit yerelde kalır; bir sonraki çalışmada "değişiklik yok" der, o yüzden geri al ki tekrar denensin
    git reset -q --soft HEAD~1
    exit 1
  fi
  sleep 10
done

gunluk "Gönderildi: $OZET"
bildir "Gönderildi" "$OZET. Site 2-3 dakika içinde güncellenir."
