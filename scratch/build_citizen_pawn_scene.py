out_path = 'scenes/npc_citizen_pawn.tscn'

variants = [
    ("axe", "res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle Axe.png"),
    ("hammer", "res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle Hammer.png"),
    ("knife", "res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle Knife.png"),
    ("meat", "res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle Meat.png"),
    ("pickaxe", "res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle Pickaxe.png"),
    ("wood", "res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle Wood.png"),
    ("normal", "res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle.png"),
    ("gold", "res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle Gold.png")
]

content = f'''[gd_scene load_steps={len(variants)*9 + 10} format=3]

[ext_resource type="Script" path="res://scripts/npc_citizen_pawn.gd" id="1_citizen_script"]
'''

for idx, (name, path) in enumerate(variants):
    content += f'[ext_resource type="Texture2D" path="{path}" id="{idx+2}_{name}_tex"]\n'
content += '\n'

# Atlas textures (8 frames each)
for idx, (name, path) in enumerate(variants):
    tex_id = f'{idx+2}_{name}_tex'
    for f in range(8):
        content += f'''[sub_resource type="AtlasTexture" id="AtlasTexture_{name}_{f}"]
atlas = ExtResource("{tex_id}")
region = Rect2({f * 192}, 0, 192, 192)

'''

# SpriteFrames
anim_defs = []
for name, _ in variants:
    frame_items = '}, {'.join([f'''"duration": 1.0,
"texture": SubResource("AtlasTexture_{name}_{f}")''' for f in range(8)])
    anim_defs.append(f'''{{
"frames": [{{{frame_items}}}],
"loop": true,
"name": &"{name}",
"speed": 10.0
}}''')

content += f'''[sub_resource type="SpriteFrames" id="SpriteFrames_citizen"]
animations = [{', '.join(anim_defs)}]

[sub_resource type="CircleShape2D" id="CircleShape2D_interact"]
radius = 48.0

[sub_resource type="RectangleShape2D" id="RectangleShape2D_col"]
size = Vector2(24, 18)

[node name="NPCCitizenPawn" type="CharacterBody2D" groups=["citizens", "npcs"]]
y_sort_enabled = true
texture_filter = 1
collision_layer = 0
collision_mask = 0
script = ExtResource("1_citizen_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
sprite_frames = SubResource("SpriteFrames_citizen")
animation = &"axe"
autoplay = "axe"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, 20)
shape = SubResource("RectangleShape2D_col")
disabled = true

[node name="InteractionArea" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="InteractionArea"]
position = Vector2(0, 10)
shape = SubResource("CircleShape2D_interact")

[node name="InteractionLabel" type="Label" parent="."]
visible = false
offset_left = -60.0
offset_top = -45.0
offset_right = 60.0
offset_bottom = -25.0
theme_override_colors/font_color = Color(1, 0.9, 0.3, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.8)
theme_override_font_sizes/font_size = 12
text = "[E] Conversar"
horizontal_alignment = 1
'''

with open(out_path, 'w', encoding='utf-8') as f:
    f.write(content)
print(f"Created {out_path}")
