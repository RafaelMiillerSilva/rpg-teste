lines = []
lines.append('[gd_scene load_steps=16 format=3]')
lines.append('')
lines.append('[ext_resource type="Script" path="res://scripts/fire_effect.gd" id="1_script"]')
lines.append('[ext_resource type="Texture2D" path="res://assets/tiny_swords/Particle FX/Fire_03.png" id="2_fire_tex"]')
lines.append('')

for i in range(12):
    x = i * 64
    lines.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_fire_{i}"]')
    lines.append('atlas = ExtResource("2_fire_tex")')
    lines.append(f'region = Rect2({x}, 0, 64, 64)')
    lines.append('')

lines.append('[sub_resource type="SpriteFrames" id="SpriteFrames_fire"]')
lines.append('animations = [{')
lines.append('"frames": [')
for i in range(12):
    comma = "," if i < 11 else ""
    lines.append('{')
    lines.append('"duration": 1.0,')
    lines.append(f'"texture": SubResource("AtlasTexture_fire_{i}")')
    lines.append('}' + comma)
lines.append('],')
lines.append('"loop": true,')
lines.append('"name": &"fire",')
lines.append('"speed": 12.0')
lines.append('}]')
lines.append('')

lines.append('[node name="FireEffect" type="AnimatedSprite2D"]')
lines.append('texture_filter = 1')
lines.append('scale = Vector2(0.9, 0.9)')
lines.append('sprite_frames = SubResource("SpriteFrames_fire")')
lines.append('animation = &"fire"')
lines.append('autoplay = "fire"')
lines.append('script = ExtResource("1_script")')
lines.append('')

with open("scenes/fire_effect.tscn", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print("Created scenes/fire_effect.tscn successfully")
