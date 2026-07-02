"""Generate the HARSHIVOS app icon (1024x1024) — a cozy home under a starry
dusk sky, matching the app's magical-world motif. Outputs a full-bleed icon
and a safe-zone adaptive foreground.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = lerp(top, bottom, t)
        for x in range(size):
            px[x, y] = c
    return img


def radial_glow(size, center, radius, color, strength=1.0):
    glow = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(glow)
    cx, cy = center
    steps = 60
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(255 * strength * (1 - i / steps) ** 2)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=a)
    layer = Image.new("RGB", (size, size), color)
    out = Image.new("RGB", (size, size))
    out.paste(layer, (0, 0), glow)
    return out, glow


def draw_scene(size):
    # Dusk sky gradient (navy -> deep purple), matching hero palette.
    img = vgradient(size, (11, 27, 58), (58, 26, 74)).convert("RGB")
    d = ImageDraw.Draw(img, "RGBA")

    # Moon with soft glow, upper-left.
    mcx, mcy, mr = size * 0.30, size * 0.26, size * 0.11
    glow, mask = radial_glow(size, (mcx, mcy), mr * 3.2, (255, 240, 200), 0.55)
    img = Image.composite(glow, img, mask)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([mcx - mr, mcy - mr, mcx + mr, mcy + mr], fill=(255, 244, 214))

    # Stars.
    import random
    random.seed(7)
    for _ in range(70):
        x = random.uniform(0, size)
        y = random.uniform(0, size * 0.62)
        r = random.uniform(1.2, 4.0)
        a = random.randint(120, 230)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, a))

    # Ground hill.
    d.ellipse([-size * 0.4, size * 0.72, size * 1.4, size * 1.5],
              fill=(24, 46, 40))

    # --- Cozy house ---
    hw, hh = size * 0.42, size * 0.30
    hx = size * 0.5 - hw / 2
    hy = size * 0.56
    body = [hx, hy, hx + hw, hy + hh]

    # Warm glow behind house.
    hglow, hmask = radial_glow(size, (size * 0.5, hy + hh * 0.5),
                               size * 0.42, (255, 180, 110), 0.45)
    img = Image.composite(hglow, img, hmask)
    d = ImageDraw.Draw(img, "RGBA")

    # House wall.
    d.rounded_rectangle(body, radius=int(size * 0.03),
                        fill=(250, 244, 235))
    # Roof (triangle).
    rpad = size * 0.06
    d.polygon([(hx - rpad, hy + size * 0.01),
               (hx + hw + rpad, hy + size * 0.01),
               (size * 0.5, hy - size * 0.16)],
              fill=(224, 96, 72))
    # Chimney.
    cxw = size * 0.045
    d.rounded_rectangle([hx + hw * 0.72, hy - size * 0.13,
                         hx + hw * 0.72 + cxw, hy - size * 0.02],
                        radius=6, fill=(196, 78, 58))

    # Glowing window.
    ww = size * 0.12
    wx, wy = size * 0.5 - ww / 2, hy + hh * 0.20
    wglow, wmask = radial_glow(size, (size * 0.5, wy + ww / 2),
                               ww * 2.0, (255, 214, 120), 0.9)
    img = Image.composite(wglow, img, wmask)
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([wx, wy, wx + ww, wy + ww], radius=int(size * 0.02),
                        fill=(255, 221, 140))
    d.line([wx + ww / 2, wy, wx + ww / 2, wy + ww], fill=(196, 120, 40),
           width=6)
    d.line([wx, wy + ww / 2, wx + ww, wy + ww / 2], fill=(196, 120, 40),
           width=6)

    # Door with heart.
    dw, dh = size * 0.10, size * 0.16
    dx, dy = size * 0.5 - dw / 2, hy + hh - dh
    d.rounded_rectangle([dx, dy, dx + dw, dy + dh],
                        radius=int(size * 0.045), fill=(120, 78, 200))
    # Heart on door.
    hxc, hyc = size * 0.5, dy + dh * 0.34
    hr = size * 0.018
    d.ellipse([hxc - hr * 1.6, hyc - hr, hxc - hr * 0.1, hyc + hr * 0.6],
              fill=(255, 120, 150))
    d.ellipse([hxc + hr * 0.1, hyc - hr, hxc + hr * 1.6, hyc + hr * 0.6],
              fill=(255, 120, 150))
    d.polygon([(hxc - hr * 1.5, hyc + hr * 0.2), (hxc + hr * 1.5, hyc + hr * 0.2),
               (hxc, hyc + hr * 1.8)], fill=(255, 120, 150))

    return img


def main():
    scene = draw_scene(S)

    # Full-bleed icon (for legacy / iOS / web).
    scene.save("assets/icon/icon.png")

    # Adaptive foreground: same scene but scaled into the safe zone with
    # transparent padding (Android crops adaptive icons).
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    inner = int(S * 0.66)
    small = scene.resize((inner, inner)).convert("RGBA")
    off = (S - inner) // 2
    fg.paste(small, (off, off))
    fg.save("assets/icon/icon_foreground.png")

    print("Wrote assets/icon/icon.png and assets/icon/icon_foreground.png")


if __name__ == "__main__":
    main()
