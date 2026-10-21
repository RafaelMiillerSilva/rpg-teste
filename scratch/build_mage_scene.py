lines = []
lines.append('[gd_scene load_steps=18 format=3]')
lines.append('')
lines.append('[ext_resource type="Script" path="res://scripts/enemies/goblin_mage.gd" id="1_script"]')
lines.append('[ext_resource type="Texture2D" path="res://assets/tiny_swords/Units/monsters/goblin/standardized/mage_idle.png" id="2_idle_tex"]')
lines.append('[ext_resource type="Texture2D" path="res://assets/tiny_swords/Units/monsters/goblin/standardized/mage_run.png" id="3_run_tex"]')
lines.append('[ext_resource type="Texture2D" path="res://assets/tiny_swords/Units/monsters/goblin/standardized/mage_attack.png" id="4_attack_tex"]')
lines.append('')

# Idle: 4 frames
for i in range(4):
    lines.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_idle_{i}"]')
    lines.append('atlas = ExtResource("2_idle_tex")')
    lines.append(f'region = Rect2({i * 192}, 0, 192, 192)')
    lines.append('')

# Run: 3 frames
for i in range(3):
    lines.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_run_{i}"]')
    lines.append('atlas = ExtResource("3_run_tex")')
    lines.append(f'region = Rect2({i * 192}, 0, 192, 192)')
    lines.append('')

# Attack: 4 frames
for i in range(4):
    lines.append(f'[sub_resource type="AtlasTexture" id="AtlasTexture_attack_{i}"]')
    lines.append('atlas = ExtResource("4_attack_tex")')
    lines.append(f'region = Rect2({i * 192}, 0, 192, 192)')
    lines.append('')

lines.append('[sub_resource type="SpriteFrames" id="SpriteFrames_mage"]')
lines.append('animations = [{')
lines.append('"frames": [')
for i in range(4):
    comma = "," if i < 3 else ""
    lines.append('{"duration": 1.0, "texture": SubResource("AtlasTexture_idle_' + str(i) + '")}' + comma)
lines.append('],')
lines.append('"loop": true,')
lines.append('"name": &"idle",')
lines.append('"speed": 8.0')
lines.append('}, {')
lines.append('"frames": [')
for i in range(3):
    comma = "," if i < 2 else ""
    lines.append('{"duration": 1.0, "texture": SubResource("AtlasTexture_run_' + str(i) + '")}' + comma)
lines.append('],')
lines.append('"loop": true,')
lines.append('"name": &"run",')
lines.append('"speed": 8.0')
lines.append('}, {')
lines.append('"frames": [')
for i in range(4):
    comma = "," if i < 3 else ""
    lines.append('{"duration": 1.0, "texture": SubResource("AtlasTexture_attack_' + str(i) + '")}' + comma)
lines.append('],')
lines.append('"loop": false,')
lines.append('"name": &"attack",')
lines.append('"speed": 8.0')
lines.append('}]')
lines.append('')

lines.append('[sub_resource type="RectangleShape2D" id="RectangleShape2D_mage"]')
lines.append('size = Vector2(36, 42)')
lines.append('')

lines.append('[node name="GoblinMage" type="CharacterBody2D" groups=["enemies"]]')
lines.append('y_sort_enabled = true')
lines.append('texture_filter = 1')
lines.append('collision_layer = 3')
lines.append('collision_mask = 3')
lines.append('script = ExtResource("1_script")')
lines.append('')

lines.append('[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."] ')
lines.append('texture_filter = 1')
lines.append('sprite_frames = SubResource("SpriteFrames_mage")')
lines.append('animation = &"idle"')
lines.append('autoplay = "idle"')
lines.append('')

lines.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="."] ')
lines.append('position = Vector2(0, 16)')
lines.append('shape = SubResource("RectangleShape2D_mage")')
lines.append('')

lines.append('[node name="HealthBar" type="ProgressBar" parent="."] ')
lines.append('offset_left = -20.0')
lines.append('offset_top = -28.0')
lines.append('offset_right = 20.0')
lines.append('offset_bottom = -22.0')
lines.append('show_percentage = false')
lines.append('')

with open("scenes/enemies/goblin_mage.tscn", "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print("Created scenes/enemies/goblin_mage.tscn successfully")
