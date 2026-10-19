import os
import numpy as np
from PIL import Image

output_base = 'assets/tiny_swords/Units/monsters/goblin/standardized'
os.makedirs(output_base, exist_ok=True)

def process_sheet(src_path, num_frames, out_name, target_h=70, frame_size=(192, 192), baseline_y=136):
    im = Image.open(src_path).convert('RGBA')
    w, h = im.size
    step = w / num_frames
    
    # First, let's find the max height and bottom baseline across all frames in this sheet
    crops = []
    max_sub_h = 0
    for i in range(num_frames):
        x0 = int(round(i * step))
        x1 = int(round((i + 1) * step))
        sub = im.crop((x0, 0, x1, h))
        arr = np.array(sub)
        ys, xs = np.where(arr[:, :, 3] > 10)
        if len(ys) > 0:
            ymin, ymax = ys.min(), ys.max()
            xmin, xmax = xs.min(), xs.max()
            char_crop = sub.crop((xmin, ymin, xmax + 1, ymax + 1))
            crops.append((char_crop, ymin, ymax, xmin, xmax))
            if (ymax - ymin + 1) > max_sub_h:
                max_sub_h = ymax - ymin + 1
        else:
            crops.append((None, 0, 0, 0, 0))
            
    # Scale ratio to match target_h
    scale = target_h / max_sub_h if max_sub_h > 0 else 1.0
    
    sheet = Image.new('RGBA', (frame_size[0] * num_frames, frame_size[1]), (0, 0, 0, 0))
    for i, (char_crop, ymin, ymax, xmin, xmax) in enumerate(crops):
        if char_crop is None:
            continue
        cw = int(round(char_crop.width * scale))
        ch = int(round(char_crop.height * scale))
        # Use nearest neighbor for crisp pixel art!
        resized = char_crop.resize((cw, ch), Image.NEAREST)
        
        # Center horizontally in the 192px frame
        dest_x = i * frame_size[0] + (frame_size[0] - cw) // 2
        dest_y = baseline_y - ch
        sheet.paste(resized, (dest_x, dest_y))
        
    out_path = os.path.join(output_base, out_name)
    sheet.save(out_path)
    print(f"Generated {out_name}: {sheet.size} (scale={scale:.2f})")

# 1. Normal Goblin (target_h = 65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_idle.png', 6, 'normie_idle.png', target_h=65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_run.png', 6, 'normie_run.png', target_h=65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_atck.png', 4, 'normie_attack.png', target_h=65)

# 2. Range Goblin (target_h = 65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_idle.png', 6, 'range_idle.png', target_h=65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_run.png', 6, 'range_run.png', target_h=65)
# Note: range_goblin_atck has 6 main action frames (frame 5 was dart debris, but 6 frames work nicely or custom slice)
process_sheet('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_atck.png', 6, 'range_attack.png', target_h=65)

# 3. Warrior Goblin (target_h = 75, sturdy)
process_sheet('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_idle.png', 6, 'warrior_idle.png', target_h=75)
process_sheet('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_run.png', 6, 'warrior_run.png', target_h=75)
process_sheet('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_guard.png', 6, 'warrior_guard.png', target_h=75)
process_sheet('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_atck.png', 4, 'warrior_attack.png', target_h=75)

# 4. Healer Goblin (target_h = 65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/healer_goblin/healer_goblin_idle.png', 6, 'healer_idle.png', target_h=65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/healer_goblin/healer_goblin_run.png', 6, 'healer_run.png', target_h=65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/healer_goblin/healer_goblin_heal.png', 11, 'healer_heal.png', target_h=65)

# 5. Giant Goblin (target_h = 135 in 256x256 frame, baseline_y = 190)
process_sheet('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_idle.png', 6, 'giant_idle.png', target_h=135, frame_size=(256, 256), baseline_y=190)
process_sheet('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_run.png', 6, 'giant_run.png', target_h=135, frame_size=(256, 256), baseline_y=190)
process_sheet('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_run_and_shot.png', 6, 'giant_run_shot.png', target_h=135, frame_size=(256, 256), baseline_y=190)
process_sheet('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_smash.png', 6, 'giant_smash.png', target_h=135, frame_size=(256, 256), baseline_y=190)

print("All standardized sheets generated successfully!")
