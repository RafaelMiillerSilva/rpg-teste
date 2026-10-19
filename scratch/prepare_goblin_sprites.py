import os
import numpy as np
from PIL import Image

def slice_and_center_frames(img_path, num_frames, target_size=(192, 192), baseline_y=145, custom_widths=None):
    im = Image.open(img_path).convert('RGBA')
    w, h = im.size
    frames = []
    
    # Calculate slice boundaries
    if custom_widths:
        slices = custom_widths
    else:
        step = w / num_frames
        slices = [(int(round(i * step)), int(round((i + 1) * step))) for i in range(num_frames)]
        
    for x0, x1 in slices:
        sub = im.crop((x0, 0, x1, h))
        # Find content bounding box in sub
        arr = np.array(sub)
        alpha = arr[:, :, 3]
        ys, xs = np.where(alpha > 10)
        
        # New frame of target_size
        frame = Image.new('RGBA', target_size, (0, 0, 0, 0))
        if len(ys) > 0:
            char_w = xs.max() - xs.min() + 1
            char_h = ys.max() - ys.min() + 1
            cropped = sub.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
            
            # Place so bottom of character is at baseline_y, and centered horizontally
            dest_x = (target_size[0] - char_w) // 2
            dest_y = baseline_y - char_h
            frame.paste(cropped, (dest_x, dest_y))
        frames.append(frame)
    return frames

print("Frame slicing helper defined.")
