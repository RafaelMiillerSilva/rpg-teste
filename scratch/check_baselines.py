import os
import numpy as np
from PIL import Image

def check_bottom_y(path, num_frames):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    step = w / num_frames
    bottoms = []
    tops = []
    for i in range(num_frames):
        x0 = int(round(i * step))
        x1 = int(round((i + 1) * step))
        sub = im.crop((x0, 0, x1, h))
        arr = np.array(sub)
        ys, xs = np.where(arr[:, :, 3] > 10)
        if len(ys) > 0:
            bottoms.append(ys.max())
            tops.append(ys.min())
    print(f"{os.path.basename(path)} ({num_frames} frames): Bottom Y={bottoms}, Top Y={tops}")

check_bottom_y('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_idle.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_run.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_atck.png', 4)

check_bottom_y('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_idle.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_run.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_atck.png', 6)

check_bottom_y('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_idle.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_run.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_guard.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_atck.png', 4)

check_bottom_y('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_idle.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_run.png', 6)
check_bottom_y('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_smash.png', 6)
