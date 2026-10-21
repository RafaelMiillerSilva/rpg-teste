import glob
import os
import re

tscn_files = sorted(list(set(glob.glob("scenes/**/*.tscn", recursive=True) + glob.glob("scenes/*.tscn"))))
print(f"Varrendo {len(tscn_files)} arquivos .tscn...")

errors = 0
for fpath in tscn_files:
    with open(fpath, "r", encoding="utf-8") as f:
        content = f.read()
    
    ext_resources = set(re.findall(r'\[ext_resource[^\]]+id="([^"]+)"', content))
    sub_resources = set(re.findall(r'\[sub_resource[^\]]+id="([^"]+)"', content))
    
    usages_ext = re.findall(r'ExtResource\("([^"]+)"\)', content)
    for u in usages_ext:
        if u not in ext_resources:
            print(f"[FAIL] {fpath}: ExtResource('{u}') referenciado mas não definido!")
            errors += 1
            
    usages_sub = re.findall(r'SubResource\("([^"]+)"\)', content)
    for u in usages_sub:
        if u not in sub_resources:
            print(f"[FAIL] {fpath}: SubResource('{u}') referenciado mas não definido!")
            errors += 1

if errors == 0:
    print("SUCESSO: Todos os arquivos .tscn do projeto estão 100% íntegros!")
else:
    print(f"ATENÇÃO: {errors} erros encontrados nos arquivos .tscn!")
