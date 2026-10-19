// dalbaris.com derleyici
// fotograflar/<seri>/*.jpg → dist/ (boyutlandırılmış, GPS ve tüm meta veriler silinmiş görseller + tek sayfa site)
import fs from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";
import exifr from "exifr";

const KOK = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const KAYNAK = path.join(KOK, "fotograflar");
const CIKTI = path.join(KOK, "dist");
const GORSEL = path.join(CIKTI, "g");
const GENISLIKLER = [640, 1280, 2400];
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
    const kareler = [];
    for (const f of dosyalar) {
      const kaynak = path.join(klasor, f);
      const temel = path.parse(f).name;
      let e = null;
      try { e = await exifr.parse(kaynak, { tiff: true, exif: true, iptc: true, xmp: true, gps: false }); } catch {}
      const bilgiC = cekimBilgisi(e);
      const baslikMeta = e && (e.title?.value || e.title || e.ObjectName || e.Headline);
      const baslik = (typeof baslikMeta === "string" && baslikMeta.trim()) || dosyaAdindanBaslik(temel) || "";
      const aciklamaMeta = e && (e.description?.value || e.description || e.Caption || e.ImageDescription);
      const ad = `${id}-${slug(temel) || kareler.length}`;
      // rotate(): EXIF yönünü uygular. sharp varsayılan olarak tüm meta verileri (GPS dahil) çıktıdan siler.
      const { info: { width: W, height: H } } = await sharp(kaynak, { failOn: "none" }).rotate().toBuffer({ resolveWithObject: true });
      const genislikler = [...new Set(GENISLIKLER.map(w => Math.min(w, W)))];
      for (const w of genislikler) {
        const temelG = sharp(kaynak, { failOn: "none" }).rotate().resize({ width: w, withoutEnlargement: true }).toColorspace("srgb");
        await temelG.clone().webp({ quality: w >= 2400 ? 86 : 80 }).toFile(path.join(GORSEL, `${ad}-${w}.webp`));
        await temelG.clone().avif({ quality: w >= 2400 ? 62 : 55, effort: 4 }).toFile(path.join(GORSEL, `${ad}-${w}.avif`));
      }
      await sharp(kaynak, { failOn: "none" }).rotate().resize({ width: 1600, withoutEnlargement: true }).toColorspace("srgb")
        .jpeg({ quality: 84, mozjpeg: true }).toFile(path.join(GORSEL, `${ad}.jpg`));
      kareler.push({
        ad, w: W, h: H, gw: genislikler, baslik,
        aciklama: typeof aciklamaMeta === "string" ? aciklamaMeta.trim() : "",
        bilgi: bilgiC.satir, kamera: bilgiC.kamera, lens: bilgiC.lens,
        tarih: bilgiC.tarih ? bilgiC.tarih.toISOString() : null,
        kapak: /kapak/i.test(temel)
      });
      console.log(`✓ ${k.name}/${f}`);
    }
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
