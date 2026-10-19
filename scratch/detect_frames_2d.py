import os
import numpy as np
from PIL import Image

goblin_dir = 'assets/tiny_swords/Units/monsters/goblin'

def analyze_sheet_2d(name, path):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    arr = np.array(im)
    alpha = arr[:, :, 3]
    
    # Let's inspect where content is
    y_indices, x_indices = np.where(alpha > 10)
    if len(y_indices) == 0:
        print(f"{name}: EMPTY")
        return
    min_y, max_y = y_indices.min(), y_indices.max()
    print(f"=== {name} ({w}x{h}) | Y span: {min_y}..{max_y} (height {max_y-min_y+1}) ===")
    
    col_has_pixels = (alpha > 10).any(axis=0)
    blocks = []
    in_block = False
    start = 0
    for x in range(w):
        if col_has_pixels[x] and not in_block:
            in_block = True
            start = x
        elif not col_has_pixels[x] and in_block:
            in_block = False
            # ignore tiny noise blocks (< 15 px)
            if x - start >= 15:
                blocks.append((start, x - 1))
    if in_block and w - start >= 15:
        blocks.append((start, w - 1))
        
    for i, (bx0, bx1) in enumerate(blocks):
        sub_alpha = alpha[:, bx0:bx1+1]
        sy, sx = np.where(sub_alpha > 10)
        print(f"  Frame {i}: X=[{bx0}..{bx1}] (w={bx1-bx0+1}), Y=[{sy.min()}..{sy.max()}] (h={sy.max()-sy.min()+1})")

for root, dirs, files in os.walk(goblin_dir):
    for f in sorted(files):
        if f.endswith('.png') and f != 'dart.png':
            analyze_sheet_2d(f, os.path.join(root, f))
