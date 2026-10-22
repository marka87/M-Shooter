"""Kopiert ausgewaehlte CC0-Samples von Kenney (kenney.nl) nach assets/sounds/ als <name>.ogg.

Aufruf aus dem Projektordner, mit dem Ordner, in den die Pakete entpackt wurden
(Unterordner scifi/, impact/, digital/ aus kenney_sci-fi-sounds, kenney_impact-sounds, kenney_digital-audio):
    python tools/import_kenney.py <Ordner>

Mehrere Quellen pro Name werden zu <name>_1.ogg, <name>_2.ogg ... (das Spiel waehlt zufaellig).
Namen, die hier fehlen, bleiben bei den Sounds aus tools/make_sounds.py (WAV).
Einen Sound tauschen: Eintrag aendern, Skript erneut ausfuehren, Godot importiert beim naechsten Start.
"""
import glob
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'sounds')

S, I, D = 'scifi/Audio/', 'impact/Audio/', 'digital/Audio/'
MAP = {
    # Waffen (Shotgun, Raketenstart, Blitz: keine passenden Kenney-Samples, bleiben synthetisch)
    # MG-Ersatz als kurzer Metallschlag; der eigene Schuss in assets/sounds/custom hat Vorrang
    'machinegun': [I + 'impactMetal_heavy_000', I + 'impactMetal_heavy_002', I + 'impactMetal_heavy_004'],
    'plasma': [S + 'laserSmall_000', S + 'laserSmall_001', S + 'laserSmall_003'],
    'railgun': [S + 'laserLarge_000'],
    'shock_beam': [S + 'laserLarge_002', S + 'laserLarge_003'],
    'shock_ball': [D + 'phaserDown1'],
    'switch': [I + 'impactMetal_medium_001', I + 'impactMetal_medium_002'],
    'empty_click': [I + 'impactTin_medium_002'],
    # Explosion und Einschlag
    'explosion': [S + 'explosionCrunch_000', S + 'explosionCrunch_002'],
    'combo': [S + 'lowFrequency_explosion_000'],
    'glass_break': [I + 'impactGlass_heavy_000', I + 'impactGlass_heavy_002', I + 'impactGlass_heavy_004'],
    'crate_break': [I + 'impactPlate_heavy_001', I + 'impactPlate_heavy_003'],
    'impact': [I + 'impactMetal_light_001', I + 'impactMetal_light_002', I + 'impactMetal_light_004', I + 'impactMetal_medium_003'],
    # Spieler und Bots
    'footstep_1': [I + 'footstep_concrete_000'],
    'footstep_2': [I + 'footstep_concrete_001'],
    'footstep_3': [I + 'footstep_concrete_002'],
    'footstep_4': [I + 'footstep_concrete_003'],
    'land': [I + 'impactSoft_heavy_000', I + 'impactSoft_heavy_002'],
    'jump': [I + 'impactSoft_medium_001'],
    'double_jump': [D + 'phaserUp4'],
    'dodge': [D + 'phaserUp6'],
    'bot_hurt': [I + 'impactPunch_medium_000', I + 'impactPunch_medium_001', I + 'impactPunch_medium_003'],
    'bot_death': [S + 'explosionCrunch_001'],
    # Pickups und Sonstiges
    'pickup': [D + 'powerUp2'],
    'weapon_pickup': [D + 'powerUp7'],
    'quad_pickup': [D + 'powerUp1'],
    'mega_pickup': [D + 'powerUp3'],
    'jump_pad': [D + 'phaseJump1'],
    'teleport': [D + 'zapThreeToneUp'],
}


def main(src):
    for name, sources in MAP.items():
        # Alte Kopien dieses Namens entfernen (auch Varianten und Godot-Importdateien)
        for old in glob.glob(os.path.join(OUT, name + '.ogg*')) + glob.glob(os.path.join(OUT, name + '_[0-9].ogg*')):
            os.remove(old)
        for i, rel in enumerate(sources):
            target = name + ('.ogg' if len(sources) == 1 else f'_{i + 1}.ogg')
            shutil.copyfile(os.path.join(src, rel + '.ogg'), os.path.join(OUT, target))
        print(f'{name:16} {len(sources)} Datei(en)')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
