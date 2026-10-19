// dalbaris.com derleyici
// fotograflar/<seri>/*.jpg → dist/ (boyutlandırılmış, GPS ve tüm meta veriler silinmiş görseller + tek sayfa site)
import fs from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import exifr from "exifr";
import os from "node:os";

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const KAYNAK = path.join(KOK, "fotograflar");
const CIKTI = path.join(KOK, "dist");
const GORSEL = path.join(CIKTI, "g");
const GENISLIKLER = [640, 1280, 2400];
const UZUN_SINIR = 4000; // tam çözünürlük sürümünün uzun kenar sınırı (piksel)
const UZANTILAR = new Set([".jpg", ".jpeg", ".png", ".tif", ".tiff", ".webp", ".heic", ".avif"]);

const trKucuk = s => s.toLocaleLowerCase("tr-TR");
const slug = s => trKucuk(s)
  .replace(/ç/g, "c").replace(/ğ/g, "g").replace(/ı/g, "i").replace(/ö/g, "o").replace(/ş/g, "s").replace(/ü/g, "u")
  .normalize("NFKD").replace(/[^\w\s-]/g, "").trim().replace(/[\s_]+/g, "-").replace(/-+/g, "-");
// "01_ayder-sabahi" → "Ayder sabahı" değil, dosya adı olduğu gibi okunaklı hale gelir
const dosyaAdindanBaslik = ad => {
  const t = ad.replace(/[\s._-]*kapak[\s._-]*/i, " ").replace(/^\d+[\s._-]*/, "").replace(/[_-]+/g, " ").replace(/\s+/g, " ").trim();
  if (!t || /^(l\d{6,}|dsc|img|_?mg|p\d{6,})/i.test(t)) return "";
  return t.charAt(0).toLocaleUpperCase("tr-TR") + t.slice(1);
};
const kacis = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

function cekimBilgisi(e) {
  if (!e) return { satir: "", kamera: "", tarih: null };
  const p = [];
  if (e.FNumber) p.push(`f/${+(+e.FNumber).toFixed(1)}`);
  if (e.ExposureTime) p.push(e.ExposureTime >= 1 ? `${+(+e.ExposureTime).toFixed(1)}s` : `1/${Math.round(1 / e.ExposureTime)}`);
  if (e.ISO) p.push(`ISO ${e.ISO}`);
  if (e.FocalLength) p.push(`${Math.round(e.FocalLength)}mm`);
  let kamera = [e.Make, e.Model].filter(Boolean).join(" ").trim();
  if (e.Make && e.Model && String(e.Model).toLowerCase().startsWith(String(e.Make).toLowerCase().split(" ")[0])) kamera = String(e.Model);
  kamera = kamera.replace(/\bLEICA\b/g, "Leica").replace(/\bCAMERA AG\b/gi, "").trim();
  const lens = e.LensModel ? String(e.LensModel).trim() : "";
  const tarih = e.DateTimeOriginal instanceof Date ? e.DateTimeOriginal : (e.CreateDate instanceof Date ? e.CreateDate : null);
  return { satir: p.join(" · "), kamera, lens, tarih };
}

async function seriBilgisi(klasor, ad) {
  // İsteğe bağlı seri.txt: 1. satır seri adı, 2. satır kısa açıklama
  try {
    const [ilk = "", ikinci = ""] = (await fs.readFile(path.join(klasor, "seri.txt"), "utf8")).split(/\r?\n/).map(s => s.trim());
    return { ad: ilk || ad, aciklama: ikinci };
  } catch { return { ad, aciklama: "" }; }
}

// Sırayı koruyarak en fazla N işi aynı anda çalıştırır
async function havuz(liste, is, n = Math.max(2, os.availableParallelism?.() ?? os.cpus().length)) {
  const sonuc = new Array(liste.length); let sira = 0;
  await Promise.all(Array.from({ length: Math.min(n, liste.length) }, async () => {
    while (sira < liste.length) { const i = sira++; sonuc[i] = await is(liste[i], i); }
  }));
  return sonuc;
}

async function main() {
  await fs.rm(CIKTI, { recursive: true, force: true });
  await fs.mkdir(GORSEL, { recursive: true });
  await fs.cp(path.join(KOK, "public"), CIKTI, { recursive: true }).catch(() => {});

  const seriler = [];
  const klasorler = (await fs.readdir(KAYNAK, { withFileTypes: true }).catch(() => []))
    .filter(d => d.isDirectory() && !d.name.startsWith("."));

  for (const k of klasorler) {
    const klasor = path.join(KAYNAK, k.name);
    const adHam = k.name.replace(/^\d+[\s._-]*/, "").replace(/[_-]+/g, " ").trim();
    const bilgi = await seriBilgisi(klasor, adHam.charAt(0).toLocaleUpperCase("tr-TR") + adHam.slice(1));
    const id = slug(bilgi.ad) || slug(k.name);
    const dosyalar = (await fs.readdir(klasor)).filter(f => UZANTILAR.has(path.extname(f).toLowerCase())).sort((a, b) => a.localeCompare(b, "tr"));
    // Kareler paralel işlenir (çekirdek sayısı kadar), sıra korunur
    const kareler = await havuz(dosyalar, async (f, i) => {
      const kaynak = path.join(klasor, f);
      const temel = path.parse(f).name;
      let e = null;
      try { e = await exifr.parse(kaynak, { tiff: true, exif: true, iptc: true, xmp: true, gps: false }); } catch {}
      const bilgiC = cekimBilgisi(e);
      const baslikMeta = e && (e.title?.value || e.title || e.ObjectName || e.Headline);
      const baslik = (typeof baslikMeta === "string" && baslikMeta.trim()) || dosyaAdindanBaslik(temel) || "";
      const aciklamaMeta = e && (e.description?.value || e.description || e.Caption || e.ImageDescription);
      const ad = `${id}-${slug(temel) || i}`;
      // rotate(): EXIF yönünü uygular. sharp varsayılan olarak tüm meta verileri (GPS dahil) çıktıdan siler;
      // withIccProfile("srgb") yalnız renk profilini geri gömer ki renkler her ekranda doğru görünsün.
      // Tek çözümleme: döndürülmüş, sRGB'ye çevrilmiş ham piksel, tüm boyutlar bundan üretilir.
      const { data: ham, info } = await sharp(kaynak, { failOn: "none", limitInputPixels: false })
        .rotate().toColorspace("srgb").removeAlpha().raw().toBuffer({ resolveWithObject: true });
      const pikselden = () => sharp(ham, { raw: { width: info.width, height: info.height, channels: info.channels } });
      // Tam çözünürlük: uzun kenar UZUN_SINIR'a kadar küçültülür (büyütülmez)
      const oran = Math.min(1, UZUN_SINIR / Math.max(info.width, info.height));
      const W = Math.round(info.width * oran), H = Math.round(info.height * oran);
      const genislikler = [...new Set(GENISLIKLER.filter(w => w < W).concat(Math.min(GENISLIKLER.at(-1), W)))].sort((a, b) => a - b);
      await Promise.all([
        ...genislikler.map(w => pikselden().resize({ width: w, kernel: "lanczos3" }).withIccProfile("srgb")
          .webp({ quality: w >= 2400 ? 90 : 82, smartSubsample: true }).toFile(path.join(GORSEL, `${ad}-${w}.webp`))),
        // Büyük görüntüleyicideki "en büyük hal": JPEG 92, renk inceltmesi yok (4:4:4) — renk kenarları da korunur
        pikselden().resize({ width: W, kernel: "lanczos3" }).withIccProfile("srgb")
          .jpeg({ quality: 92, chromaSubsampling: "4:4:4", optimiseCoding: true }).toFile(path.join(GORSEL, `${ad}-tam.jpg`)),
        // Eski tarayıcılar ve paylaşım önizlemesi için
        pikselden().resize({ width: Math.min(1600, W), kernel: "lanczos3" }).withIccProfile("srgb")
          .jpeg({ quality: 84, mozjpeg: true }).toFile(path.join(GORSEL, `${ad}.jpg`))
      ]);
      console.log(`✓ ${k.name}/${f}`);
      return {
        ad, w: W, h: H, gw: genislikler, baslik,
        aciklama: typeof aciklamaMeta === "string" ? aciklamaMeta.trim() : "",
        bilgi: bilgiC.satir, kamera: bilgiC.kamera, lens: bilgiC.lens,
        tarih: bilgiC.tarih ? bilgiC.tarih.toISOString() : null,
        kapak: /kapak/i.test(temel)
      };
    });
    if (!kareler.length) continue;
    const tarihler = kareler.map(x => x.tarih).filter(Boolean).sort();
    seriler.push({ id, ad: bilgi.ad, aciklama: bilgi.aciklama, kareler, son: tarihler.at(-1) || null, ilk: tarihler[0] || null });
  }

  // En yeni seri en üstte
  seriler.sort((a, b) => (b.son || "").localeCompare(a.son || ""));
  const tum = seriler.flatMap(s => s.kareler.map(x => ({ ...x, seri: s.id })));
  const kapak = tum.find(x => x.kapak) || tum.find(x => x.w / x.h >= 1.3) || tum[0] || null;

  const ayYil = iso => iso ? new Date(iso).toLocaleDateString("tr-TR", { month: "long", year: "numeric" }).toLocaleUpperCase("tr-TR") : "";
  const sonSeri = seriler[0];
  const veri = { seriler: seriler.map(({ kareler, ...s }) => ({ ...s, adet: kareler.length, kapak: (kareler.find(x => x.kapak) || kareler[0]).ad })), kareler: tum, kapak: kapak?.ad || null };

  let html = await fs.readFile(path.join(KOK, "sablon", "index.html"), "utf8");
  const kapakGorsel = kapak ? `https://dalbaris.com/g/${kapak.ad}.jpg` : "https://dalbaris.com/paylasim.jpg";
  html = html
    .replace("/*__VERI__*/null", JSON.stringify(veri).replace(/</g, "\\u003c"))
    .replace(/__SON_EKLENEN__/g, kacis(sonSeri ? `${sonSeri.ad.toLocaleUpperCase("tr-TR")}${sonSeri.son ? " — " + ayYil(sonSeri.son) : ""}` : "YAKINDA"))
    .replace(/__KAPAK_GORSEL__/g, kacis(kapakGorsel))
    .replace(/__YIL__/g, String(new Date().getFullYear()));
  await fs.writeFile(path.join(CIKTI, "index.html"), html);
  console.log(`\n${seriler.length} seri, ${tum.length} kare derlendi → dist/`);
}

main().catch(e => { console.error(e); process.exit(1); });
