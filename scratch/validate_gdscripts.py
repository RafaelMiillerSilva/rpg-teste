import glob
import re

gd_files = glob.glob("scripts/**/*.gd", recursive=True) + glob.glob("scripts/*.gd")
print(f"Validando {len(gd_files)} scripts GDScript...")

has_error = False

for path in sorted(gd_files):
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    func_names = []
    for line_idx, line in enumerate(lines):
        # checa definição de funções
        m = re.match(r'^(?:static\s+)?func\s+([a-zA-Z0-9_]+)\s*\(', line.strip())
        if m:
            fn = m.group(1)
            if fn in func_names:
                print(f"[ERRO] {path}:{line_idx+1}: Função duplicada '{fn}'")
                has_error = True
            func_names.append(fn)

if not has_error:
    print("TODOS os GDScripts estao validos sem funcoes duplicadas!")
