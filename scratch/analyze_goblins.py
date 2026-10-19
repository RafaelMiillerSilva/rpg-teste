import os
from PIL import Image

goblin_dir = 'assets/tiny_swords/Units/monsters/goblin'

for root, dirs, files in os.walk(goblin_dir):
    for f in sorted(files):
        if f.endswith('.png'):
            full_path = os.path.join(root, f)
            im = Image.open(full_path)
            w, h = im.size
            print(f"File: {f} | Size: {w}x{h}")
            # Check horizontal division candidates
            # usually 1 row with N frames where frame_w is around h or standard
            # let's find non-empty columns to detect frame boundaries
            # or check common ratios: 1024 / N
            print(f"  Ratios: 1024/4={1024/4}, 1024/5={1024/5}, 1024/6={1024/6}, 1024/8={1024/8}")
