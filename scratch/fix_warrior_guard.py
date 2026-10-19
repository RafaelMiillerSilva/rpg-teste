import re

# 1. Fix ally_warrior.tscn and npc_warrior.tscn
def fix_warrior_guard(path):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    
    old_entry = ''', {
"frames": [SubResource("AtlasTexture_guard_0"), SubResource("AtlasTexture_guard_1"), SubResource("AtlasTexture_guard_2"), SubResource("AtlasTexture_guard_3"), SubResource("AtlasTexture_guard_4"), SubResource("AtlasTexture_guard_5")],
"loop": true,
"name": &"guard",
"speed": 10.0
}'''
    
    new_entry = ''', {
"frames": [{
"duration": 1.0,
"texture": SubResource("AtlasTexture_guard_0")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_guard_1")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_guard_2")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_guard_3")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_guard_4")
}, {
"duration": 1.0,
"texture": SubResource("AtlasTexture_guard_5")
}],
"loop": true,
"name": &"guard",
"speed": 10.0
}'''
    if old_entry in text:
        text = text.replace(old_entry, new_entry)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text)
        print(f"Fixed guard frames in {path}")
    else:
        print(f"old_entry not found in {path}")

fix_warrior_guard('scenes/ally_warrior.tscn')
fix_warrior_guard('scenes/npc_warrior.tscn')
