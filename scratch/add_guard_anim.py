import re

def add_guard_to_warrior_scene(scene_path):
    with open(scene_path, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'Warrior_Guard.png' in content:
        print(f"{scene_path} already has Warrior_Guard.png")
        return

    # 1. Add ExtResource for Warrior_Guard.png
    ext_guard = '[ext_resource type="Texture2D" path="res://assets/tiny_swords/Units/Blue Units/Warrior/Warrior_Guard.png" id="5_warrior_guard"]'
    # Find last ext_resource line
    ext_idx = content.rfind('[ext_resource')
    end_of_line = content.find('\n', ext_idx)
    content = content[:end_of_line+1] + ext_guard + '\n' + content[end_of_line+1:]

    # 2. Add AtlasTextures for guard
    guard_atlas = ""
    for i in range(6):
        guard_atlas += f'''[sub_resource type="AtlasTexture" id="AtlasTexture_guard_{i}"]
atlas = ExtResource("5_warrior_guard")
region = Rect2({i * 192}, 0, 192, 192)

'''
    # Insert right before [sub_resource type="SpriteFrames"
    sf_idx = content.find('[sub_resource type="SpriteFrames"')
    content = content[:sf_idx] + guard_atlas + content[sf_idx:]

    # 3. Add "guard" animation into SpriteFrames animations list
    guard_frames = ', '.join([f'SubResource("AtlasTexture_guard_{i}")' for i in range(6)])
    guard_anim_entry = f''', {{
"frames": [{guard_frames}],
"loop": true,
"name": &"guard",
"speed": 10.0
}}'''

    # Find the closing "}]" of animations
    # We look for the last animation before "}]"
    last_brace = content.rfind('}]', 0, content.find('[node name='))
    content = content[:last_brace] + guard_anim_entry + content[last_brace:]

    with open(scene_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Updated {scene_path} with guard animation.")

add_guard_to_warrior_scene('scenes/ally_warrior.tscn')
add_guard_to_warrior_scene('scenes/npc_warrior.tscn')
