out_path = 'scenes/pawn_gold.tscn'

content = '''[gd_scene load_steps=19 format=3]

[ext_resource type="Script" path="res://scripts/pawn_gold.gd" id="1_pawn_script"]
[ext_resource type="Texture2D" path="res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle Gold.png" id="2_pawn_idle_gold"]
[ext_resource type="Texture2D" path="res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Run Gold.png" id="3_pawn_run_gold"]

'''

# Idle frames (8 frames)
for i in range(8):
    content += f'''[sub_resource type="AtlasTexture" id="AtlasTexture_idle_{i}"]
atlas = ExtResource("2_pawn_idle_gold")
region = Rect2({i * 192}, 0, 192, 192)

'''

# Run frames (6 frames)
for i in range(6):
    content += f'''[sub_resource type="AtlasTexture" id="AtlasTexture_run_{i}"]
atlas = ExtResource("3_pawn_run_gold")
region = Rect2({i * 192}, 0, 192, 192)

'''

idle_items = '}, {'.join([f'''"duration": 1.0,
"texture": SubResource("AtlasTexture_idle_{i}")''' for i in range(8)])

run_items = '}, {'.join([f'''"duration": 1.0,
"texture": SubResource("AtlasTexture_run_{i}")''' for i in range(6)])

content += f'''[sub_resource type="SpriteFrames" id="SpriteFrames_pawn"]
animations = [{{
"frames": [{{{idle_items}}}],
"loop": true,
"name": &"idle",
"speed": 10.0
}}, {{
"frames": [{{{run_items}}}],
"loop": true,
"name": &"run",
"speed": 10.0
}}]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_pawn"]
size = Vector2(24, 18)

[node name="PawnGold" type="CharacterBody2D" groups=["helpers", "pawns"]]
y_sort_enabled = true
texture_filter = 1
collision_layer = 0
collision_mask = 1
script = ExtResource("1_pawn_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
sprite_frames = SubResource("SpriteFrames_pawn")
animation = &"idle"
autoplay = "idle"

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, 20)
shape = SubResource("RectangleShape2D_pawn")

[node name="CapacityLabel" type="Label" parent="."]
offset_left = -30.0
offset_top = -30.0
offset_right = 30.0
offset_bottom = -14.0
theme_override_colors/font_color = Color(1, 0.9, 0.2, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.8)
theme_override_font_sizes/font_size = 12
text = "🪙 0/25"
horizontal_alignment = 1
'''

with open(out_path, 'w', encoding='utf-8') as f:
    f.write(content)
print(f"Created {out_path}")
