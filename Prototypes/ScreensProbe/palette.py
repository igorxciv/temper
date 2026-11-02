# Contrast and color-blindness numbers for Ink and a proposed increased-contrast set.
# Machado, Oliveira & Fernandes 2009, severity 1.0, applied in linear sRGB.
import itertools, math

def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def enc(c):
    c = max(0, min(1, c))
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
def rgb(h):
    return [lin((h >> s & 255) / 255) for s in (16, 8, 0)]
def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def cr(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)
def oklab(c):
    l = 0.4122214708 * c[0] + 0.5363325363 * c[1] + 0.0514459929 * c[2]
    m = 0.2119034982 * c[0] + 0.6806995451 * c[1] + 0.1073969566 * c[2]
    s = 0.0883024619 * c[0] + 0.2817188376 * c[1] + 0.6299787005 * c[2]
    l, m, s = [math.copysign(abs(v) ** (1 / 3), v) for v in (l, m, s)]
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
def dE(a, b):
    return 100 * math.dist(oklab(a), oklab(b))
M = {
    "normal": [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
    "protan": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
    "deutan": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
    "tritan": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}
def sim(c, kind):
    return [max(0, min(1, sum(M[kind][i][j] * c[j] for j in range(3)))) for i in range(3)]
def over(fg, bg, a):
    return [fg[i] * a + bg[i] * (1 - a) for i in range(3)]  # linear approximation, for reference only

INK = {
    "Prepare": dict(bg=0x0F2433, ring=0x8FCBEF, track=0x274A60, text=0xEFF8FD),
    "Work": dict(bg=0x351C17, ring=0xFFAE8A, track=0x59332A, text=0xFFF5F0),
    "Rest": dict(bg=0x0F2A2B, ring=0x86DCCB, track=0x254A48, text=0xF0FBF8),
    "Cooldown": dict(bg=0x18223F, ring=0xAFC4FF, track=0x2F3D66, text=0xF3F6FF),
}
# Proposal: darker grounds, brighter marks, tracks lifted to a visible 3:1 against the ground.
INK_IC = {
    "Prepare": dict(bg=0x081A27, ring=0xB5E0FA, track=0x4A748C, text=0xFFFFFF),
    "Work": dict(bg=0x2A120E, ring=0xFFC6AB, track=0x986149, text=0xFFFFFF),
    "Rest": dict(bg=0x071F20, ring=0xA8EFE1, track=0x447E77, text=0xFFFFFF),
    "Cooldown": dict(bg=0x0F1830, ring=0xC9D7FF, track=0x586DAC, text=0xFFFFFF),
}
HOME = 0x11151D
HOME_IC = 0x0A0D13
HOME_UI = dict(raised=0x1B212C, separator=0x2E3643, text=0xF3F1EA, secondary=0xA9ADB5, accent=0xE6B566)
HOME_UI_IC = dict(raised=0x161B24, separator=0x6A7486, text=0xFFFFFF, secondary=0xD3D6DB, accent=0xF3CA85)

def report(name, pal, home, ui):
    print(f"\n== {name}")
    print("phase      text:bg ring:bg ring:track track:bg")
    for k, p in pal.items():
        print(f"{k:9} {cr(rgb(p['text']), rgb(p['bg'])):7.2f} {cr(rgb(p['ring']), rgb(p['bg'])):7.2f} "
              f"{cr(rgb(p['ring']), rgb(p['track'])):7.2f} {cr(rgb(p['track']), rgb(p['bg'])):7.2f}")
    print("home:", {k: round(cr(rgb(v), rgb(home)), 2) for k, v in ui.items()})
    print("hollow word contrast against home by opacity (sRGB-space blend, as SwiftUI composites):")
    def blend(fg, a):
        f = [(fg >> s & 255) / 255 for s in (16, 8, 0)]
        b = [(home >> s & 255) / 255 for s in (16, 8, 0)]
        return [lin(f[i] * a + b[i] * (1 - a)) for i in range(3)]
    for a in (0.32, 0.45, 0.60, 0.80):
        vals = [cr(blend(p["ring"], a), rgb(home)) for p in pal.values()] + [cr(blend(ui["accent"], a), rgb(home))]
        print(f"  {a:.2f}: {min(vals):.2f} to {max(vals):.2f}")
    print("color-blind: min phase-to-phase distance (OKLab x100; larger is further apart)")
    for kind in M:
        rows = []
        for (a, pa), (b, pb) in itertools.combinations(pal.items(), 2):
            rows.append((dE(sim(rgb(pa["bg"]), kind), sim(rgb(pb["bg"]), kind)),
                         dE(sim(rgb(pa["ring"]), kind), sim(rgb(pb["ring"]), kind)), a, b))
        bgmin = min(rows, key=lambda r: r[0])
        ringmin = min(rows, key=lambda r: r[1])
        wr = next(r for r in rows if r[2] == "Work" and r[3] == "Rest")
        rc = min(cr(sim(rgb(p["ring"]), kind), sim(rgb(p["bg"]), kind)) for p in pal.values())
        print(f"  {kind:7} bg min {bgmin[0]:5.1f} ({bgmin[2]}/{bgmin[3]})  ring min {ringmin[1]:5.1f} ({ringmin[2]}/{ringmin[3]})"
              f"  Work/Rest bg {wr[0]:5.1f} ring {wr[1]:5.1f}  ring:bg >= {rc:.2f}")

report("Ink", INK, HOME, HOME_UI)
report("Ink increased contrast (proposal)", INK_IC, HOME_IC, HOME_UI_IC)

print("\n== arcminutes at 3 m for a glyph height in points")
for dev, ptmm in (("iPhone SE (326ppi @2x)", 25.4 / 163), ("15 Pro Max / 18 Pro (460ppi @3x)", 25.4 / (460 / 3))):
    for h in (40, 46, 80, 90, 100):
        mm = h * ptmm
        print(f"  {dev}: {h}pt = {mm:.1f}mm = {math.degrees(math.atan(mm / 3000)) * 60:.1f}'")
