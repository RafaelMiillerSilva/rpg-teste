import re

with open('scenes/world.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

# Check ext resources
print("Ext resources count:", len(re.findall(r'\[ext_resource', text)))
# Find max id in ext_resource
ids = [int(m) for m in re.findall(r'id="(\d+)_', text)]
print("Max ext id prefix:", max(ids) if ids else 0)

# Check houses
houses = re.findall(r'\[node name="(House\d+)"', text)
print("Existing houses:", houses)
