#!/usr/bin/env python3
"""Render the repository's simple icon geometry at iOS Settings sizes."""
from pathlib import Path
from PIL import Image, ImageDraw

out = Path(__file__).resolve().parent / 'icons'
out.mkdir(exist_ok=True)
# Draw at 8x for clean antialiased edges; each output has exactly 29pt extent.
for scale, suffix in [(1, ''), (2, '@2x'), (3, '@3x')]:
    n = 29 * scale
    factor = 8
    im = Image.new('RGBA', (n * factor, n * factor))
    d = ImageDraw.Draw(im)
    def box(values): return tuple(round(v * scale * factor) for v in values)
    d.rounded_rectangle(box((0, 0, 29, 29)), radius=6 * scale * factor, fill='#6152DC')
    # Three notification tiles, with clear up/down chevrons.
    for x in (6, 12, 18):
        d.rounded_rectangle(box((x, 12, x + 5, 17)), radius=scale * factor, fill='white')
    for points in [((11, 8.5), (14.5, 5), (18, 8.5)), ((11, 20.5), (14.5, 24), (18, 20.5))]:
        points = [(round(x * scale * factor), round(y * scale * factor)) for x,y in points]
        d.line(points, fill='white', width=round(1.8 * scale * factor), joint='curve')
    im = im.resize((n,n), Image.Resampling.LANCZOS)
    im.save(out / f'icon{suffix}.png')
    assert im.getbbox() is not None and im.getextrema()[3][1] == 255
print('Rendered Settings icons: 29x29, 58x58, 87x87')
