import re

with open('scenes/world.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

for m in re.finditer(r'\[node name="UpgradeArea"[^\n]*\n(?:[^\n]*\n){1,6}', text):
    print("UPGRADE AREA MATCH:")
    print(m.group(0))

for m in re.finditer(r'\[node name="PauseButton"[^\n]*\n(?:[^\n]*\n){1,15}', text):
    print("PAUSE BUTTON MATCH:")
    print(m.group(0))
