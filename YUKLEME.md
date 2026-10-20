# dalbaris.com — Fotoğraf yükleme

Site adını **Barış Dal — Görsel Hikâyeler** olarak kullanıyorum. Profesyonel portfolyolarda sık görülen kısa, fotoğrafçının kendi adıyla kurulu marka yapısını izliyor; gezinmede “Hikâyeler” ve “Seçkiler” kullanılıyor. Carlton Soohoo da işlerini “Galleries” ve “Selected Work” olarak ayırıyor.

## Masaüstü ve iPhone klasörü

Masaüstündeki **dalbaris Fotoğraflar** klasörü iCloud Drive’dadır; iPhone ve Mac aynı içeriği görür. Mac yükleyicisi klasörü izler, dosyalar eşitlenince fotoğrafları GitHub’a gönderir ve Cloudflare siteyi yeniden üretir.

Her yolculuk için ana klasörün içinde ayrı bir hikâye klasörü aç:

```
dalbaris Fotoğraflar/
  01_Fas/
    01_marrakesh-koutoubia-minaresi.jpg
    02_essaouira-balik-limani.jpg
    03_essaouira-limaninda-karsilasma.jpg
    04_essaouira-sisli-surlar_kapak.jpg
    hikaye.txt
  02_Japonya/
    ...
  01-seckiden-bir-kare.jpg
```

- Klasörleri doğrudan ana klasörün içine aç; hikâyelerin içine ikinci bir klasör açma.
- Ana klasöre doğrudan koyduğun fotoğraflar **Seçkiler** grubuna eklenir.
- Hikâye klasörünün adı varsayılan başlıktır. `hikaye.txt` kullanırsan ilk satır başlık, ikinci satır kısa açıklama olur. Eski `seri.txt` dosyaları da desteklenir.
- Başındaki numara sıralama içindir. Kapak olacak fotoğrafın dosya adında `kapak` geçsin.
- Fotoğraf adında kısa, anlaşılır konu adı kullan: `01_kyoto-yagmurda-sokak.jpg`. Başlık metadatası olmayan karelerde site dosya adını kullanır.

## Lightroom ve Leica’dan ekleme

Her uygulamada dışa aktarılan dosyayı aynı yere kaydet: **Paylaş → Dosyalara Kaydet → iCloud Drive → dalbaris Fotoğraflar → hikâye klasörü**.

- **Lightroom Mobile:** Paylaş → Farklı Dışa Aktar → JPG, kalite 95, renk alanı sRGB, en büyük boyut veya uzun kenar 4000 px. Filigranı kapalı bırak.
- **Lightroom masaüstü:** Dışa aktarmada JPG, kalite 95, sRGB ve uzun kenar 4000 px seç. Daha büyük kaydedersen Mac gönderim kopyasını 4000 px’e indirir.
- **Leica FOTOS:** DNG yerine JPG seçip Dosyalara Kaydet. Leica FOTOS DNG aktarabildiği için ham dosyayı ayrı arşivinde tut.
- **Leica LUX / iPhone Fotoğraflar:** Paylaş → Dosyalara Kaydet. HEIC/HEIF dosyaları Mac’te JPG’ye çevrilir.

DNG/RAW siteye gönderilmez; Lightroom’dan yüksek kaliteli JPG dışa aktar. HEIC özgünü ve büyük kaynak dosyalar iCloud’daki asıl klasörde korunur. Mac sadece geçici kopyayı dönüştürür veya 4000 px’e indirir.

## Site görselleri nasıl hazırlanır?

Kaynak görselin yönü ve sRGB renkleri korunur. Sitede otomatik olarak:

| Kullanım | Boyut | Biçim |
|---|---:|---|
| Galeri ve hikâye kapakları | 640, 1280, 2400 px | WebP |
| Eski tarayıcı yedeği | En fazla 1600 px | JPEG |
| Görüntüleyicide 1:1 yakınlaştırma | Uzun kenar en fazla 4000 px | JPEG, yüksek kalite |

Sayfa, ekranın ihtiyacına göre uygun WebP boyutunu yükler; tam boyutlu JPEG’i yalnız 1:1 yakınlaştırmada kullanır. Site için üretilen görsellerden EXIF/GPS bilgileri silinir.

Fotoğrafı veya klasörü iCloud’dan silersen site sürümü de sonraki yayında silinir. Mac ve iPhone iCloud eşitlemesi bitince gönderim birkaç dakika sürer.

---

## İlk kurulum (bir kez): Cloudflare'e bağlama

1. **GitHub izni:** github.com → Settings → Applications → Installed GitHub Apps → **Cloudflare Workers and Pages** → Configure → Repository access'e **dalbaris**'i ekle → Save.
2. **Cloudflare:** dash.cloudflare.com → Workers & Pages → **Create** → **Import a repository** → hesap Ronin677 → **dalbaris** (dal-os değil!) → Next.
3. Ayarlar:
   - Proje adı: `dalbaris`
   - Derleme komutu (Build command): `npm run build`
   - Yayın komutu (Deploy command): `npx wrangler deploy`
   - Kök dizin: boş bırak
4. **Deploy**. İlk derleme birkaç dakika sürer. `dalbaris.com` ve `www.dalbaris.com` adresleri `wrangler.jsonc` içinde tanımlı, otomatik bağlanır.
