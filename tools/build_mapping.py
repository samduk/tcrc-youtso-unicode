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

  step 1  render every glyph of both fonts to a small picture
  step 2  for each legacy glyph, find the most similar Unicode-font glyph
          (compare the pictures pixel by pixel)
  step 3  some matched glyphs are stacks (like སྐྱ) that have no single
          Unicode value — they are produced by the font's internal
          substitution rules (GSUB). We read those rules backwards to
          recover the sequence of characters that builds the stack.
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


# ---------------------------------------------------------------------------
# STEP 1: render every glyph of a font to a small, comparable picture.
# ---------------------------------------------------------------------------

def render_all_glyphs(font_path, size=96):
    """Return a dictionary: glyph number -> (32x32 picture, height/width)."""

    face = freetype.Face(font_path)
    face.set_char_size(size * 64)

    number_of_glyphs = TTFont(font_path)["maxp"].numGlyphs
    pictures = {}

    for glyph_id in range(number_of_glyphs):
        face.load_glyph(glyph_id, freetype.FT_LOAD_RENDER)
        bitmap = face.glyph.bitmap

        glyph_is_empty = bitmap.width == 0
        if glyph_is_empty:
            continue

        # Turn the raw bytes into a 2-D grid of pixel values (0..255).
        pixels = np.frombuffer(bytes(bitmap.buffer), dtype=np.uint8)
        pixels = pixels.reshape(bitmap.rows, bitmap.width)

        # Crop away the empty border so only the ink remains.
        ink_rows, ink_columns = np.where(pixels > 32)
        if len(ink_rows) == 0:
            continue
        top = ink_rows.min()
        bottom = ink_rows.max() + 1
        left = ink_columns.min()
        right = ink_columns.max() + 1
        pixels = pixels[top:bottom, left:right]

        # Shrink to a standard 32x32 black-and-white picture so any two
        # glyphs can be compared, whatever their original size was.
        small_picture = Image.fromarray(pixels).resize((32, 32), Image.BILINEAR)
        black_and_white = (np.asarray(small_picture) > 64).astype(np.float32)

        # Also remember the original shape (tall? wide?) — it helps tell
        # apart glyphs that look similar after shrinking.
        aspect_ratio = pixels.shape[0] / pixels.shape[1]

        pictures[glyph_id] = (black_and_white, aspect_ratio)

    return pictures


# ---------------------------------------------------------------------------
# STEP 3 (helper): what Unicode text does each glyph of the Unicode font
# represent?
#
# Simple glyphs are listed directly in the font's character map ("cmap").
# Stack glyphs are built by the font's substitution rules (GSUB): a rule
# might say "ས + ྐ + ྱ  becomes  the single stack glyph སྐྱ".
# We read those rules backwards: stack glyph -> the characters that made it.
# ---------------------------------------------------------------------------

def unicode_value_of_each_glyph(font_path):
    font = TTFont(font_path)

    # Direct mapping from the cmap: glyph name -> one Unicode codepoint.
    directly_mapped = {}
    cmap = font.getBestCmap()
    for codepoint, glyph_name in sorted(cmap.items()):
        if glyph_name not in directly_mapped:
            directly_mapped[glyph_name] = codepoint

    # Read the substitution rules.
    ligature_parts = {}    # stack glyph -> list of part glyphs
    variant_source = {}    # alternate-shape glyph -> the original glyph
    gsub = font["GSUB"].table

    for lookup in gsub.LookupList.Lookup:
        for subtable in lookup.SubTable:

            rule_builds_stacks = lookup.LookupType == 4
            rule_swaps_shapes = lookup.LookupType == 1

            if rule_builds_stacks:
                for first_glyph, ligatures in subtable.ligatures.items():
                    for ligature in ligatures:
                        stack_glyph = ligature.LigGlyph
                        if stack_glyph not in ligature_parts:
                            parts = [first_glyph] + list(ligature.Component)
                            ligature_parts[stack_glyph] = parts

            elif rule_swaps_shapes:
                for source_glyph, variant_glyph in subtable.mapping.items():
                    if variant_glyph not in variant_source:
                        variant_source[variant_glyph] = source_glyph

    def to_unicode(glyph_name, depth=0):
        """Follow the rules backwards until we reach real characters."""
        if depth > 8:                      # safety: avoid endless loops
            return None

        if glyph_name in directly_mapped:
            return [directly_mapped[glyph_name]]

        if glyph_name in ligature_parts:
            codepoints = []
            for part in ligature_parts[glyph_name]:
                decoded_part = to_unicode(part, depth + 1)
                if decoded_part is None:
                    return None
                codepoints = codepoints + decoded_part
            return codepoints

        if glyph_name in variant_source:
            original = variant_source[glyph_name]
            return to_unicode(original, depth + 1)

        return None                        # this glyph cannot be decoded

    glyph_names = font.getGlyphOrder()
    result = {}
    for glyph_name in glyph_names:
        result[glyph_name] = to_unicode(glyph_name)
    return result, glyph_names


# ---------------------------------------------------------------------------
# STEP 2 + putting it all together.
# ---------------------------------------------------------------------------

def main(legacy_font_path, unicode_font_path, output_path):

    legacy_pictures = render_all_glyphs(legacy_font_path)
    unicode_pictures = render_all_glyphs(unicode_font_path)
    glyph_unicode, unicode_glyph_names = unicode_value_of_each_glyph(unicode_font_path)

    # Put all Unicode-font pictures into one big numpy block, so one legacy
    # picture can be compared against ALL of them in a single operation.
    candidate_ids = list(unicode_pictures.keys())
    candidate_pictures = []
    candidate_aspects = []
    for glyph_id in candidate_ids:
        picture, aspect = unicode_pictures[glyph_id]
        candidate_pictures.append(picture)
        candidate_aspects.append(aspect)
    picture_block = np.stack(candidate_pictures)
    aspect_block = np.array(candidate_aspects)

    # We need glyph numbers for the legacy font's characters.
    legacy_font = TTFont(legacy_font_path)
    name_to_id = {}
    for glyph_id, glyph_name in enumerate(legacy_font.getGlyphOrder()):
        name_to_id[glyph_name] = glyph_id

    table = {}
    legacy_cmap = legacy_font.getBestCmap()

    for codepoint, glyph_name in sorted(legacy_cmap.items()):
        glyph_id = name_to_id[glyph_name]

        if glyph_id not in legacy_pictures:
            continue
        picture, aspect = legacy_pictures[glyph_id]

        # How different is this legacy picture from every candidate?
        # (average pixel difference, plus a small penalty if the
        #  original shapes had very different proportions)
        pixel_difference = np.abs(picture_block - picture).mean(axis=(1, 2))
        aspect_penalty = 0.3 * np.abs(aspect_block - aspect) / (aspect_block + aspect)
        difference = pixel_difference + aspect_penalty

        # Try the three best-looking candidates, take the first one that
        # can be decoded to Unicode.
        three_best = np.argsort(difference)[:3]
        for candidate_index in three_best:
            candidate_name = unicode_glyph_names[candidate_ids[candidate_index]]
            decoded = glyph_unicode.get(candidate_name)
            if decoded is not None:
                characters = []
                for cp in decoded:
                    characters.append(chr(cp))
                table[codepoint] = "".join(characters)
                break

    # Save the draft table as JSON.
    json_table = {}
    for codepoint, unicode_text in table.items():
        json_table[str(codepoint)] = unicode_text
    with open(output_path, "w", encoding="utf-8") as output_file:
        json.dump(json_table, output_file, ensure_ascii=False, indent=1)

    print("draft table with " + str(len(table)) + " entries -> " + output_path)
    print("IMPORTANT: review it by eye before trusting it (see file docstring).")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: python build_mapping.py <legacy.ttf> <unicode.ttf> <out.json>")
    main(sys.argv[1], sys.argv[2], sys.argv[3])
