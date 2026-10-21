import os
import numpy as np
from PIL import Image

output_base = 'assets/tiny_swords/Units/monsters/goblin/standardized'
os.makedirs(output_base, exist_ok=True)

def process_sheet(src_path, num_frames, out_name, target_h=65, frame_size=(192, 192), baseline_y=136):
    im = Image.open(src_path).convert('RGBA')
    w, h = im.size
    step = w / float(num_frames)
    
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
            
    scale = target_h / float(max_sub_h) if max_sub_h > 0 else 1.0
    
    sheet = Image.new('RGBA', (frame_size[0] * num_frames, frame_size[1]), (0, 0, 0, 0))
    for i, (char_crop, ymin, ymax, xmin, xmax) in enumerate(crops):
        if char_crop is None:
            continue
        cw = int(round(char_crop.width * scale))
        ch = int(round(char_crop.height * scale))
        resized = char_crop.resize((cw, ch), Image.NEAREST)
        
        dest_x = i * frame_size[0] + (frame_size[0] - cw) // 2
        dest_y = baseline_y - ch
        sheet.paste(resized, (dest_x, dest_y))
        
    out_path = os.path.join(output_base, out_name)
    sheet.save(out_path)
    print(f"Generated {out_name}: {sheet.size} (scale={scale:.2f})")

# Mage Goblin (target_h = 65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/mage_goblin/goblin_mage_idle.png', 4, 'mage_idle.png', target_h=65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/mage_goblin/goblin_mage_run.png', 3, 'mage_run.png', target_h=65)
process_sheet('assets/tiny_swords/Units/monsters/goblin/mage_goblin/goblin_mage_atck.png', 4, 'mage_attack.png', target_h=65)

print("Mage goblin standardized sheets generated successfully!")
