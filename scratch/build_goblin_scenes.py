import os

scenes_dir = 'scenes/enemies'
os.makedirs(scenes_dir, exist_ok=True)

def generate_goblin_tscn(filename, script_path, anims, collision_size=(28, 20), collision_pos=(0, 25), frame_size=(192, 192), hp=25):
    tscn = ['[gd_scene load_steps=%d format=3]\n' % (len(anims) * 8 + 10)]
    
    ext_idx = 1
    ext_map = {}
    ext_lines = []
    
    # Script
    ext_lines.append(f'[ext_resource type="Script" path="{script_path}" id="{ext_idx}_script"]')
    script_id = f'{ext_idx}_script'
    ext_idx += 1
    
    # Textures
    for anim_name, (tex_path, count, fps, loop) in anims.items():
        if tex_path not in ext_map:
            ext_map[tex_path] = f'{ext_idx}_{anim_name}_tex'
            ext_lines.append(f'[ext_resource type="Texture2D" path="{tex_path}" id="{ext_map[tex_path]}"]')
            ext_idx += 1
            
    tscn.extend(ext_lines)
    tscn.append('')
    
    # AtlasTextures
    sub_lines = []
    anim_frames = {}
    fw, fh = frame_size
    for anim_name, (tex_path, count, fps, loop) in anims.items():
        tex_id = ext_map[tex_path]
        anim_frames[anim_name] = []
        for i in range(count):
            sub_id = f'AtlasTexture_{anim_name}_{i}'
            anim_frames[anim_name].append(sub_id)
            sub_lines.append(f'[sub_resource type="AtlasTexture" id="{sub_id}"]')
            sub_lines.append(f'atlas = ExtResource("{tex_id}")')
            sub_lines.append(f'region = Rect2({i * fw}, 0, {fw}, {fh})\n')
            
    # SpriteFrames
    sub_lines.append('[sub_resource type="SpriteFrames" id="SpriteFrames_goblin"]')
    sub_lines.append('animations = [{')
    
    anim_entries = []
    for anim_name, (tex_path, count, fps, loop) in anims.items():
        frame_items = '}, {'.join([f'''"duration": 1.0,
"texture": SubResource("{fid}")''' for fid in anim_frames[anim_name]])
        anim_entries.append(f'''"frames": [{{{frame_items}}}],
"loop": {"true" if loop else "false"},
"name": &"{anim_name}",
"speed": {float(fps)}''')
    
    sub_lines.append('}, {'.join(anim_entries))
    sub_lines.append('}]\n')
    
    # CollisionShape
    sub_lines.append(f'[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]')
    sub_lines.append(f'size = Vector2({collision_size[0]}, {collision_size[1]})\n')
    
    tscn.extend(sub_lines)
    
    # Node tree
    nodes = f'''[node name="Goblin" type="CharacterBody2D" groups=["enemies"]]
y_sort_enabled = true
texture_filter = 1
collision_layer = 3
collision_mask = 3
script = ExtResource("{script_id}")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
sprite_frames = SubResource("SpriteFrames_goblin")
animation = &"idle"
autoplay = "idle"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2({collision_pos[0]}, {collision_pos[1]})
shape = SubResource("RectangleShape2D_body")

[node name="HealthBar" type="ProgressBar" parent="."]
offset_left = -20.0
offset_top = -28.0
offset_right = 20.0
offset_bottom = -22.0
show_percentage = false
'''
    tscn.append(nodes)
    
    out_file = os.path.join(scenes_dir, filename)
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(tscn))
    print(f"Created scene: {out_file}")

# 1. Goblin Normal
generate_goblin_tscn('goblin_normal.tscn', 'res://scripts/enemies/goblin_normal.gd', {
    'idle': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/normie_idle.png', 6, 10, True),
    'run': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/normie_run.png', 6, 10, True),
    'attack': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/normie_attack.png', 4, 10, False)
}, collision_size=(36, 42), collision_pos=(0, 16), hp=25)

# 2. Goblin Range
generate_goblin_tscn('goblin_range.tscn', 'res://scripts/enemies/goblin_range.gd', {
    'idle': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/range_idle.png', 6, 10, True),
    'run': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/range_run.png', 6, 10, True),
    'attack': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/range_attack.png', 6, 10, False)
}, collision_size=(36, 42), collision_pos=(0, 16), hp=35)

# 3. Goblin Warrior
generate_goblin_tscn('goblin_warrior.tscn', 'res://scripts/enemies/goblin_warrior.gd', {
    'idle': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/warrior_idle.png', 6, 10, True),
    'run': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/warrior_run.png', 6, 10, True),
    'guard': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/warrior_guard.png', 6, 10, True),
    'attack': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/warrior_attack.png', 4, 10, False)
}, collision_size=(40, 46), collision_pos=(0, 16), hp=65)

# 4. Goblin Healer
generate_goblin_tscn('goblin_healer.tscn', 'res://scripts/enemies/goblin_healer.gd', {
    'idle': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/healer_idle.png', 6, 10, True),
    'run': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/healer_run.png', 6, 10, True),
    'heal': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/healer_heal.png', 11, 10, False)
}, collision_size=(36, 42), collision_pos=(0, 16), hp=40)

# 5. Goblin Giant (256x256)
generate_goblin_tscn('goblin_giant.tscn', 'res://scripts/enemies/goblin_giant.gd', {
    'idle': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/giant_idle.png', 6, 10, True),
    'run': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/giant_run.png', 6, 10, True),
    'run_shot': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/giant_run_shot.png', 6, 10, True),
    'smash': ('res://assets/tiny_swords/Units/monsters/goblin/standardized/giant_smash.png', 6, 10, False)
}, collision_size=(80, 90), collision_pos=(0, 30), frame_size=(256, 256), hp=320)
