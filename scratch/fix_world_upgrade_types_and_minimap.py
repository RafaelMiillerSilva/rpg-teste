with open('scenes/world.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Update Castle UpgradeArea
old_castle = '''[node name="UpgradeArea" type="Area2D" parent="Buildings/Castle" unique_id=537323794]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")'''

new_castle = '''[node name="UpgradeArea" type="Area2D" parent="Buildings/Castle" unique_id=537323794]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")
building_type = "castle"'''

if old_castle in text:
    text = text.replace(old_castle, new_castle)
    print("Replaced Castle UpgradeArea")

# 2. Update Monastery UpgradeArea
old_monastery = '''[node name="UpgradeArea" type="Area2D" parent="Buildings/Monastery" unique_id=2117259899]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")'''

new_monastery = '''[node name="UpgradeArea" type="Area2D" parent="Buildings/Monastery" unique_id=2117259899]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")
building_type = "monastery"'''

if old_monastery in text:
    text = text.replace(old_monastery, new_monastery)
    print("Replaced Monastery UpgradeArea")

# 3. Update Barracks UpgradeArea
old_barracks = '''[node name="UpgradeArea" type="Area2D" parent="Buildings/Barracks" unique_id=2101514063]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")'''

new_barracks = '''[node name="UpgradeArea" type="Area2D" parent="Buildings/Barracks" unique_id=2101514063]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")
building_type = "barracks"'''

if old_barracks in text:
    text = text.replace(old_barracks, new_barracks)
    print("Replaced Barracks UpgradeArea")

# 4. Update Archery UpgradeArea
old_archery = '''[node name="UpgradeArea" type="Area2D" parent="Buildings/Archery" unique_id=1344804361]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")'''

new_archery = '''[node name="UpgradeArea" type="Area2D" parent="Buildings/Archery" unique_id=1344804361]
position = Vector2(0, 10)
collision_layer = 0
script = ExtResource("32_upgrade_area_script")
building_type = "archery"'''

if old_archery in text:
    text = text.replace(old_archery, new_archery)
    print("Replaced Archery UpgradeArea")

# 5. Insert Minimap into CanvasLayer (right before DialogueBox)
minimap_snippet = '''[node name="Minimap" parent="CanvasLayer" instance=ExtResource("34_minimap")]
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -180.0
offset_top = 125.0
offset_right = -20.0
offset_bottom = 245.0
grow_horizontal = 0

'''

if 'instance=ExtResource("34_minimap")' not in text:
    target = '[node name="DialogueBox" parent="."'
    if target in text:
        text = text.replace(target, minimap_snippet + target)
        print("Inserted Minimap into CanvasLayer")

with open('scenes/world.tscn', 'w', encoding='utf-8') as f:
    f.write(text)

print("Updated world.tscn successfully.")
