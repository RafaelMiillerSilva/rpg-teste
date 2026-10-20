import os
import re

files_to_check = [
    "project.godot",
    "assets/font/main_theme.tres",
    "scenes/dialogue_box.tscn",
    "scenes/main_menu.tscn",
    "scenes/pause_menu.tscn",
    "scenes/game_over.tscn",
    "scenes/upgrade_menu.tscn",
    "scenes/world.tscn",
]

all_good = True
for fpath in files_to_check:
    if not os.path.exists(fpath):
        print(f"[FAIL] Arquivo não encontrado: {fpath}")
        all_good = False
        continue
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Check for basic bracket matching in Godot files
    open_sq = content.count("[")
    close_sq = content.count("]")
    if open_sq != close_sq:
        print(f"[WARN] Bracket mismatch in {fpath}: [={open_sq}, ]={close_sq}")
    
    # Check for missing ext_resource references
    load_steps_match = re.search(r'load_steps=(\d+)', content)
    ext_resources = re.findall(r'\[ext_resource[^\]]+id="([^"]+)"', content)
    sub_resources = re.findall(r'\[sub_resource[^\]]+id="([^"]+)"', content)
    
    # Check that referenced ExtResources exist in the file
    usages = re.findall(r'ExtResource\("([^"]+)"\)', content)
    for u in usages:
        if u not in ext_resources:
            print(f"[FAIL] In {fpath}: ExtResource('{u}') referenced but not defined!")
            all_good = False
            
    usages_sub = re.findall(r'SubResource\("([^"]+)"\)', content)
    for u in usages_sub:
        if u not in sub_resources:
            print(f"[FAIL] In {fpath}: SubResource('{u}') referenced but not defined!")
            all_good = False

    print(f"[OK] {fpath} verificado com sucesso ({len(ext_resources)} ext, {len(sub_resources)} sub).")

if all_good:
    print("\nTODOS OS ARQUIVOS PASSARAM NA VALIDAÇÃO DE INTEGRIDADE!")
else:
    print("\nERROS ENCONTRADOS!")
