import re

with open('scenes/world.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Add ExtResources
ext_to_add = '''[ext_resource type="PackedScene" path="res://scenes/minimap.tscn" id="34_minimap"]
[ext_resource type="PackedScene" path="res://scenes/pawn_gold.tscn" id="35_pawn_gold"]
[ext_resource type="PackedScene" path="res://scenes/npc_citizen_pawn.tscn" id="36_npc_citizen_pawn"]
'''

last_ext = text.rfind('[ext_resource')
end_of_line = text.find('\n', last_ext)
text = text[:end_of_line+1] + ext_to_add + text[end_of_line+1:]

# 2. Add building_type to existing UpgradeAreas
def add_building_type_to_upgrade_area(scene_text, parent_name, b_type):
    # Pattern to find [node name="UpgradeArea" parent="parent_name" ... ]
    pattern = rf'(\[node name="UpgradeArea" parent="{re.escape(parent_name)}"[^\]]*\]\n(?:[^\n]*\n)*?script = ExtResource\("32_upgrade_area_script"\))'
    match = re.search(pattern, scene_text)
    if match:
        replacement = match.group(1) + f'\nbuilding_type = "{b_type}"'
        scene_text = scene_text[:match.start()] + replacement + scene_text[match.end():]
        print(f"Added building_type='{b_type}' to {parent_name}/UpgradeArea")
    else:
        print(f"WARNING: Could not find UpgradeArea for {parent_name}")
    return scene_text

text = add_building_type_to_upgrade_area(text, 'Buildings/Castle', 'castle')
text = add_building_type_to_upgrade_area(text, 'Buildings/Monastery', 'monastery')
text = add_building_type_to_upgrade_area(text, 'Buildings/Barracks', 'barracks')
text = add_building_type_to_upgrade_area(text, 'Buildings/Archery', 'archery')

# 3. Add House6, House7, House8 (with Pawn House UpgradeArea) to Buildings
houses_to_add = '''
[node name="House6" type="StaticBody2D" parent="Buildings"]
texture_filter = 1
position = Vector2(3500, 3700)
collision_mask = 0

[node name="Sprite2D" type="Sprite2D" parent="Buildings/House6"]
texture_filter = 1
texture = ExtResource("14_house1_tex")
offset = Vector2(0, -85)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Buildings/House6"]
position = Vector2(0, -22)
shape = SubResource("RectangleShape2D_house")

[node name="House7" type="StaticBody2D" parent="Buildings"]
texture_filter = 1
position = Vector2(4100, 3700)
collision_mask = 0

[node name="Sprite2D" type="Sprite2D" parent="Buildings/House7"]
texture_filter = 1
texture = ExtResource("15_house2_tex")
offset = Vector2(0, -85)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Buildings/House7"]
position = Vector2(0, -22)
shape = SubResource("RectangleShape2D_house")

[node name="House8" type="StaticBody2D" parent="Buildings"]
texture_filter = 1
position = Vector2(4500, 3700)
collision_mask = 0

[node name="Sprite2D" type="Sprite2D" parent="Buildings/House8"]
texture_filter = 1
texture = ExtResource("16_house3_tex")
offset = Vector2(0, -85)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Buildings/House8"]
position = Vector2(0, -22)
shape = SubResource("RectangleShape2D_house")

[node name="UpgradeArea" type="Area2D" parent="Buildings/House8"]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")
building_type = "pawn_house"

[node name="CollisionShape2D" type="CollisionShape2D" parent="Buildings/House8/UpgradeArea"]
shape = SubResource("CircleShape2D_upgrade")

[node name="InteractionLabel" type="Label" parent="Buildings/House8/UpgradeArea"]
visible = false
offset_left = -70.0
offset_top = -65.0
offset_right = 70.0
offset_bottom = -45.0
theme_override_colors/font_color = Color(1, 0.9, 0.2, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 0.8)
theme_override_font_sizes/font_size = 13
text = "[E] Casa dos Peões"
horizontal_alignment = 1
'''

# Insert right after House5 collision shape or before Forest
house5_match = re.search(r'\[node name="House5"[^\]]*\]\n(?:[^\n]*\n)*?shape = SubResource\("RectangleShape2D_house"\)\n', text)
if house5_match:
    idx = house5_match.end()
    text = text[:idx] + houses_to_add + text[idx:]
    print("Added House6, House7, House8 to Buildings")
else:
    print("WARNING: Could not find House5 insertion point")

# 4. Add Minimap to CanvasLayer
minimap_node = '''
[node name="Minimap" parent="CanvasLayer" instance=ExtResource("34_minimap")]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -180.0
offset_top = 125.0
offset_right = -20.0
offset_bottom = 245.0
grow_horizontal = 0
'''

pause_btn_match = re.search(r'\[node name="PauseButton" parent="CanvasLayer"[^\]]*\]\n(?:[^\n]*\n)*?text = "⏸ Menu \[ESC\]"\n', text)
if pause_btn_match:
    idx = pause_btn_match.end()
    text = text[:idx] + minimap_node + text[idx:]
    print("Added Minimap to CanvasLayer")
else:
    print("WARNING: Could not find PauseButton insertion point")

# 5. Add 8 Static Village Citizen Pawns and Mobile PawnGold Helper
citizens_and_pawn = '''
[node name="NPCCitizen_Axe" parent="." instance=ExtResource("36_npc_citizen_pawn")]
position = Vector2(3400, 3210)
variant = "axe"

[node name="NPCCitizen_Hammer" parent="." instance=ExtResource("36_npc_citizen_pawn")]
position = Vector2(3700, 3410)
variant = "hammer"

[node name="NPCCitizen_Knife" parent="." instance=ExtResource("36_npc_citizen_pawn")]
position = Vector2(4300, 3410)
variant = "knife"

[node name="NPCCitizen_Meat" parent="." instance=ExtResource("36_npc_citizen_pawn")]
position = Vector2(3300, 3560)
variant = "meat"

[node name="NPCCitizen_Pickaxe" parent="." instance=ExtResource("36_npc_citizen_pawn")]
position = Vector2(4700, 3560)
variant = "pickaxe"

[node name="NPCCitizen_Wood" parent="." instance=ExtResource("36_npc_citizen_pawn")]
position = Vector2(3500, 3760)
variant = "wood"

[node name="NPCCitizen_Normal" parent="." instance=ExtResource("36_npc_citizen_pawn")]
position = Vector2(4100, 3760)
variant = "normal"

[node name="NPCCitizen_Gold" parent="." instance=ExtResource("36_npc_citizen_pawn")]
position = Vector2(4500, 3760)
variant = "gold"

[node name="PawnGold" parent="." instance=ExtResource("35_pawn_gold")]
position = Vector2(4050, 2920)
'''

# Add at the very end of world.tscn before or after UpgradeMenu
text = text.rstrip() + '\n' + citizens_and_pawn + '\n'

with open('scenes/world.tscn', 'w', encoding='utf-8') as f:
    f.write(text)

print("world.tscn patched successfully!")
