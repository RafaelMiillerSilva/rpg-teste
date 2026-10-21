lines = []
lines.append('[gd_scene load_steps=15 format=3]')
lines.append('')
lines.append('[ext_resource type="Script" path="res://scripts/enemies/goblin_fireball.gd" id="1_script"]')
lines.append('[ext_resource type="Texture2D" path="res://assets/tiny_swords/Particle FX/Explosion_02.png" id="2_exp_tex"]')
lines.append('[ext_resource type="AudioStream" path="res://assets/sounds/8_Atk_Magic_SFX/04_Fire_explosion_04_medium.wav" id="3_exp_sfx"]')
lines.append('')

# Flight frame: frame 0
lines.append('[sub_resource type="AtlasTexture" id="AtlasTexture_flight_0"]')
lines.append('atlas = ExtResource("2_exp_tex")')
lines.append('region = Rect2(0, 0, 192, 192)')
lines.append('')

# Explode frames: frames 1 to 9
for i in range(1, 10):
    x = i * 192
    lines.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_exp_{i}"]')
    lines.append('atlas = ExtResource("2_exp_tex")')
    lines.append(f'region = Rect2({x}, 0, 192, 192)')
    lines.append('')

lines.append('[sub_resource type="SpriteFrames" id="SpriteFrames_fireball"]')
lines.append('animations = [{')
lines.append('"frames": [{')
lines.append('"duration": 1.0,')
lines.append('"texture": SubResource("AtlasTexture_flight_0")')
lines.append('}],')
lines.append('"loop": true,')
lines.append('"name": &"flight",')
lines.append('"speed": 5.0')
lines.append('}, {')
lines.append('"frames": [')
for i in range(1, 10):
    comma = "," if i < 9 else ""
    lines.append('{')
    lines.append('"duration": 1.0,')
    lines.append(f'"texture": SubResource("AtlasTexture_exp_{i}")')
    lines.append('}' + comma)
lines.append('],')
lines.append('"loop": false,')
lines.append('"name": &"explode",')
lines.append('"speed": 16.0')
lines.append('}]')
lines.append('')

lines.append('[sub_resource type="CircleShape2D" id="CircleShape2D_fireball"]')
lines.append('radius = 16.0')
lines.append('')

lines.append('[node name="GoblinFireball" type="Area2D"]')
lines.append('collision_layer = 0')
lines.append('collision_mask = 5')
lines.append('script = ExtResource("1_script")')
lines.append('')

lines.append('[node name="AnimatedSprite2D" type="AnimatedSprite2D"]')
lines.append('texture_filter = 1')
lines.append('scale = Vector2(0.5, 0.5)')
lines.append('sprite_frames = SubResource("SpriteFrames_fireball")')
lines.append('animation = &"flight"')
lines.append('autoplay = "flight"')
lines.append('')

lines.append('[node name="CollisionShape2D" type="CollisionShape2D"]')
lines.append('shape = SubResource("CircleShape2D_fireball")')
lines.append('')

lines.append('[node name="AudioStreamPlayer2D" type="AudioStreamPlayer2D"]')
lines.append('stream = ExtResource("3_exp_sfx")')
lines.append('volume_db = 1.0')
lines.append('max_distance = 1200.0')
lines.append('')

with open("scenes/enemies/goblin_fireball.tscn", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print("Created scenes/enemies/goblin_fireball.tscn successfully")
