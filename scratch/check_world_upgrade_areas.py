import re

with open('scenes/world.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

for m in re.finditer(r'\[node name="UpgradeArea" parent="([^"]+)"[^\]]*\]\n(.*?)(?=\n\[node|\Z)', text, re.DOTALL):
    print("Parent:", m.group(1))
    print("Content:\n" + m.group(2).strip() + "\n---")
