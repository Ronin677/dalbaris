# dalbaris.com — Fotoğraf nasıl eklenir

Site, `fotograflar/` klasöründeki fotoğraflardan kendini otomatik kurar. Yeni fotoğraf yükleyince Cloudflare siteyi 1–2 dakikada yeniden yayınlar.

## 1. Lightroom'dan dışa aktar

- **Dosya türü:** JPEG, kalite 90
- **Renk alanı:** sRGB (önemli, yoksa renkler bazı ekranlarda soluk görünür)
- **Boyut:** Uzun kenar 3000 piksel
- **Meta veri:** "Tümü" kalabilir. GPS ve diğer bilgiler sitede otomatik silinir. Sadece çekim bilgisi (diyafram, enstantane, ISO, lens) ve başlık okunur.
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

GitHub'da `dalbaris` deposunu aç → `fotograflar` klasörüne gir → **Add file → Upload files** → fotoğrafları sürükle → **Commit changes**. Telefondan da yapılabilir.

Bir fotoğrafı kaldırmak için GitHub'da dosyayı açıp çöp kutusu simgesine bas.
