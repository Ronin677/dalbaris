#!/bin/bash
# dalbaris.com — "dalbaris Fotoğraflar" klasörünü GitHub'a otomatik gönderir.
# Klasör iCloud Drive'dadır: Mac masaüstünden de, iPhone'daki Dosyalar uygulamasından da (Lightroom,
# Leica FOTOS, Leica LUX → Paylaş → Dosyalara Kaydet) doldurulur. Asıl kaynak bu klasördür;
# depodaki fotograflar/ onun aynasıdır.
# launchd (com.dal.dalbaris-yukle) her dakika çalıştırır. Değişiklik yoksa hiçbir şey yapmaz.
# Kopyalama/iCloud indirmesi sürerken göndermez: dosyalar 20 sn değişmeden durunca gönderir.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG="tr_TR.UTF-8"
DEPO="$HOME/dalbaris"
KLASOR="fotograflar"
BULUT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dalbaris Fotoğraflar"
UZUN_KENAR=4000
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

# ---- iCloud klasörünü depoya aynala ----
if [ -d "$BULUT" ]; then
  if ! ls "$BULUT" >/dev/null 2>&1; then
    bildir "iCloud klasörüne erişilemiyor" "Sistem Ayarları → Gizlilik'ten 'dalbaris Yükleyici' için iCloud Drive izni ver."
    gunluk "HATA: iCloud klasörü okunamadı (izin)"; exit 1
  fi
  # GitHub sitesinden (başka yoldan) eklenen fotoğrafları iCloud klasörüne de koy ki aynalama onları silmesin
  if [ -z "$(git status --porcelain -- "$KLASOR")" ] && git fetch -q origin main 2>/dev/null; then
    YENI="$(git diff --name-only --diff-filter=A HEAD origin/main -- "$KLASOR" 2>/dev/null)"
    if git merge -q --ff-only origin/main 2>/dev/null && [ -n "$YENI" ]; then
      while IFS= read -r f; do
        [ -f "$f" ] || continue; h="$BULUT/${f#$KLASOR/}"
        [ -e "$h" ] || { mkdir -p "$(dirname "$h")"; cp -p "$f" "$h"; }
      done <<< "$YENI"
      gunluk "GitHub'dan gelenler iCloud klasörüne kopyalandı"
    fi
  fi
  # iCloud bazı dosyaları henüz bu Mac'e indirmediyse indir ve bu turu bekle
  BEKLEYEN="$(find "$BULUT" -name '.*.icloud' 2>/dev/null)"
  if [ -n "$BEKLEYEN" ]; then
    brctl download "$BULUT" >/dev/null 2>&1
    while IFS= read -r f; do d="$(dirname "$f")"; n="$(basename "$f")"; n="${n#.}"; brctl download "$d/${n%.icloud}" >/dev/null 2>&1; done <<< "$BEKLEYEN"
    exit 0
  fi
  resimleri_say() { find "$1" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.webp' \) 2>/dev/null | wc -l | tr -d ' '; }
  # Güvenlik: iCloud klasörü boş görünüyor ama sitede fotoğraf varsa hiçbir şeyi silme
  if [ "$(resimleri_say "$BULUT")" = "0" ] && [ "$(resimleri_say "$KLASOR")" != "0" ]; then
    gunluk "UYARI: iCloud klasörü boş görünüyor, silme yapılmadı"; exit 0
  fi
  # Kopyalama / iCloud senkronu bitti mi? 20 sn arayla iki ölçüm aynı olmalı
  bolcum() { find "$BULUT" -type f ! -name '.DS_Store' -exec stat -f '%N %z %m' {} + 2>/dev/null | sort | md5 -q; }
  ILK="$(bolcum)"
  if [ "$ILK" != "$(cat "$DURUM/son-olcum" 2>/dev/null)" ]; then
    sleep 20; [ "$ILK" != "$(bolcum)" ] && exit 0
    # Telefondan tam boy gelenleri küçült (uzun kenar 4000 px, kalite 95) — depo hafif kalsın
    find "$BULUT" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -size +6M 2>/dev/null | while IFS= read -r f; do
      W="$(sips -g pixelWidth "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')"; H="$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')"
      if [ -n "$W" ] && [ -n "$H" ] && { [ "$W" -gt "$UZUN_KENAR" ] || [ "$H" -gt "$UZUN_KENAR" ]; }; then
        sips -Z "$UZUN_KENAR" -s formatOptions 95 "$f" >/dev/null 2>&1 && gunluk "Küçültüldü: $f"
      fi
    done
    # Telefondan HEIC geldiyse JPEG'e çevir
    find "$BULUT" -type f \( -iname '*.heic' -o -iname '*.heif' \) 2>/dev/null | while IFS= read -r f; do
      j="${f%.*}.jpg"; [ -e "$j" ] && continue
      sips -s format jpeg -s formatOptions 95 -Z "$UZUN_KENAR" "$f" --out "$j" >/dev/null 2>&1 && mv "$f" "$HOME/.Trash/" 2>/dev/null && gunluk "HEIC → JPEG: $j"
    done
    bolcum > "$DURUM/son-olcum"
  fi
  rsync -a --delete --exclude '.DS_Store' --exclude '.*.icloud' --exclude '.gitignore' --exclude '.gitkeep' --exclude 'NASIL KULLANILIR.txt' "$BULUT/" "$KLASOR/" 2>/dev/null \
    || { gunluk "HATA: iCloud → depo kopyalama başarısız"; exit 1; }
fi

# Desteklenmeyen dosyalar (DNG, HEIC, video...) için bir kez uyar
ATLANAN="$(git status --porcelain --ignored -- "$KLASOR" 2>/dev/null | grep '^!!' | grep -v '\.DS_Store' | sed 's/^!! //')"
if [ -n "$ATLANAN" ]; then
  IZ="$(printf '%s' "$ATLANAN" | md5 -q)"
  if [ "$IZ" != "$(cat "$DURUM/atlanan" 2>/dev/null)" ]; then
    ADET="$(printf '%s\n' "$ATLANAN" | wc -l | tr -d ' ')"
    bildir "$ADET dosya gönderilmedi" "Sadece JPEG/PNG/TIFF gider. DNG (ham) dosyalar için Lightroom'dan JPEG çıkar."
    gunluk "Desteklenmeyen dosyalar: $ATLANAN"
    printf '%s' "$IZ" > "$DURUM/atlanan"
  fi
fi

# Değişiklik yoksa çık
[ -z "$(git status --porcelain -- "$KLASOR")" ] && exit 0

# iCloud yoksa (yalnız yerel klasör): kopyalama bitti mi?
if [ ! -d "$BULUT" ]; then
  olcum() { find "$KLASOR" -type f ! -name '.DS_Store' -exec stat -f '%N %z %m' {} + 2>/dev/null | sort | md5 -q; }
  ILK="$(olcum)"; sleep 20; [ "$ILK" != "$(olcum)" ] && exit 0
fi

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

git commit -q -m "Fotoğraflar: $OZET" -m "dalbaris Fotoğraflar klasöründen (iCloud) otomatik gönderildi."

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
