import os
import numpy as np
from PIL import Image

goblin_dir = 'assets/tiny_swords/Units/monsters/goblin'

def analyze_sheet(name, path):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    arr = np.array(im)
    alpha = arr[:, :, 3]
    col_has_pixels = (alpha > 10).any(axis=0)
    
    # find continuous blocks of pixels
    blocks = []
    in_block = False
    start = 0
    for x in range(w):
        if col_has_pixels[x] and not in_block:
            in_block = True
            start = x
        elif not col_has_pixels[x] and in_block:
            in_block = False
            blocks.append((start, x - 1))
    if in_block:
        blocks.append((start, w - 1))
    
    print(f"=== {name} ({w}x{h}) ===")
    print(f"Detected {len(blocks)} pixel blocks:")
    for i, b in enumerate(blocks):
        print(f"  Frame {i}: cols {b[0]}..{b[1]} (width {b[1]-b[0]+1})")

for root, dirs, files in os.walk(goblin_dir):
    for f in sorted(files):
        if f.endswith('.png') and f != 'dart.png':
            analyze_sheet(f, os.path.join(root, f))
