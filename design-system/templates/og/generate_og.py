#!/usr/bin/env python3
"""
Tuwa "Field Notes" (DESIGN.md v6.2) — Open Graph card generator.

Renders the share cards for the four feature pages in ALL THREE SHIPPING LOCALES at
exactly 1200x630. Deterministic: no network, no CDN, fonts read from the repo.

  en  ->  tuwa-website/public/og/<card>.png        (unchanged path — already referenced)
  zh  ->  tuwa-website/public/og/zh/<card>.png     (new)
  fr  ->  tuwa-website/public/og/fr/<card>.png     (new)

WHY THE LOCALE AXIS EXISTS (Wave 3 Round 2 review finding 1)
  Twelve `ogImage` props across `src/pages/features/`, `src/pages/zh/features/` and
  `src/pages/fr/features/` all pointed at the SAME English `/og/<card>.png`, so a card
  shared from a Chinese or French page previewed in English. The copy below is not
  translated here — it is lifted from each locale's own page (`class="feat-h1"` and
  `class="feat-lead"`), so the card and the page it links to say the same thing.

  Emitting the files is all this script can do. Pointing the zh/fr pages at them is a
  `tuwa-website/src/` edit, which belongs to CODEX — filed as a request in status-g.md:
      zh/features/<card>.astro : ogImage="/og/zh/<card>.png"
      fr/features/<card>.astro : ogImage="/og/fr/<card>.png"

DESIGN LAW APPLIED HERE
  - Warm stone planes only; the metric hues never fill a surface.
  - Elevation = plane + 0.5px hairline + relief. NO shadows.
  - Two-voice type: Instrument Sans speaks (headline, sub, wordmark); Fragment Mono
    annotates (uppercase, +0.05em, <=12px at display scale — the 1200px canvas renders
    ~600 CSS px wide, so 20px here is ~10 CSS px). Alpino is the display voice and is
    allowed on marketing surfaces only.
  - Reading Color Rule: the hero reading wears its metric's hue; a reading with no
    metric identity wears travertine accent. Every coloured text element names the
    metric whose hue it wears.
  - Contrast rule: annotation defaults to TEXT_3, but NEVER TEXT_3 on a well (2.84:1
    on well-top). Annotation inside the readout well is TEXT_2.
  - 8pt grid, corners 12 / 8 / pill, sentence case in the working voice.
  - zh-Hans: NO case transform and NO added tracking on the annotation voice (design
    system, CONTENT FUNDAMENTALS -> i18n). Enforced by the locale table, not by call
    sites. zh also drops Alpino — it is a Latin display face with no CJK — and sets the
    headline in Noto Sans SC Medium, the declared CJK cascade.

Usage:  python3 design-system/templates/og/generate_og.py
        python3 design-system/templates/og/generate_og.py --locale zh
"""

import argparse
import os
import sys

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
DS = os.path.join(REPO, "design-system")
OUT_ROOT = os.path.join(REPO, "tuwa-website", "public", "og")

W, H = 1200, 630

# ---------------------------------------------------------------- tokens
BG = "#F0EFEC"
SURFACE = "#F4F3F0"
DIVIDER = "#D6D3CD"
DIVIDER_STRONG = "#CCC9C2"
WELL_TOP = "#E7E5E0"
WELL_BOTTOM = "#EDEBE6"
TEXT_1 = "#1B1A17"
TEXT_2 = "#57544E"
TEXT_3 = "#8B877F"
ACCENT = "#6F6759"
METRIC = {
    "readiness": "#2E7D4F",
    "recovery": "#1D7189",
    "sleep": "#52589E",
    "strain": "#A8442D",
    "load": "#8A6810",
}

FONT_DIR = os.path.join(REPO, "WorkloadApp", "Resources", "Fonts")
SANS_R = os.path.join(FONT_DIR, "InstrumentSans-Regular.ttf")
SANS_M = os.path.join(FONT_DIR, "InstrumentSans-Medium.ttf")
MONO = os.path.join(FONT_DIR, "FragmentMono-Regular.ttf")
NOTO_R = os.path.join(FONT_DIR, "NotoSansSC-Regular.otf")
NOTO_M = os.path.join(FONT_DIR, "NotoSansSC-Medium.otf")
ALPINO = os.path.join(DS, "fonts", "Alpino-Variable.ttf")
ICON = os.path.join(DS, "assets", "icon-512.png")

SS = 2  # supersample factor — draw at 2x, downsample for clean hairlines/edges

_CMAP_CACHE = {}


def cmap_of(path):
    """The set of codepoints a face can actually draw (used for the CJK cascade)."""
    if path not in _CMAP_CACHE:
        tt = TTFont(path, fontNumber=0, lazy=True)
        cps = set()
        for table in tt["cmap"].tables:
            cps |= set(table.cmap.keys())
        _CMAP_CACHE[path] = cps
    return _CMAP_CACHE[path]


class Face:
    """One or more real faces in cascade order, dispatched per character.

    This is the PIL equivalent of `--font-sans:'Instrument Sans','Noto Sans SC'` —
    PIL has no font fallback, so a Chinese card set in Instrument Sans alone renders
    as tofu. Every draw/measure helper below goes through this class.
    """

    def __init__(self, paths, size, variation=None):
        self.size = size * SS
        self.faces = []
        for p in paths:
            f = ImageFont.truetype(p, self.size)
            if variation is not None:
                try:
                    f.set_variation_by_axes([variation])
                except Exception:
                    pass
            self.faces.append((cmap_of(p), f, p))

    def for_char(self, ch):
        for cps, f, _ in self.faces:
            if ord(ch) in cps:
                return f
        return self.faces[-1][1]  # last resort: draw tofu rather than crash

    def missing(self, s):
        return {ch for ch in s if not any(ord(ch) in cps for cps, _, _ in self.faces)}


def px(v):
    return v * SS


def text_w(draw, s, face, tracking=0.0):
    if not s:
        return 0
    total = sum(draw.textlength(ch, font=face.for_char(ch)) for ch in s)
    return total + tracking * face.size * max(len(s) - 1, 0)


def draw_text(draw, xy, s, face, fill, tracking=0.0, anchor_right=None):
    """Draw with per-character face cascade and optional letter-spacing.

    Tracking is passed in by the LOCALE TABLE, never by a call site — that is how the
    zh-Hans "no added tracking" rule is enforced structurally.
    """
    x, y = xy
    if anchor_right is not None:
        x = anchor_right - text_w(draw, s, face, tracking)
    step = tracking * face.size
    for ch in s:
        f = face.for_char(ch)
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + step
    return x


NO_LINE_START = "，。、；：？！）】」』’”%·—…"


def wrap(draw, s, face, max_w, by_char=False):
    """Word wrap for Latin; character wrap (with a leading-punctuation guard) for CJK."""
    if by_char:
        lines, cur = [], ""
        for ch in s:
            trial = cur + ch
            if text_w(draw, trial, face) <= max_w or not cur:
                cur = trial
            else:
                if ch in NO_LINE_START and cur:
                    cur += ch          # never start a line with closing punctuation
                    lines.append(cur)
                    cur = ""
                else:
                    lines.append(cur)
                    cur = ch
        if cur:
            lines.append(cur)
        return lines

    words, lines, cur = s.split(), [], ""
    for w_ in words:
        trial = (cur + " " + w_).strip()
        if text_w(draw, trial, face) <= max_w or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = w_
    if cur:
        lines.append(cur)
    return lines


def vgrad(size, top, bottom):
    """Vertical two-stop gradient — the relief system's only sanctioned gradient."""
    w, h = size
    img = Image.new("RGB", (1, h))
    t = tuple(int(top[i:i + 2], 16) for i in (1, 3, 5))
    b = tuple(int(bottom[i:i + 2], 16) for i in (1, 3, 5))
    for y in range(h):
        k = y / max(h - 1, 1)
        img.putpixel((0, y), tuple(int(t[j] + (b[j] - t[j]) * k) for j in range(3)))
    return img.resize((w, h))


def debossed_well(img, box, radius=12):
    """A readout well: well-top -> well-bottom, hairline. No shadow."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    g = vgrad((w, h), WELL_TOP, WELL_BOTTOM)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=px(radius), fill=255)
    img.paste(g, (x0, y0), mask)
    ImageDraw.Draw(img).rounded_rectangle(
        box, radius=px(radius), outline=DIVIDER_STRONG, width=max(1, SS // 2))


# ---------------------------------------------------------------- locale axis
# `anno_upper` / `anno_track` are the two i18n levers the design system names by hand:
# zh-Hans gets no case transform and no added tracking. Nothing else may set them.
LOCALES = {
    "en": dict(subdir="", anno_upper=True, anno_track=0.05, wrap_by_char=False,
               mono=[MONO], sans=[SANS_R], sans_m=[SANS_M], display="alpino"),
    "fr": dict(subdir="fr", anno_upper=True, anno_track=0.05, wrap_by_char=False,
               mono=[MONO], sans=[SANS_R], sans_m=[SANS_M], display="alpino"),
    # Fragment Mono has no CJK, so zh annotation cascades Mono -> Noto Sans SC:
    # Latin/digit machine tokens stay in the annotation voice, Chinese falls to Noto.
    "zh": dict(subdir="zh", anno_upper=False, anno_track=0.0, wrap_by_char=True,
               mono=[MONO, NOTO_R], sans=[SANS_R, NOTO_R], sans_m=[SANS_M, NOTO_M],
               display="noto"),
}

STRIP_LEFT = "TUWA · FIELD NOTES"   # brand + system token; Latin in every locale

# ---------------------------------------------------------------- card spec
# `hue` and `reading_hue` are locale-invariant (a metric identity does not translate).
# `reading` is the default; a locale may override it in its copy block when the NUMBER
# FORMAT differs (fr groups thousands with a space, not a comma). Everything else a
# reader reads is per-locale, lifted from that locale's own feature page.
CARDS = [
    dict(
        name="recovery-scoring",
        hue="recovery", reading="82", reading_hue=True,
        copy={
            "en": dict(
                section="RECOVERY",
                headline="Readiness you can read",
                sub="HRV, sleep, and resting heart rate scored against your own rolling "
                    "baselines — not population norms.",
                reading_key="RECOVERY · TODAY",
                readout="RECOVERY", readout_tail="HRV VS YOUR BASELINE"),
            "zh": dict(
                section="恢复",
                headline="看得懂的准备状态",
                sub="夜间 HRV、睡眠和静息心率对照你自己的滚动基线打分，而不是人群标准。",
                reading_key="恢复 · 今天",
                readout="恢复", readout_tail="HRV 对照你的基线"),
            "fr": dict(
                section="RÉCUPÉRATION",
                headline="Une forme que tu peux lire",
                sub="VFC nocturne, sommeil et fréquence cardiaque au repos, notés contre "
                    "tes propres références glissantes — pas des normes de population.",
                reading_key="RÉCUPÉRATION · AUJOURD'HUI",
                readout="RÉCUPÉRATION", readout_tail="VFC VS TA RÉFÉRENCE"),
        },
    ),
    dict(
        name="workload-tracking",
        hue="load", reading="1.12", reading_hue=True,
        copy={
            "en": dict(
                section="TRAINING LOAD",
                headline="One fatigue budget",
                sub="Sport skill, strength, and conditioning drain the same tank. "
                    "Tuwa tracks them as one load.",
                reading_key="ACWR · 7D : 28D",
                readout="LOAD", readout_tail="STRIKE ZONE 0.80–1.30"),
            "zh": dict(
                section="训练负荷",
                headline="一个疲劳预算",
                sub="专项技术、力量、体能消耗的是同一个油箱。Tuwa 把它们记成同一份负荷。",
                reading_key="ACWR · 7D : 28D",
                readout="负荷", readout_tail="STRIKE ZONE 0.80–1.30"),
            "fr": dict(
                section="CHARGE D'ENTRAÎNEMENT",
                headline="Un seul budget de fatigue",
                sub="Le sport, la force et le cardio puisent dans le même réservoir. "
                    "Tuwa les suit comme une seule charge.",
                reading_key="ACWR · 7J : 28J",
                readout="CHARGE", readout_tail="STRIKE ZONE 0.80–1.30"),
        },
    ),
    dict(
        name="cold-start",
        hue="readiness", reading="D-01", reading_hue=True,
        copy={
            "en": dict(
                section="STARTING OUT",
                headline="Useful on day one",
                sub="Tuwa starts with your profile and first sessions, then gets more "
                    "personal as real data arrives — without pretending certainty.",
                reading_key="READINESS · DAY ONE",
                readout="READINESS", readout_tail="NO DATA STAYS NEUTRAL"),
            "zh": dict(
                section="即刻开始",
                headline="第一天就有用",
                sub="Tuwa 从你的资料和第一批训练记录开始，随着真实数据进入而变得更个人化，"
                    "但不假装确定。",
                reading_key="准备状态 · 第一天",
                readout="准备状态", readout_tail="没有数据就保持中性"),
            "fr": dict(
                section="POUR COMMENCER",
                headline="Utile dès le premier jour",
                sub="Tuwa démarre avec ton profil et tes premières séances, puis devient "
                    "plus personnel à mesure que les vraies données arrivent — sans "
                    "prétendre à la certitude.",
                reading_key="FORME · JOUR UN",
                readout="FORME", readout_tail="SANS DONNÉES, RESTE NEUTRE"),
        },
    ),
    dict(
        name="smart-templates",
        hue="strain", reading="1,324", reading_hue=False,  # a movement count is not a metric
        copy={
            "en": dict(
                section="LOGGING",
                headline="Log fast, between sets",
                sub="A 1,324-exercise movement bank behind a search-first picker. "
                    "Weight, reps, done.",
                reading_key="MOVEMENT BANK",
                readout="STRAIN", readout_tail="RPE + LOAD ON EVERY SET"),
            "zh": dict(
                section="记录",
                headline="组间快速记录",
                sub="1,324 个动作的动作库，放在一个搜索优先的选择器后面。重量、次数、完成。",
                reading_key="动作库",
                readout="强度", readout_tail="每组都有 RPE + 负荷"),
            "fr": dict(
                section="JOURNAL",
                headline="Note vite, entre les séries",
                sub="Une banque de 1 324 mouvements derrière un sélecteur pensé recherche "
                    "d'abord. Charge, répétitions, validé.",
                reading="1 324",   # fr groups thousands with a space
                reading_key="BANQUE DE MOUVEMENTS",
                readout="EFFORT", readout_tail="RPE + CHARGE À CHAQUE SÉRIE"),
        },
    ),
]


def render(spec, locale):
    L = LOCALES[locale]
    C = spec["copy"][locale]
    hue = METRIC[spec["hue"]]
    track = L["anno_track"]

    def anno(s):
        return s.upper() if L["anno_upper"] else s

    img = Image.new("RGB", (W * SS, H * SS), BG)
    d = ImageDraw.Draw(img)

    f_anno = Face(L["mono"], 20)
    f_anno_sm = Face(L["mono"], 17)
    if L["display"] == "alpino":
        f_head = Face([ALPINO], 60, variation=650)
    else:
        f_head = Face(L["sans_m"], 60)
    f_sub = Face(L["sans"], 25)
    f_word = Face(L["sans_m"], 26)
    f_read = Face(L["sans_m"], 76)

    # --- top annotation strip (surface plane + hairline) -------------------
    STRIP = 96
    d.rectangle((0, 0, W * SS, px(STRIP)), fill=SURFACE)
    d.rectangle((0, px(STRIP), W * SS, px(STRIP) + max(1, SS // 2)), fill=DIVIDER)
    ty = px(STRIP // 2) - f_anno.size * 0.62
    draw_text(d, (px(56), ty), anno(STRIP_LEFT), f_anno, TEXT_3, track)
    draw_text(d, (0, ty), anno(C["section"]), f_anno, TEXT_3, track, anchor_right=px(W - 56))

    # --- bottom strip ------------------------------------------------------
    FOOT = 534
    d.rectangle((0, px(FOOT), W * SS, H * SS), fill=SURFACE)
    d.rectangle((0, px(FOOT), W * SS, px(FOOT) + max(1, SS // 2)), fill=DIVIDER)

    ICON_PX = 64
    icon = Image.open(ICON).convert("RGBA").resize((px(ICON_PX), px(ICON_PX)), Image.LANCZOS)
    icon_y = px(FOOT) + (px(H - FOOT) - px(ICON_PX)) // 2
    img.paste(icon, (px(56), icon_y), icon)
    d.text((px(56 + ICON_PX + 8), px(FOOT + (H - FOOT) // 2) - f_word.size * 0.66),
           "Tuwa", font=f_word.for_char("T"), fill=TEXT_1)

    # metric readout — the dot is a mark (drawn, not a glyph); the label names the metric
    label, tail = anno(C["readout"]), anno(C["readout_tail"])
    ry = px(FOOT + (H - FOOT) // 2) - f_anno_sm.size * 0.62
    dot_r, dot_gap = px(5), px(12)
    wordmark_end = px(56 + ICON_PX + 8) + d.textlength("Tuwa", font=f_word.for_char("T"))
    avail = px(W - 56) - wordmark_end - px(32)
    while (text_w(d, label, f_anno_sm, track) + dot_gap * 2 + dot_r * 2
           + text_w(d, tail, f_anno_sm, track)) > avail and " " in tail:
        tail = tail.rsplit(" ", 1)[0]   # never let the footer readout collide or wrap
    label_w = text_w(d, label, f_anno_sm, track)
    tail_w = text_w(d, tail, f_anno_sm, track)
    x = px(W - 56) - (label_w + dot_gap + dot_r * 2 + dot_gap + tail_w)
    draw_text(d, (x, ry), label, f_anno_sm, hue, track)
    x += label_w + dot_gap
    cy = px(FOOT + (H - FOOT) // 2)
    d.ellipse((x, cy - dot_r, x + dot_r * 2, cy + dot_r), fill=hue)
    x += dot_r * 2 + dot_gap
    draw_text(d, (x, ry), tail, f_anno_sm, TEXT_3, track)

    # --- readout well (right of the middle band, vertically centred) -------
    band_mid = px((STRIP + FOOT) // 2)
    well_h, well_w = px(208), px(312)
    well = (px(W - 56) - well_w, band_mid - well_h // 2, px(W - 56), band_mid + well_h // 2)
    debossed_well(img, well)
    d = ImageDraw.Draw(img)
    reading_color = hue if spec["reading_hue"] else ACCENT
    reading = C.get("reading", spec["reading"])
    cx = (well[0] + well[2]) / 2
    rw = text_w(d, reading, f_read)
    d.text((cx - rw / 2, well[1] + px(52)), reading,
           font=f_read.for_char("0"), fill=reading_color)
    # The key sits INSIDE the well, so it may not take TEXT_3: measured 2.84:1 on
    # well-top and 3.00:1 on well-bottom, both at/under the 3:1 micro floor.
    # DESIGN.md v6.2 (Contrast rule) — "never `text3` on a well". TEXT_2 measures
    # 5.99:1 / 6.33:1 across the same gradient.
    key = anno(C["reading_key"])
    kw = text_w(d, key, f_anno_sm, track)
    draw_text(d, (cx - kw / 2, well[1] + px(144)), key, f_anno_sm, TEXT_2, track)

    # --- headline + sub (display / working voice), vertically centred ------
    max_w = px(688)
    head_lines = wrap(d, C["headline"], f_head, max_w, L["wrap_by_char"])
    sub_lines = wrap(d, C["sub"], f_sub, max_w, L["wrap_by_char"])
    head_lh = int(f_head.size * 1.12)
    sub_lh = int(f_sub.size * 1.45)
    head_gap = px(32) if L["wrap_by_char"] else px(16)   # CJK fills its em box — two 8pt steps up
    block_h = len(head_lines) * head_lh + head_gap + len(sub_lines) * sub_lh
    y = band_mid - block_h // 2 - px(8)
    for ln in head_lines:
        draw_text(d, (px(56), y), ln, f_head, TEXT_1)
        y += head_lh
    y += head_gap
    for ln in sub_lines:
        draw_text(d, (px(56), y), ln, f_sub, TEXT_2)
        y += sub_lh

    # loud failure rather than silent tofu
    for name, face, s in (("headline", f_head, C["headline"]), ("sub", f_sub, C["sub"]),
                          ("anno", f_anno, anno(C["section"])),
                          ("anno_sm", f_anno_sm, anno(C["reading_key"] + C["readout"]
                                                      + C["readout_tail"]))):
        gone = face.missing(s)
        if gone:
            print(f"  !! {locale}/{spec['name']}: {name} has no glyph for "
                  f"{sorted(gone)} — falls back to tofu", file=sys.stderr)

    return img.resize((W, H), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--locale", choices=sorted(LOCALES), action="append",
                    help="render one locale (repeatable); default = all three")
    args = ap.parse_args()
    locales = args.locale or list(LOCALES)

    for locale in locales:
        out_dir = os.path.join(OUT_ROOT, LOCALES[locale]["subdir"])
        os.makedirs(out_dir, exist_ok=True)
        for spec in CARDS:
            p = os.path.join(out_dir, spec["name"] + ".png")
            render(spec, locale).save(p, optimize=True)
            print("wrote", os.path.relpath(p, REPO), Image.open(p).size)


if __name__ == "__main__":
    main()
