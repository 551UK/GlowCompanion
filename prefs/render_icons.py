#!/usr/bin/env python3
"""Prepare lower-resolution variants from the original Glow 87px icon."""
from pathlib import Path
from PIL import Image

out = Path(__file__).resolve().parent / 'icons'
source = out / 'icon@3x.png'
with Image.open(source) as image:
    assert image.size == (87, 87)
    for size, suffix in [(29, ''), (58, '@2x')]:
        image.resize((size, size), Image.Resampling.LANCZOS).save(out / f'icon{suffix}.png')
print('Prepared 29x29 and 58x58 variants; original 87x87 icon retained unchanged')
