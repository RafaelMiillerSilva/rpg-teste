import os
import numpy as np
from PIL import Image

output_base = 'assets/tiny_swords/Units/monsters/goblin/standardized'
os.makedirs(output_base, exist_ok=True)

# Escala unificada calculada a partir do corpo de 256px original para alvo de 65px
# 65.0 / 256.0 = 0.25390625
UNIFIED_SCALE = 65.0 / 256.0
BASELINE_Y = 136
FRAME_SIZE = (192, 192)

sheets_info = [
    {
        'src': 'assets/tiny_swords/Units/monsters/goblin/mage_goblin/goblin_mage_idle.png',
        'frames': 4,
        'out': 'mage_idle.png'
    },
    {
        'src': 'assets/tiny_swords/Units/monsters/goblin/mage_goblin/goblin_mage_run.png',
        'frames': 3,
        'out': 'mage_run.png'
    },
    {
        'src': 'assets/tiny_swords/Units/monsters/goblin/mage_goblin/goblin_mage_atck.png',
        'frames': 4,
        'out': 'mage_attack.png'
    }
]

for item in sheets_info:
    src_path = item['src']
    num_frames = item['frames']
    out_name = item['out']
    
    im = Image.open(src_path).convert('RGBA')
    w, h = im.size
    step = w / float(num_frames)
    
    out_sheet = Image.new('RGBA', (FRAME_SIZE[0] * num_frames, FRAME_SIZE[1]), (0, 0, 0, 0))
    
    for i in range(num_frames):
        x0 = int(round(i * step))
        x1 = int(round((i + 1) * step))
        sub = im.crop((x0, 0, x1, h))
        arr = np.array(sub)
        ys, xs = np.where(arr[:, :, 3] > 10)
        
        if len(ys) == 0:
            continue
            
        ymin, ymax = int(ys.min()), int(ys.max())
        xmin, xmax = int(xs.min()), int(xs.max())
        
        char_crop = sub.crop((xmin, ymin, xmax + 1, ymax + 1))
        
        # Redimensiona rigorosamente com a mesma escala UNIFIED_SCALE
        cw = max(1, int(round(char_crop.width * UNIFIED_SCALE)))
        ch = max(1, int(round(char_crop.height * UNIFIED_SCALE)))
        
        resized = char_crop.resize((cw, ch), Image.NEAREST)
        
        # O pé do personagem (ymax) é alinhado com BASELINE_Y
        dest_x = i * FRAME_SIZE[0] + (FRAME_SIZE[0] - cw) // 2
        dest_y = BASELINE_Y - ch
        
        out_sheet.paste(resized, (dest_x, dest_y))
        
    out_path = os.path.join(output_base, out_name)
    out_sheet.save(out_path)
    print(f"Salvo {out_name}: {out_sheet.size} com escala unificada {UNIFIED_SCALE:.4f}")

print("Todas as movimentações do Goblin Mage agora têm EXATAMENTE a mesma escala!")
