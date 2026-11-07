{ pkgs }:

# ocr-scan: screenshot a region, OCR it, copy the text.
# Everything it needs is in this file plus ocr-scan.sh next to it.

let
  # Tesseract's "best" models. nixpkgs only ships the "fast" ones, which are
  # about 5x smaller and clearly less accurate. Each file is pinned by hash.
  model = name: hash: {
    name = "${name}.traineddata";
    path = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/4.1.0/${name}.traineddata";
      inherit hash;
    };
  };

  tessdata = pkgs.linkFarm "tessdata-best" [
    (model "jpn"         "sha256-Nr35rII/WRHmJMMNBVPokLirx8MaZbPvFNqUNljEC3k=")
    (model "jpn_vert"    "sha256-Eli+brKphR8YBDI0rRjMoT7TJpC//2KzNciYu+o3FUg=")
    (model "kor"         "sha256-+IjUA4NIoMPSUVHn9FK9oNdMonWxjKsUZ5i8u5QIT/8=")
    (model "kor_vert"    "sha256-5scjJ2F8C/GVqai2MYJ78QLHVzW7uTISbm+hxGVsdWg=")
    (model "chi_sim"     "sha256-T+8tEwbI6HYW1NPkxsZ/r11EvjNCKQz48vD246p+c1s=")
    (model "chi_sim_vert" "sha256-6mcqeBVxmcMzqhLsTnRVAHdom1Rd9fx3CQNxaFDIsuU=")
    (model "chi_tra"     "sha256-GqYEiFdMr6aUhtkZKE8HnKm2j8x/atjcH/GzGN/ZcCg=")
    (model "chi_tra_vert" "sha256-u+UY+UueOFIQkRNQc1e/5+JXg02I0tHq1EF4BGvNIYE=")
  ];

  py = pkgs.python3.withPackages (ps: [ ps.pillow ps.numpy ]);

  # The image-cleanup + multi-attempt OCR logic, kept inline so there is no
  # extra file for a flake to ignore. Two stages: a quick pass, then (only if
  # the quick pass is unsure) extra variants for noise, tilt and colour.
  ocrBestPy = pkgs.writeText "ocr-best.py" ''
#!/usr/bin/env python3
"""ocr-best IMAGE LANG PSM

Runs tesseract on several cleaned-up versions of IMAGE and prints the reading
the versions agree on most, weighted by tesseract's confidence.

Stage 1 (always, fast): the image as a light-background greyscale, rescaled to
the size the model likes, plus three black-and-white variants.

Stage 2 (only when stage 1 is shaky, i.e. low confidence or the variants
disagree with each other): extra variants aimed at the usual troublemakers.
  * deskewed (tilted text)
  * denoised (grain, halftone, textured backgrounds)
  * a larger scale (the size estimate is a guess, small text reads better bigger)
  * colour-distance map (text that differs from its background by hue, not
    brightness, plus outlined text on gradients)

Choosing: every reading is compared with the strongest others. A reading that
many independent variants agree on beats one stray high-confidence reading,
which is how tesseract's hallucinations on noisy backgrounds get filtered.

Needs: tesseract on PATH, Pillow, numpy. Language data comes from
TESSDATA_PREFIX like normal tesseract. OCR_DEBUG=1 prints every reading.
"""
import csv
import io
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from difflib import SequenceMatcher

import numpy as np
from PIL import Image, ImageFilter, ImageOps

LINE_TARGET = 48      # px: height we try to bring one line of text to
MAX_SIDE = 3200       # px: never feed tesseract anything bigger than this
MARGIN = 24           # px: white border around the text
GOOD_QUALITY = 0.80   # stage 1 is accepted if the winner is at least this sure...
GOOD_AGREEMENT = 0.85  # ...and this many of the variants agree with it
MIN_QUALITY = 0.12    # below this the "text" is noise, report nothing
NON_ASCII_GAP = re.compile(r"(?<=[^\x00-\x7f])[ \t]+(?=[^\x00-\x7f])")


# ---------------------------------------------------------------- image helpers

def otsu(gray: np.ndarray) -> int:
    hist = np.bincount(gray.ravel(), minlength=256).astype(np.float64)
    levels = np.arange(256)
    w0 = np.cumsum(hist)
    w1 = gray.size - w0
    s0 = np.cumsum(hist * levels)
    m0 = s0 / np.maximum(w0, 1)
    m1 = (s0[-1] - s0) / np.maximum(w1, 1)
    return int(np.argmax(w0 * w1 * (m0 - m1) ** 2))


def load_rgb(path: str) -> Image.Image:
    img = Image.open(path)
    if img.mode in ("RGBA", "LA", "P"):
        img = img.convert("RGBA")
        bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
        img = Image.alpha_composite(bg, img)
    return img.convert("RGB")


def border_value(gray: Image.Image) -> int:
    a = np.asarray(gray)
    return int(np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])))


def dark_text_on_light(gray: Image.Image) -> Image.Image:
    """Flip the image if the background is dark."""
    a = np.asarray(gray)
    t = otsu(a)
    ring = np.concatenate([a[:2].ravel(), a[-2:].ravel(), a[:, :2].ravel(), a[:, -2:].ravel()])
    if np.median(ring) <= t:  # dark background
        return ImageOps.invert(gray)
    return gray


def ink_mask(gray: Image.Image) -> np.ndarray:
    """Boolean mask of probable ink (dark text on a light background).

    A single global threshold is used when it gives a plausible amount of ink.
    On gradients it would call half the picture ink, so then we look for pixels
    that are darker than their surroundings instead.
    """
    gray = gray.filter(ImageFilter.GaussianBlur(1.2))  # grain must not look like ink
    a = np.asarray(gray)
    glob = a <= otsu(a)
    if glob.mean() <= 0.35:
        return glob
    sigma = float(np.clip(min(gray.size) * 0.15, 6, 40))
    bg = np.asarray(gray.filter(ImageFilter.GaussianBlur(sigma))).astype(np.int16)
    d = np.clip(bg - a.astype(np.int16), 0, 255).astype(np.uint8)
    return d > max(otsu(d), 12)


def text_extent(gray: Image.Image, vertical: bool):
    """Median thickness (px) of a text line, and how many lines there are."""
    ink = ink_mask(gray)
    prof = ink.sum(axis=0 if vertical else 1)
    span = ink.shape[0 if vertical else 1]
    on = prof > max(1, 0.01 * span)
    runs, n = [], 0
    for v in on:
        if v:
            n += 1
        elif n:
            runs.append(n)
            n = 0
    if n:
        runs.append(n)
    runs = [r for r in runs if r >= 4]
    if not runs:
        return None, 1
    return float(np.median(runs)), len(runs)


def skew_angle(gray: Image.Image, vertical: bool):
    """Estimate how far the text lines are tilted.

    Returns (degrees to rotate with PIL's counter-clockwise convention, how much
    sharper the line profile gets at that angle compared to no rotation).
    """
    ink = Image.fromarray((ink_mask(gray) * 255).astype(np.uint8))
    ink.thumbnail((640, 640))
    axis = 0 if vertical else 1

    def sharp(ang: float) -> float:
        r = np.asarray(ink.rotate(ang, resample=Image.BILINEAR)).astype(np.float64)
        return float((np.diff(r.sum(axis=axis)) ** 2).sum())

    base = sharp(0.0)
    if base <= 0:
        return 0.0, 1.0
    _, ang = max((sharp(a), a) for a in np.arange(-10, 10.01, 0.5))
    s, ang = max((sharp(a), a) for a in np.arange(ang - 0.4, ang + 0.41, 0.1))
    return float(ang), s / base


def rescale(img: Image.Image, factor: float) -> Image.Image:
    w, h = img.size
    factor = min(factor, MAX_SIDE / max(w, h))
    if abs(factor - 1) < 0.03:
        return img
    size = (max(1, round(w * factor)), max(1, round(h * factor)))
    return img.resize(size, Image.LANCZOS)


def pad(img: Image.Image) -> Image.Image:
    return ImageOps.expand(img, border=MARGIN, fill=255)


def binarize(img: Image.Image, offset: int = 0) -> Image.Image:
    """One global black/white threshold (Otsu), nudged by `offset`."""
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(0.8)))
    return Image.fromarray(((a > otsu(a) + offset) * 255).astype(np.uint8))


def binarize_local(img: Image.Image, window: int, k: float = 0.12) -> Image.Image:
    """Local threshold: a pixel is ink if clearly darker than its surroundings.
    Copes with gradients, outlines and uneven backgrounds."""
    a = np.asarray(img.filter(ImageFilter.GaussianBlur(0.8))).astype(np.float64)
    w = int(window) | 1
    p = np.pad(a, w // 2, mode="edge")
    ii = np.pad(p.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    h, wd = a.shape
    s = ii[w:w + h, w:w + wd] - ii[:h, w:w + wd] - ii[w:w + h, :wd] + ii[:h, :wd]
    return Image.fromarray(np.where(a < s / (w * w) * (1 - k), 0, 255).astype(np.uint8))


def colour_distance_map(rgb: Image.Image) -> Image.Image:
    """Greyscale picture where anything unlike its local background is dark.

    `rgb` must already be scaled so a line of text is about LINE_TARGET px high.
    The background colour is the local median over about a line and a half, so
    gradients cancel out, and text that differs from the background in hue but
    not in brightness still shows up. (The median runs on a 6x smaller copy,
    on the full-size picture it would take ten seconds.)
    """
    w, h = rgb.size
    f = 6
    small = rgb.resize((max(1, w // f), max(1, h // f)), Image.BOX)
    size = int(LINE_TARGET * 1.5 / f) | 1
    size = min(size, (min(small.size) - 1) | 1)
    if size >= 3:
        small = small.filter(ImageFilter.MedianFilter(size))
    bg = small.resize((w, h), Image.BILINEAR)
    d = np.sqrt(((np.asarray(rgb).astype(np.float64) - np.asarray(bg).astype(np.float64)) ** 2).sum(axis=2))
    hi = max(float(np.percentile(d, 99)), 20.0)
    return Image.fromarray((255 - np.clip(d * 255 / hi, 0, 255)).astype(np.uint8))


# ------------------------------------------------------------------- candidates

def prepare(gray: Image.Image, vertical: bool):
    """Scale factor that brings the text lines to LINE_TARGET, and the line count."""
    height, nlines = text_extent(gray, vertical)
    base = LINE_TARGET / height if height else 2.0
    return min(max(base, 0.4), 5.0), nlines


class PsmMix:
    """Hands out tesseract page-segmentation modes, alternating between two.

    Every variant using the same mode would share the same blind spots (psm 6
    sometimes drops a whole line that psm 4 reads fine), so for horizontal text
    the variants take turns: line mode and block mode for one line, block mode
    and column mode for several. The line count is only an estimate, this also
    covers it being wrong.
    """

    def __init__(self, nlines: int, vertical: bool, psm: int):
        if vertical:
            self.modes = [psm]
        elif nlines == 1:
            self.modes = [7, 6]
        else:
            self.modes = [psm, 4]
        self.i = 0

    def next(self) -> int:
        m = self.modes[self.i % len(self.modes)]
        self.i += 1
        return m


def window_for() -> int:
    return max(15, int(LINE_TARGET * 1.2))


def stage1(rgb: Image.Image, vertical: bool, psm: int):
    gray = ImageOps.autocontrast(dark_text_on_light(rgb.convert("L")), cutoff=1)
    base, nlines = prepare(gray, vertical)
    main = rescale(gray, base)
    window = window_for()
    mix = PsmMix(nlines, vertical, psm)
    cands = [
        ("plain", pad(main), mix.next()),
        ("otsu", pad(binarize(main)), mix.next()),
        ("otsu+20", pad(binarize(main, 20)), mix.next()),
        ("local", pad(binarize_local(main, window)), mix.next()),
    ]
    return cands, gray, base, main


def stage2(rgb: Image.Image, gray: Image.Image, base: float, main: Image.Image,
           vertical: bool, psm: int):
    window = window_for()
    mix = PsmMix(prepare(gray, vertical)[1], vertical, psm)
    out = []

    # Tilted text. Re-measure the lines after straightening, the earlier size
    # guess is wrong when lines run into each other.
    ang, gain = skew_angle(gray, vertical)
    if abs(ang) >= 1.0 and gain >= 1.3:
        g2 = gray.rotate(ang, resample=Image.BICUBIC, expand=True, fillcolor=border_value(gray))
        base2, nl2 = prepare(g2, vertical)
        m2 = rescale(g2, base2)
        mix2 = PsmMix(nl2, vertical, psm)
        out += [
            ("skew:plain", pad(m2), mix2.next()),
            ("skew:otsu", pad(binarize(m2)), mix2.next()),
            ("skew:local", pad(binarize_local(m2, window)), mix2.next()),
        ]

    # Grain and textured backgrounds.
    med = main.filter(ImageFilter.MedianFilter(5))
    out += [
        ("denoise:plain", pad(med), mix.next()),
        ("denoise:otsu", pad(binarize(med)), mix.next()),
        ("denoise:blur2", pad(binarize(main.filter(ImageFilter.GaussianBlur(2)))), mix.next()),
    ]

    # The size estimate is a guess and small text reads better bigger.
    big = rescale(gray, base * 1.5)
    out += [
        ("big:plain", pad(big), mix.next()),
        ("big:local", pad(binarize_local(big, window)), mix.next()),
    ]

    # Colour-aware: distance from the local background colour.
    cm = ImageOps.autocontrast(colour_distance_map(rescale(rgb, base)), cutoff=1)
    out += [
        ("colour:plain", pad(cm), mix.next()),
        ("colour:otsu", pad(binarize(cm)), mix.next()),
    ]
    return out


# -------------------------------------------------------------------- tesseract

def run_tesseract(img: Image.Image, lang: str, psm: int):
    """Returns (score, characters, text). `score` counts confident characters,
    shaky ones barely count."""
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    env = dict(os.environ, OMP_THREAD_LIMIT="1")
    with tempfile.TemporaryDirectory() as tmp:
        base = os.path.join(tmp, "out")
        # One run, two outputs: the plain text (correct spacing) and the TSV
        # (per-word confidence, used only for scoring).
        try:
            subprocess.run(
                ["tesseract", "stdin", base, "-l", lang, "--oem", "1",
                 "--psm", str(psm), "--dpi", "300",
                 "-c", "tessedit_create_txt=1", "-c", "tessedit_create_tsv=1"],
                input=buf.getvalue(), capture_output=True, env=env, timeout=40,
            )
        except subprocess.TimeoutExpired:  # a hopeless variant must not hang the lot
            return 0.0, 0, ""
        try:
            with open(base + ".txt", encoding="utf-8", errors="replace") as f:
                text = f.read()
            with open(base + ".tsv", encoding="utf-8", errors="replace") as f:
                tsv = f.read()
        except OSError:
            return 0.0, 0, ""

    score, chars = 0.0, 0
    for r in csv.reader(io.StringIO(tsv), delimiter="\t", quoting=csv.QUOTE_NONE):
        if len(r) < 12 or r[0] != "5":
            continue
        try:
            conf = float(r[10])
        except ValueError:
            continue
        word = r[11].strip()
        if not word or conf < 0:
            continue
        n = len(word.replace(" ", ""))
        chars += n
        score += n * max(conf - 35.0, 0.0) / 65.0
    return score, chars, text


def read_all(cands, lang):
    with ThreadPoolExecutor(max_workers=max(1, min(len(cands), os.cpu_count() or 4))) as ex:
        raw = list(ex.map(lambda c: run_tesseract(c[1], lang, c[2]), cands))
    return [
        {"name": c[0], "psm": c[2], "score": s, "chars": n, "text": t,
         "flat": re.sub(r"\s+", "", t)}
        for c, (s, n, t) in zip(cands, raw)
    ]


# -------------------------------------------------------------------- choosing

def similarity(a: str, b: str) -> float:
    if a == b:
        return 1.0
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, a, b, autojunk=False).ratio()


def vote_key(text: str) -> str:
    """Reading with spacing normalised, so 'me at' and 'meat' are different
    readings but stray spaces between CJK characters do not matter."""
    t = NON_ASCII_GAP.sub("", re.sub(r"[ \t]+", " ", text))
    return "\n".join(ln.strip() for ln in t.splitlines() if ln.strip())


def pick(results):
    """Best reading: confident AND agreed on by the other strong readings.

    Returns (result, quality, agreement); result is None if nothing was read.
    """
    live = [r for r in results if r["flat"]]
    if not live:
        return None, 0.0, 0.0
    top = sorted(live, key=lambda r: -r["score"])[:6]
    votes = Counter(vote_key(r["text"]) for r in live)
    for r in live:
        r["quality"] = r["score"] / r["chars"] if r["chars"] else 0.0
        num = den = 0.0
        for o in top:
            if o is r:
                continue
            w = max(o["score"], 1e-6)
            num += w * similarity(r["flat"], o["flat"])
            den += w
        r["agree"] = num / den if den else 0.5
        # Identical readings from independent variants count as votes: a lone
        # reading that is a few percent more "confident" must not outvote them.
        # Quality counts twice: pages of low-confidence junk must not beat a
        # short reading that tesseract is actually sure about.
        r["rank"] = (r["score"] * r["quality"] ** 2 * (0.35 + 0.65 * r["agree"])
                     * (1 + 0.04 * min(votes[vote_key(r["text"])] - 1, 4)))
    best = max(live, key=lambda r: r["rank"])
    return best, best["quality"], best["agree"]


# --------------------------------------------------------------------- cleanup

FULLWIDTH = {"?": "？", "!": "！", ":": "：", ";": "；", ".": "。"}


def clean(text: str, lang: str) -> str:
    # Korean uses real spaces between words and ASCII punctuation.
    # Japanese and Chinese use neither.
    if not lang.startswith("kor"):
        # Tesseract often writes , ? ! after CJK text as ASCII. Make them
        # full-width and pull them back against the character before them.
        comma = "、" if lang.startswith("jpn") else "，"
        text = re.sub(r"(?<=[^\x00-\x7f])[ \t]*([,?!:;.])(?![0-9A-Za-z])",
                      lambda m: comma if m.group(1) == "," else FULLWIDTH[m.group(1)], text)
        text = NON_ASCII_GAP.sub("", text)
    lines = [ln.strip() for ln in text.splitlines()]
    text = "\n".join(lines)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    path, lang = sys.argv[1], sys.argv[2]
    psm = int(sys.argv[3]) if len(sys.argv) > 3 else 6
    vertical = lang.endswith("_vert")
    sys.stdout.reconfigure(encoding="utf-8")
    debug = bool(os.environ.get("OCR_DEBUG"))

    rgb = load_rgb(path)
    cands, gray, base, main_img = stage1(rgb, vertical, psm)
    results = read_all(cands, lang)
    best, quality, agree = pick(results)

    if best is None or quality < GOOD_QUALITY or agree < GOOD_AGREEMENT:
        if debug:
            print(f"[stage 1 unsure: quality={quality:.2f} agreement={agree:.2f}, trying more]",
                  file=sys.stderr)
        results += read_all(stage2(rgb, gray, base, main_img, vertical, psm), lang)
        best, quality, agree = pick(results)

    if debug:
        for r in results:
            mark = "*" if r is best else " "
            print(f"{mark}[{r['name']} psm{r['psm']}] score={r['score']:.1f} "
                  f"agree={r.get('agree', 0):.2f} {r['text'].strip()!r}", file=sys.stderr)
    print(clean(best["text"], lang) if best and quality >= MIN_QUALITY else "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
'';

  ocrBest = pkgs.writeShellScriptBin "ocr-best" ''
    export TESSDATA_PREFIX=${tessdata}
    exec ${py}/bin/python3 ${ocrBestPy} "$@"
  '';
in
pkgs.writeShellApplication {
  name = "ocr-scan";

  runtimeInputs = with pkgs; [
    grim
    slurp
    wl-clipboard
    libnotify
    glib # gdbus, used to close the notification
    coreutils
    gnused
    tesseract
    ocrBest
  ];

  text = builtins.readFile ./ocr-scan.sh;
}
