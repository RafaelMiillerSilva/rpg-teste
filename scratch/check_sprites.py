import os
from PIL import Image

def inspect_dir(path):
    print(f"=== {path} ===")
    for root, dirs, files in os.walk(path):
        for f in files:
            if f.endswith('.png'):
                full_path = os.path.join(root, f)
                try:
                    with Image.open(full_path) as im:
                        print(f"{os.path.basename(f)}: size={im.size}, mode={im.mode}")
                except Exception as e:
                    print(f"Error {f}: {e}")

inspect_dir('assets/tiny_swords/Units/monsters/goblin')
inspect_dir('assets/tiny_swords/Units/Blue Units/Pawn')
inspect_dir('assets/tiny_swords/Units/Blue Units/Warrior')
inspect_dir('assets/tiny_swords/Units/Blue Units/Monk')
