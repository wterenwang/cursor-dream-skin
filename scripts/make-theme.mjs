// Build a theme directory (image + theme.json) from any picture.
// Dominant-color extraction is dependency-free:
//   - macOS: `sips` → small BMP
//   - Windows: PowerShell System.Drawing → sample pixels
//   - fallback: dark purple defaults if neither sampler works
//
// Usage (run with ELECTRON_RUN_AS_NODE=1 <Cursor binary> make-theme.mjs …):
//   --image PATH          source picture (png/jpg/jpeg/webp)
//   --id ID               theme id (directory name), e.g. "pikachu"
//   --name NAME           display name, e.g. "Pikachu"
//   [--out-dir DIR]       parent dir for the theme (default: <project>/themes)
//   [--mode auto|dark|light]  skin brightness (default auto from image)
//   [--accent #rrggbb]    override extracted accent color
//   [--editor-opacity N]  0.5-1.0 editor surface opacity (default 0.88 dark / 0.90 light)

import fs from "node:fs/promises";
import { readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");

function parseArgs(argv) {
  const options = { outDir: path.join(root, "themes"), mode: "auto", accent: null, editorOpacity: null };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--image") options.image = path.resolve(argv[++i]);
    else if (arg === "--id") options.id = argv[++i];
    else if (arg === "--name") options.name = argv[++i];
    else if (arg === "--out-dir") options.outDir = path.resolve(argv[++i]);
    else if (arg === "--mode") options.mode = argv[++i];
    else if (arg === "--accent") options.accent = argv[++i];
    else if (arg === "--editor-opacity") options.editorOpacity = Number(argv[++i]);
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!options.image) throw new Error("--image is required");
  if (!options.id || !/^[a-z0-9][a-z0-9-]{0,60}$/.test(options.id)) {
    throw new Error("--id is required: lowercase letters, digits and dashes only");
  }
  if (!options.name) options.name = options.id;
  if (!["auto", "dark", "light"].includes(options.mode)) throw new Error(`Invalid --mode: ${options.mode}`);
  if (options.accent && !/^#[0-9a-f]{6}$/i.test(options.accent)) throw new Error("--accent must be #rrggbb");
  if (options.editorOpacity !== null && !(options.editorOpacity >= 0.5 && options.editorOpacity <= 1)) {
    throw new Error("--editor-opacity must be between 0.5 and 1.0");
  }
  return options;
}

// ---- pixel samplers ----

function parseBmpPixels(buf) {
  if (buf.readUInt16LE(0) !== 0x4d42) throw new Error("Not a BMP file");
  const dataOffset = buf.readUInt32LE(10);
  const width = buf.readInt32LE(18);
  const heightRaw = buf.readInt32LE(22);
  const height = Math.abs(heightRaw);
  const bpp = buf.readUInt16LE(28);
  if (![24, 32].includes(bpp)) throw new Error(`Unsupported BMP bit depth: ${bpp}`);
  const bytesPerPixel = bpp / 8;
  const rowSize = Math.ceil((width * bytesPerPixel) / 4) * 4;
  const pixels = [];
  for (let y = 0; y < height; y += 1) {
    const row = dataOffset + y * rowSize;
    for (let x = 0; x < width; x += 1) {
      const p = row + x * bytesPerPixel;
      pixels.push([buf[p + 2], buf[p + 1], buf[p]]); // BGR -> RGB
    }
  }
  return pixels;
}

function readPixelsViaSips(imagePath) {
  const tmp = path.join(os.tmpdir(), `cds-theme-${process.pid}.bmp`);
  execFileSync("/usr/bin/sips", ["-s", "format", "bmp", "-z", "48", "48", imagePath, "--out", tmp], { stdio: "ignore" });
  const buf = readFileSync(tmp);
  rmSync(tmp, { force: true });
  return parseBmpPixels(buf);
}

function readPixelsViaWindowsPowerShell(imagePath) {
  const ps = `
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile('${imagePath.replace(/'/g, "''")}')
$bmp = New-Object System.Drawing.Bitmap 48, 48
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, 0, 0, 48, 48)
$g.Dispose(); $img.Dispose()
$sb = New-Object System.Text.StringBuilder
for ($y = 0; $y -lt 48; $y++) {
  for ($x = 0; $x -lt 48; $x++) {
    $c = $bmp.GetPixel($x, $y)
    [void]$sb.AppendFormat("{0},{1},{2};", $c.R, $c.G, $c.B)
  }
}
$bmp.Dispose()
Write-Output $sb.ToString()
`.trim();
  const out = execFileSync("powershell.exe", [
    "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", ps,
  ], { encoding: "utf8", windowsHide: true });
  const pixels = [];
  for (const part of out.trim().split(";")) {
    if (!part) continue;
    const [r, g, b] = part.split(",").map(Number);
    if ([r, g, b].every((n) => Number.isFinite(n))) pixels.push([r, g, b]);
  }
  if (pixels.length < 16) throw new Error("PowerShell sampler returned too few pixels");
  return pixels;
}

function defaultStats() {
  return { avgLum: 0.25, baseHue: 260, avgSat: 0.35, accentHue: 270, accentSat: 0.6 };
}

function readPixels(imagePath) {
  if (process.platform === "darwin") {
    try { return readPixelsViaSips(imagePath); } catch { /* fall through */ }
  }
  if (process.platform === "win32") {
    try { return readPixelsViaWindowsPowerShell(imagePath); } catch { /* fall through */ }
  }
  return null;
}

// ---- color math ----

function rgbToHsl([r, g, b]) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return [0, 0, l];
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h;
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  else if (max === g) h = ((b - r) / d + 2) / 6;
  else h = ((r - g) / d + 4) / 6;
  return [h * 360, s, l];
}

function hslToRgb(h, s, l) {
  h = ((h % 360) + 360) % 360 / 360;
  if (s === 0) {
    const v = Math.round(l * 255);
    return [v, v, v];
  }
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const hue = (t) => {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };
  return [hue(h + 1 / 3), hue(h), hue(h - 1 / 3)].map((v) => Math.round(v * 255));
}

const rgba = (h, s, l, a) => {
  const [r, g, b] = hslToRgb(h, s, l);
  return a >= 1 ? `rgb(${r}, ${g}, ${b})` : `rgba(${r}, ${g}, ${b}, ${a})`;
};
const hex = (h, s, l) => {
  const [r, g, b] = hslToRgb(h, s, l);
  return `#${[r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("")}`;
};

function analyze(pixels) {
  let lumSum = 0;
  const hueBins = new Array(36).fill(0);
  const hueSat = new Array(36).fill(0);
  let weightSum = 0, hueXSum = 0, hueYSum = 0, satSum = 0;
  for (const px of pixels) {
    const [h, s, l] = rgbToHsl(px);
    lumSum += l;
    // saturated mid-tones vote for the accent hue
    if (s > 0.25 && l > 0.18 && l < 0.92) {
      const bin = Math.floor(h / 10) % 36;
      const weight = s * (1 - Math.abs(l - 0.5));
      hueBins[bin] += weight;
      hueSat[bin] += s;
    }
    // circular mean of all hues weighted by saturation -> base tint
    const w = s;
    hueXSum += Math.cos((h * Math.PI) / 180) * w;
    hueYSum += Math.sin((h * Math.PI) / 180) * w;
    satSum += s;
    weightSum += w;
  }
  const avgLum = lumSum / pixels.length;
  const baseHue = weightSum > 0.01
    ? ((Math.atan2(hueYSum, hueXSum) * 180) / Math.PI + 360) % 360
    : 260;
  const avgSat = satSum / pixels.length;

  let bestBin = 0;
  for (let i = 1; i < 36; i += 1) if (hueBins[i] > hueBins[bestBin]) bestBin = i;
  const hasAccent = hueBins[bestBin] > 0.5;
  const accentHue = hasAccent ? bestBin * 10 + 5 : baseHue;
  const accentSat = hasAccent ? Math.min(Math.max(hueSat[bestBin] / Math.max(hueBins[bestBin], 0.001) * 0.9, 0.5), 0.85) : 0.55;
  return { avgLum, baseHue, avgSat, accentHue, accentSat };
}

function buildColors(stats, mode, accentOverride, editorOpacity) {
  const dark = mode === "dark" || (mode === "auto" && stats.avgLum < 0.62);
  const h = stats.baseHue;
  const s = Math.min(stats.avgSat * 1.3, dark ? 0.45 : 0.30);
  const accent = accentOverride ?? hex(stats.accentHue, stats.accentSat, dark ? 0.68 : 0.42);
  const editorA = editorOpacity ?? (dark ? 0.90 : 0.92);
  if (dark) {
    return {
      mode: "dark",
      colors: {
        dim: "rgba(4, 3, 10, 0.22)",
        chrome: rgba(h, s, 0.11, 0.72),
        sidebar: rgba(h, s, 0.09, 0.62),
        editor: rgba(h, s, 0.08, editorA),
        aiPane: rgba(h, s, 0.10, 0.70),
        input: rgba(h, s, 0.16, 0.92),
        // Near-opaque so chat code blocks stay readable over wallpaper.
        widget: rgba(h, s, 0.13, 0.97),
        foreground: hex(h, 0.08, 0.96),
        mutedForeground: rgba(h, 0.08, 0.96, 0.70),
        accent,
        line: `${accent}40`,
      },
    };
  }
  return {
    mode: "light",
    colors: {
      dim: "rgba(255, 255, 255, 0.22)",
      chrome: rgba(h, s, 0.96, 0.68),
      sidebar: rgba(h, s, 0.95, 0.58),
      editor: rgba(h, s, 0.98, editorA),
      aiPane: rgba(h, s, 0.96, 0.64),
      input: rgba(h, s, 0.99, 0.90),
      widget: rgba(h, s, 0.97, 0.96),
      foreground: hex(h, 0.30, 0.13),
      mutedForeground: rgba(h, 0.30, 0.13, 0.62),
      accent,
      line: `${accent}40`,
    },
  };
}

const options = parseArgs(process.argv.slice(2));
const extension = path.extname(options.image).toLowerCase();
if (![".png", ".jpg", ".jpeg", ".webp"].includes(extension)) {
  throw new Error(`Unsupported image format: ${extension || "missing"}`);
}
await fs.access(options.image);

const sampled = readPixels(options.image);
const stats = sampled ? analyze(sampled) : defaultStats();
const { mode, colors } = buildColors(stats, options.mode, options.accent, options.editorOpacity);

const themeDir = path.join(options.outDir, options.id);
await fs.mkdir(themeDir, { recursive: true });
const imageName = `art${extension}`;
await fs.copyFile(options.image, path.join(themeDir, imageName));

const theme = {
  schemaVersion: 1,
  id: options.id,
  name: options.name,
  mode,
  builtin: false,
  custom: true,
  hidden: false,
  image: imageName,
  artFit: "cover",
  artPosition: "center",
  artFilter: "none",
  colors,
};
await fs.writeFile(path.join(themeDir, "theme.json"), `${JSON.stringify(theme, null, 2)}\n`);

console.log(JSON.stringify({
  pass: true,
  themeDir,
  mode,
  stats: {
    averageLuminance: Number(stats.avgLum.toFixed(3)),
    baseHue: Math.round(stats.baseHue),
    accentHue: Math.round(stats.accentHue),
  },
  colors,
}, null, 2));
