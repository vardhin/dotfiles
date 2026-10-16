#!/usr/bin/env python3
# Builds symbols.tsv for the CLIP pane's SYMBOLS page: one "glyph<TAB>name"
# per line, emoji first, then arrows, punctuation, math and currency.
# Single code points only (no skin tones or ZWJ sequences).
#   python3 data/build-symbols.py > data/symbols.tsv
import unicodedata

EMOJI = [(0x1F600, 0x1F64F), (0x1F910, 0x1F9FF), (0x1F300, 0x1F5FF),
         (0x1F680, 0x1F6FF), (0x1FA70, 0x1FAFF), (0x2600, 0x26FF), (0x2700, 0x27BF)]
SYMBOLS = [(0x2190, 0x21FF), (0x2010, 0x205E), (0x2200, 0x22FF), (0x20A0, 0x20C0),
           (0x2100, 0x214F), (0x00A1, 0x00BF), (0x00D7, 0x00D7), (0x00F7, 0x00F7),
           (0x2500, 0x259F), (0x25A0, 0x25FF)]

seen = set()
for lo, hi in EMOJI + SYMBOLS:
    for cp in range(lo, hi + 1):
        ch = chr(cp)
        name = unicodedata.name(ch, "")
        if not name or ch in seen or unicodedata.category(ch) in ("Cc", "Cf", "Zs", "Mn"):
            continue
        seen.add(ch)
        print(f"{ch}\t{name.lower()}")
