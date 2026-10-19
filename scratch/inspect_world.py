import re

with open('scenes/world.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

pattern = re.compile(r'\[node name="(House\d+)" type="StaticBody2D" parent="Buildings"[^\]]*\](?:\s*position = Vector2\(([^)]+)\))?', re.MULTILINE)
matches = pattern.findall(text)
print("Houses found:")
for m in matches:
    print(m)

npcs = re.findall(r'\[node name="([^"]*NPC[^"]*)"[^\]]*\](?:\s*position = Vector2\(([^)]+)\))?', text)
print("NPCs found:")
for n in npcs:
    print(n)
