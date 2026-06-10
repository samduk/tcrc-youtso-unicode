"""
make_icons.py — generate the app icons (tcrc_on.ico / tcrc_off.ico).

The icon shows the word "bod" (Tibet) in the Youtso typeface itself,
on a discreet design that echoes meaningful colors without depicting
any flag or symbol: deep blue and muted red panels with a yellow border.
The gray version is shown in the tray when Tibetan typing is toggled off.

HOW TO USE
----------
    pip install -r requirements.txt
    python tools/make_icons.py
"""

from pathlib import Path

import freetype
import numpy as np
import uharfbuzz as hb
from PIL import Image, ImageDraw

ROOT = Path(__file__).parent.parent
FONT = str(ROOT / "fonts" / "TCRC-Youtso-Unicode-fixed.ttf")
TEXT = "བོད"  # bod


def render_text(text, size, color):
    """Shape the text with HarfBuzz (so stacks form) and render it."""
    face = hb.Face(open(FONT, "rb").read())
    font = hb.Font(face)
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf)

    scale = size / face.upem
    ft = freetype.Face(FONT)
    ft.set_char_size(size * 64)

    margin = size
    width = int(sum(p.x_advance for p in buf.glyph_positions) * scale) + 2 * margin
    height = int(size * 2) + 2 * margin
    canvas = np.zeros((height, width), dtype=np.uint8)

    x, y = margin, margin + size
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        ft.load_glyph(info.codepoint, freetype.FT_LOAD_RENDER)
        bitmap = ft.glyph.bitmap
        if bitmap.width:
            pixels = np.frombuffer(bytes(bitmap.buffer), dtype=np.uint8)
            pixels = pixels.reshape(bitmap.rows, bitmap.width)
            px = int(x + pos.x_offset * scale) + ft.glyph.bitmap_left
            py = int(y - pos.y_offset * scale) - ft.glyph.bitmap_top
            h, w = pixels.shape
            canvas[py:py + h, px:px + w] = np.maximum(canvas[py:py + h, px:px + w], pixels)
        x += pos.x_advance * scale

    rows, cols = np.where(canvas > 16)
    canvas = canvas[rows.min():rows.max() + 1, cols.min():cols.max() + 1]
    image = Image.new("RGBA", (canvas.shape[1], canvas.shape[0]), color)
    image.putalpha(Image.fromarray(canvas))
    return image


def make_icon(gray=False):
    S = 256
    blue, red = (28, 52, 110, 255), (140, 32, 40, 255)
    yellow, white = (232, 185, 35, 255), (248, 248, 248, 255)
    if gray:  # the "Tibetan typing OFF" version
        blue, red = (90, 90, 95, 255), (70, 70, 74, 255)
        yellow, white = (150, 150, 150, 255), (210, 210, 210, 255)

    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    draw.rounded_rectangle([4, 4, S - 4, S - 4], radius=44, fill=yellow)
    draw.rounded_rectangle([16, 16, S - 16, S - 16], radius=36, fill=blue)

    corner = Image.new("L", (S, S), 0)
    ImageDraw.Draw(corner).polygon([(S - 16, 80), (S - 16, S - 16), (80, S - 16)], fill=255)
    red_panel = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(red_panel).rounded_rectangle([16, 16, S - 16, S - 16], radius=36, fill=red)
    icon = Image.composite(red_panel, icon, corner)

    text = render_text(TEXT, 130, white)
    if text.width > S - 64:
        text = text.resize((S - 64, int(text.height * (S - 64) / text.width)), Image.LANCZOS)
    icon.alpha_composite(text, ((S - text.width) // 2, (S - text.height) // 2 + 4))
    return icon


if __name__ == "__main__":
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (256, 256)]
    out = ROOT / "installer"
    make_icon(False).save(out / "tcrc_on.ico", sizes=sizes)
    make_icon(True).save(out / "tcrc_off.ico", sizes=sizes)
    print("icons written to installer/")
