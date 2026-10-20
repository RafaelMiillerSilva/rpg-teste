from fontTools.ttLib import TTFont

f = TTFont(r"assets/font/AncientModernTales-a7Po.ttf")
cmap = f.getBestCmap()
test_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789áéíóúâêîôûãõçÁÉÍÓÚÂÊÎÔÛÃÕÇ.,!?:;-\"'()[]{} "
missing = [c for c in test_chars if ord(c) not in cmap]
print("Missing chars count:", len(missing))
print("Missing chars:", missing)
available_sample = [c for c in test_chars if ord(c) in cmap]
print("Covered count:", len(available_sample))
