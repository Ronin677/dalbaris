# dalbaris.com — Fotoğraf nasıl eklenir

Site, `fotograflar/` klasöründeki fotoğraflardan kendini otomatik kurar. Yeni fotoğraf yükleyince Cloudflare siteyi birkaç dakikada yeniden yayınlar.

## Kalite nasıl korunuyor

Her fotoğraftan yayın sırasında otomatik olarak birkaç sürüm üretilir:

| Nerede | Boyut | Biçim |
|---|---|---|
| Izgara, seri kapakları | 640 / 1280 px | AVIF + WebP (hızlı açılsın diye) |
| Tıklayınca açılan görüntü | 2400 px | AVIF + WebP |
| **Tam çözünürlük** (büyük ekranlar, 1:1 yakınlaştırma, tam ekran) | Gönderdiğin boyut, uzun kenar en fazla 4000 px | JPEG kalite 92, renk inceltmesi yok (4:4:4) |

Görüntüleyici önce ekrana yetecek sürümü gösterir; 4K/5K ekranda ya da **1:1**'e basınca (çift tık / çift dokunuş / iki parmakla açma) tam çözünürlüğe geçer. Telefonda gereksiz yere büyük dosya indirilmez.

GPS ve diğer tüm kişisel meta veriler silinir; yalnız sRGB renk profili korunur.

## 1. Lightroom'dan dışa aktar

- **Dosya türü:** JPEG, **kalite 95**
- **Renk alanı:** **sRGB** (önemli, yoksa renkler bazı ekranlarda soluk görünür)
- **Boyut:** **Uzun kenar 4000 piksel** (daha büyüğü site tarafından zaten 4000'e indirilir, sadece yüklemeyi yavaşlatır)
- **Keskinleştirme:** Ekran için, Standart
- **Meta veri:** "Tümü" kalabilir. GPS sitede otomatik silinir. Sadece çekim bilgisi (diyafram, enstantane, ISO, lens) ve başlık okunur.
- **Başlık:** Lightroom'da fotoğrafa "Başlık" (Title) yazarsan sitede o görünür. Yazmazsan dosya adı kullanılır.

İpucu: Bu ayarları Lightroom'da bir dışa aktarma ön ayarı olarak kaydet ("dalbaris.com").

## 2. Seri klasörüne koy

Her seri bir klasördür:

```
fotograflar/
  01_karadeniz/
    01_ayder-sabahı_kapak.jpg   ← adında "kapak" geçen kare serinin ve sitenin kapağı olur
    02_yayla-evleri.jpg
    seri.txt                    ← isteğe bağlı: 1. satır seri adı, 2. satır kısa açıklama
  02_sokak/
    ...
```

- Klasör ve dosya adlarının başındaki numaralar sıralama içindir, sitede görünmez.
- En yeni çekilmiş seri sitede en üstte görünür.

## 3. Yükle

**Mac'ten (en kolayı):** Masaüstündeki **dalbaris Fotoğraflar** klasörüne seri klasörünü sürükle. Mac mini her dakika bakar, yenileri kendiliğinden gönderir ve bitince bildirim gösterir. Klasörden silinen fotoğraf siteden de kalkar. DNG/HEIC gönderilmez.

Masaüstü klasörü yoksa (yeni Mac vb.): depodaki `scripts/mac-kur.command` dosyasını bir kez çift tıkla.

**Telefondan ya da başka bilgisayardan:** GitHub'da `dalbaris` deposunu aç → `fotograflar` klasörüne gir → **Add file → Upload files** → fotoğrafları sürükle → **Commit changes**. Telefondan da yapılabilir. (GitHub sitesinden tek dosya en fazla 25 MB; 4000 px JPEG 95 bunun çok altında kalır.)

Bir fotoğrafı kaldırmak için GitHub'da dosyayı açıp çöp kutusu simgesine bas.

Her kareye kendi bağlantısı da verilir (ör. `dalbaris.com/#kare=karadeniz-ayder-sabahi`); görüntüleyici açıkken adres çubuğundaki bağlantıyı paylaşabilirsin.

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
