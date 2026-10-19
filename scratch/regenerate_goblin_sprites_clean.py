import os
import numpy as np
from PIL import Image
from scipy.ndimage import label

output_base = 'assets/tiny_swords/Units/monsters/goblin/standardized'
os.makedirs(output_base, exist_ok=True)

def clean_frame_bleed(sub):
    arr = np.array(sub)
    alpha = (arr[:, :, 3] > 10).astype(int)
    labeled, num_features = label(alpha)
    if num_features <= 1:
        return arr
    
    cleaned = arr.copy()
    total_px = arr.shape[0] * arr.shape[1]
    for f in range(1, num_features + 1):
        ys, xs = np.where(labeled == f)
        if len(xs) == 0:
            continue
        cx = np.mean(xs)
        count = len(xs)
        # Bleed from previous frame on the left edge
        if xs.min() == 0 and cx < sub.width * 0.35 and count < (total_px * 0.25):
            cleaned[labeled == f] = 0
        # Bleed to next frame on the right edge
        elif xs.max() >= sub.width - 1 and cx > sub.width * 0.65 and count < (total_px * 0.25):
            cleaned[labeled == f] = 0
            
    return cleaned

def process_sheet(src_path, num_frames, out_name, target_h=70, frame_size=(192, 192), baseline_y=136, scale=None):
    im = Image.open(src_path).convert('RGBA')
    w, h = im.size
    step = w / num_frames
    
    crops = []
    max_sub_h = 0
    for i in range(num_frames):
        x0 = int(round(i * step))
        x1 = int(round((i + 1) * step))
        sub = im.crop((x0, 0, x1, h))
        arr = clean_frame_bleed(sub)
        
        ys, xs = np.where(arr[:, :, 3] > 10)
        if len(ys) > 0:
            ymin, ymax = ys.min(), ys.max()
            xmin, xmax = xs.min(), xs.max()
            sub_cleaned = Image.fromarray(arr)
            char_crop = sub_cleaned.crop((xmin, ymin, xmax + 1, ymax + 1))
            
            # Corta 1 pixel do lado esquerdo do sprite do goblin a pedido do usuário
            if char_crop.width > 2:
                char_crop = char_crop.crop((1, 0, char_crop.width, char_crop.height))
                
            crops.append((char_crop, ymin, ymax, xmin, xmax))
            if char_crop.height > max_sub_h:
                max_sub_h = char_crop.height
        else:
            crops.append((None, 0, 0, 0, 0))
            
    if scale is None:
        scale = target_h / max_sub_h if max_sub_h > 0 else 1.0
    
    sheet = Image.new('RGBA', (frame_size[0] * num_frames, frame_size[1]), (0, 0, 0, 0))
    for i, (char_crop, ymin, ymax, xmin, xmax) in enumerate(crops):
        if char_crop is None:
            continue
        cw = max(1, int(round(char_crop.width * scale)))
        ch = max(1, int(round(char_crop.height * scale)))
        resized = char_crop.resize((cw, ch), Image.NEAREST)
        
        # Centraliza horizontalmente e alinha na baseline dos pés
        dest_x = i * frame_size[0] + (frame_size[0] - cw) // 2
        dest_y = baseline_y - ch
        sheet.paste(resized, (dest_x, dest_y))
        
    out_path = os.path.join(output_base, out_name)
    sheet.save(out_path)
    print(f"Generated {out_name}: {sheet.size} (scale={scale:.4f})")

print("Regenerating all standardized sheets with consistent master scales...")

# 1. Normal Goblin:
# Idle height = 176 -> base scale = 65.0 / 176.0 = 0.369318
# Em goblin_atck.png os sprites brutos foram desenhados menores (~1.42x menor);
# scale = 0.525 faz o corpo do goblin no ataque ter exatamente a mesma escala 1:1 do idle e run!
normie_scale = 65.0 / 176.0
process_sheet('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_idle.png', 6, 'normie_idle.png', scale=normie_scale)
process_sheet('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_run.png', 6, 'normie_run.png', scale=normie_scale)
process_sheet('assets/tiny_swords/Units/monsters/goblin/normie_goblin/goblin_atck.png', 4, 'normie_attack.png', scale=0.525)

# 2. Range Goblin:
# Idle height = 159 -> base scale = 65.0 / 159.0 = 0.408805
range_scale = 65.0 / 159.0
process_sheet('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_idle.png', 6, 'range_idle.png', scale=range_scale)
process_sheet('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_run.png', 6, 'range_run.png', scale=range_scale)
process_sheet('assets/tiny_swords/Units/monsters/goblin/dart_goblin/range_goblin_atck.png', 6, 'range_attack.png', scale=range_scale)

# 3. Warrior Goblin:
# Escala aumentada (target_h = 88.0) e extração precisa por componente conectado com margem extra à direita para o escudo
def process_warrior_sheet_6frames(src_path, out_name, target_h=88.0, frame_size=(192, 192), baseline_y=138):
    im = Image.open(src_path).convert('RGBA')
    arr = np.array(im)
    alpha = (arr[:, :, 3] > 10).astype(int)
    labeled, num_features = label(alpha)
    comps = []
    for f in range(1, num_features + 1):
        ys, xs = np.where(labeled == f)
        if len(xs) > 300:
            comps.append({'xmin': int(xs.min()), 'xmax': int(xs.max()), 'ymin': int(ys.min()), 'ymax': int(ys.max()), 'cx': float(np.mean(xs))})
    comps.sort(key=lambda c: c['cx'])
    scale = target_h / 192.0
    sheet = Image.new('RGBA', (frame_size[0] * 6, frame_size[1]), (0, 0, 0, 0))
    for i, c in enumerate(comps):
        x_start = c['xmin'] + 1 # 1px corte à esquerda
        max_allowed_x = comps[i+1]['xmin'] - 1 if i < 5 else im.width - 1
        x_end = min(max_allowed_x, c['xmax'] + 2) # Margem ampliada à direita para não cortar escudo
        char_crop = im.crop((x_start, max(0, c['ymin'] - 1), x_end + 1, min(im.height - 1, c['ymax'] + 1) + 1))
        cw = max(1, int(round(char_crop.width * scale)))
        ch = max(1, int(round(char_crop.height * scale)))
        resized = char_crop.resize((cw, ch), Image.NEAREST)
        dest_x = i * frame_size[0] + (frame_size[0] - cw) // 2
        dest_y = baseline_y - ch
        sheet.paste(resized, (dest_x, dest_y))
    sheet.save(os.path.join(output_base, out_name))

def process_warrior_attack(src_path, out_name, target_h=88.0, frame_size=(192, 192), baseline_y=138):
    im = Image.open(src_path).convert('RGBA')
    valleys = [0, 230, 486, 733, im.width]
    scale = target_h / 192.0
    sheet = Image.new('RGBA', (frame_size[0] * 4, frame_size[1]), (0, 0, 0, 0))
    for i in range(4):
        x0, x1 = valleys[i], valleys[i+1]
        sub = im.crop((x0, 0, x1, im.height))
        sub_arr = np.array(sub)
        ys, xs = np.where(sub_arr[:, :, 3] > 10)
        if len(xs) > 0:
            xmin, xmax = int(xs.min()), int(xs.max())
            ymin, ymax = int(ys.min()), int(ys.max())
            char_crop = im.crop((x0 + xmin + 1, ymin, min(im.width, x0 + xmax + 2) + 1, ymax + 1))
            cw = max(1, int(round(char_crop.width * scale)))
            ch = max(1, int(round(char_crop.height * scale)))
            resized = char_crop.resize((cw, ch), Image.NEAREST)
            dest_x = i * frame_size[0] + (frame_size[0] - cw) // 2
            dest_y = baseline_y - ch
            sheet.paste(resized, (dest_x, dest_y))
    sheet.save(os.path.join(output_base, out_name))

process_warrior_sheet_6frames('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_idle.png', 'warrior_idle.png')
process_warrior_sheet_6frames('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_run.png', 'warrior_run.png')
process_warrior_sheet_6frames('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_guard.png', 'warrior_guard.png')
process_warrior_attack('assets/tiny_swords/Units/monsters/goblin/warrior_goblin/goblin_warrior_atck.png', 'warrior_attack.png')

# 4. Healer Goblin:
# Idle height = 209 -> base scale = 65.0 / 209.0 = 0.311005
# Em healer_goblin_heal.png a resolução do spritesheet foi exportada pela metade (~0.5x);
# scale = 0.60 faz o corpo do curandeiro ter exatamente a mesma escala 1:1 do idle e run!
healer_scale = 65.0 / 209.0
process_sheet('assets/tiny_swords/Units/monsters/goblin/healer_goblin/healer_goblin_idle.png', 6, 'healer_idle.png', scale=healer_scale)
process_sheet('assets/tiny_swords/Units/monsters/goblin/healer_goblin/healer_goblin_run.png', 6, 'healer_run.png', scale=healer_scale)
process_sheet('assets/tiny_swords/Units/monsters/goblin/healer_goblin/healer_goblin_heal.png', 11, 'healer_heal.png', scale=0.60)

# 5. Giant Goblin:
# Idle height = 128 -> base scale = 135.0 / 128.0 = 1.0546875
giant_scale = 135.0 / 128.0
process_sheet('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_idle.png', 6, 'giant_idle.png', scale=giant_scale, frame_size=(256, 256), baseline_y=190)
process_sheet('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_run.png', 6, 'giant_run.png', scale=giant_scale, frame_size=(256, 256), baseline_y=190)
process_sheet('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_run_and_shot.png', 6, 'giant_run_shot.png', scale=giant_scale, frame_size=(256, 256), baseline_y=190)
process_sheet('assets/tiny_swords/Units/monsters/goblin/giant_goblin/giant_goblin_smash.png', 6, 'giant_smash.png', scale=giant_scale, frame_size=(256, 256), baseline_y=190)

print("Done regenerating all sheets with consistent master scale!")
