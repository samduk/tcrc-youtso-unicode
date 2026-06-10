"""
build_mapping.py — how the legacy→Unicode conversion table was created.

THE PROBLEM
-----------
Old TCRC documents store Tibetan on English character codes, and there was no
published table saying which code means which Tibetan letter. Without that
table, old documents cannot be converted.

THE IDEA
--------
Both fonts draw the SAME typeface. So for every character of the legacy font
we can find its visual twin in the Unicode font, and from the twin we can
learn the real Unicode value:

  step 1  render every glyph of both fonts to a small image
  step 2  for each legacy glyph, find the most similar Unicode-font glyph
          (compare the images pixel by pixel)
  step 3  some matched glyphs are stacks (like སྐྱ) that have no single
          Unicode value — they are produced by the font's internal
          substitution rules (GSUB). We invert those rules to recover the
          sequence of characters that builds the stack.
  step 4  REVIEW BY EYE + verify against real documents. Similar-looking
          letters (ལ vs ླ, ང vs ྔ, ཨ vs ྸ) cannot be told apart by pixels
          alone; real words such as ལྡན, ལྷ, བླ, གླིང and པདྨ settled
          every ambiguous case.

The finished, human-verified table ships as
converter/tcrc_to_unicode_map.json — you do NOT need to run this script to
use the converter. It is included so the method is transparent and reusable
for OTHER legacy Tibetan fonts (Drutsa, Dedris, Sambhota...): point it at a
legacy font and its Unicode sibling and you get a draft table to review.

HOW TO USE
----------
    pip install fonttools uharfbuzz freetype-py pillow numpy
    python build_mapping.py legacy.ttf unicode.ttf draft_table.json
"""

import json
import sys

import freetype
import numpy as np
from fontTools.ttLib import TTFont
from PIL import Image


def render_all_glyphs(font_path, size=96):
    """Render every glyph to a normalized 32x32 black-and-white image."""
    face = freetype.Face(font_path)
    face.set_char_size(size * 64)
    images = {}
    for glyph_id in range(TTFont(font_path)["maxp"].numGlyphs):
        face.load_glyph(glyph_id, freetype.FT_LOAD_RENDER)
        bitmap = face.glyph.bitmap
        if not bitmap.width:
            continue
        pixels = np.frombuffer(bytes(bitmap.buffer), dtype=np.uint8)
        pixels = pixels.reshape(bitmap.rows, bitmap.width)
        ink_rows, ink_cols = np.where(pixels > 32)
        if not len(ink_rows):
            continue
        pixels = pixels[ink_rows.min():ink_rows.max() + 1,
                        ink_cols.min():ink_cols.max() + 1]
        small = Image.fromarray(pixels).resize((32, 32), Image.BILINEAR)
        aspect = pixels.shape[0] / pixels.shape[1]
        images[glyph_id] = ((np.asarray(small) > 64).astype(np.float32), aspect)
    return images


def unicode_value_of_each_glyph(font_path):
    """glyph name -> Unicode string, inverting the font's stacking rules."""
    font = TTFont(font_path)
    direct = {}
    for codepoint, glyph_name in sorted(font.getBestCmap().items()):
        direct.setdefault(glyph_name, codepoint)

    ligature_parts, variant_source = {}, {}
    for lookup in font["GSUB"].table.LookupList.Lookup:
        for subtable in lookup.SubTable:
            if lookup.LookupType == 4:        # ligature: parts -> stack glyph
                for first, ligatures in subtable.ligatures.items():
                    for lig in ligatures:
                        ligature_parts.setdefault(
                            lig.LigGlyph, [first] + list(lig.Component))
            elif lookup.LookupType == 1:      # variant shape of another glyph
                for source, variant in subtable.mapping.items():
                    variant_source.setdefault(variant, source)

    def to_unicode(glyph, depth=0):
        if depth > 8:
            return None
        if glyph in direct:
            return [direct[glyph]]
        if glyph in ligature_parts:
            result = []
            for part in ligature_parts[glyph]:
                decoded = to_unicode(part, depth + 1)
                if decoded is None:
                    return None
                result += decoded
            return result
        if glyph in variant_source:
            return to_unicode(variant_source[glyph], depth + 1)
        return None

    return {g: to_unicode(g) for g in font.getGlyphOrder()}, font.getGlyphOrder()


def main(legacy_path, unicode_path, output_path):
    legacy_images = render_all_glyphs(legacy_path)
    unicode_images = render_all_glyphs(unicode_path)
    glyph_unicode, unicode_names = unicode_value_of_each_glyph(unicode_path)

    candidates = list(unicode_images)
    stack = np.stack([unicode_images[g][0] for g in candidates])
    aspects = np.array([unicode_images[g][1] for g in candidates])

    legacy_font = TTFont(legacy_path)
    name_to_id = {n: i for i, n in enumerate(legacy_font.getGlyphOrder())}

    table = {}
    for codepoint, glyph_name in sorted(legacy_font.getBestCmap().items()):
        glyph_id = name_to_id[glyph_name]
        if glyph_id not in legacy_images:
            continue
        image, aspect = legacy_images[glyph_id]
        difference = (np.abs(stack - image).mean(axis=(1, 2))
                      + 0.3 * np.abs(aspects - aspect) / (aspects + aspect))
        for best in np.argsort(difference)[:3]:
            decoded = glyph_unicode.get(unicode_names[candidates[best]])
            if decoded:
                table[codepoint] = "".join(chr(c) for c in decoded)
                break

    json.dump({str(k): v for k, v in table.items()},
              open(output_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"draft table with {len(table)} entries -> {output_path}")
    print("IMPORTANT: review it by eye before trusting it (see file docstring).")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: python build_mapping.py <legacy.ttf> <unicode.ttf> <out.json>")
    main(*sys.argv[1:])
