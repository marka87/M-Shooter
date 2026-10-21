"""Bereitet eigene Sounds fuers Spiel auf: assets/sounds/new/ (beliebige Unterordner, .wav) -> assets/sounds/custom/.

Aufruf aus dem Projektordner:
    python tools/import_custom_sounds.py

- Dateiname = Spiel-Name, Ziffern am Ende = Variante: impact.wav, impact1.wav, impact2.wav -> impact_1..3 (Zufallsauswahl).
  Schritte sind feste Namen: footstep1.wav -> footstep_1.wav.
- Stille am Anfang wird entfernt (sonst klingt der Schuss verzoegert), Stille am Ende gekuerzt,
  alles auf dieselbe Spitzenlautstaerke gebracht (Lautstaerke pro Sound regelt der Code).
- custom/ hat Vorrang vor Kenney-OGG und erzeugten WAVs. Das Skript ersetzt custom/ jedes Mal komplett.
- Ansager: assets/sounds/new/Announcer/*.mp3 laut Tabelle ANNOUNCER nach custom/announcer/ (unveraendert kopiert,
  MP3 laesst sich ohne Zusatzbibliothek nicht schneiden). Zwei Dateien fuer einen Satz = Zufallsauswahl.
Benoetigt nur numpy. assets/sounds/new/ bekommt eine .gdignore, damit Godot die Rohdateien nicht mit exportiert.
"""
import glob
import os
import re
import shutil
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets', 'sounds', 'new')
OUT = os.path.join(ROOT, 'assets', 'sounds', 'custom')
# Dateinamen, die nicht dem Spiel-Namen entsprechen
ALIASES = {'ligthning': 'lightning', 'rocket launcher': 'rocket_fire', 'rocket_launcher': 'rocket_fire'}
FIXED_NUMBERS = {'footstep'}
# Ansager-Dateiname (ohne .mp3, ohne Varianten-Ziffer) -> Satz im Spiel (GameManager.play_announcer)
ANNOUNCER = {
    'Combo Whore': 'combo', 'DOMINATING!': 'dominating', 'Double Kill!': 'double_kill', 'FIGHT!': 'fight',
    'First Blood!': 'first_blood', 'Five minutes remaining': 'five_minutes', 'GODLIKE!': 'godlike',
    'Killing Spree!': 'killing_spree', 'M-M-M-MONSTER KILL!': 'monster_kill', 'MEGA KILL!': 'mega_kill',
    'Mega Health': 'mega_health', 'Multi Kill!': 'multi_kill', 'One minute remaining.': 'one_minute', 'One!': 'one',
    'QUAD DAMAGE!': 'quad_damage', 'RAMPAGE!': 'rampage', 'Three!': 'three', 'Two!': 'two',
    'UNSTOPPABLE!': 'unstoppable', 'You... Lose': 'you_lose', 'You... Win.': 'you_win', 'headshot': 'headshot',
}
SILENCE = 0.01
PEAK = 0.89


def read(path):
    with wave.open(path) as w:
        assert w.getsampwidth() == 2, f'{path}: nur 16-Bit-WAV'
        x = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').reshape(-1, w.getnchannels())
        return x.astype(np.float64) / 32768.0, w.getframerate()


def prepare(x, sr):
    loud = np.nonzero(np.abs(x).max(axis=1) > SILENCE)[0]
    if len(loud) == 0:
        return x
    start = max(loud[0] - int(sr * 0.002), 0)
    end = min(loud[-1] + int(sr * 0.03), len(x))
    x = x[start:end].copy()
    fade = min(int(sr * 0.02), len(x))
    x[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    return x * (PEAK / np.abs(x).max())


def write(path, x, sr):
    with wave.open(path, 'wb') as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767).astype('<i2').tobytes())


def main():
    groups = {}
    for path in sorted(glob.glob(os.path.join(SRC, '**', '*.wav'), recursive=True)):
        stem = os.path.splitext(os.path.basename(path))[0].lower()
        m = re.fullmatch(r'(.*?)[ _]?(\d*)', stem)
        base, number = ALIASES.get(m.group(1), m.group(1)), m.group(2)
        if base in FIXED_NUMBERS:
            base, number = f'{base}_{number}', ''
        groups.setdefault(base, []).append(path)
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    for base, paths in sorted(groups.items()):
        for i, path in enumerate(paths):
            x, sr = read(path)
            x = prepare(x, sr)
            write(os.path.join(OUT, base + ('.wav' if len(paths) == 1 else f'_{i + 1}.wav')), x, sr)
        print(f'{base:16} {len(paths)} Datei(en)')
    announcer_groups = {}
    for path in sorted(glob.glob(os.path.join(SRC, 'Announcer', '*.mp3'))):
        stem = re.sub(r'\d+$', '', os.path.splitext(os.path.basename(path))[0])
        if stem not in ANNOUNCER:
            print(f'UNBEKANNT (in ANNOUNCER eintragen): {os.path.basename(path)}')
            continue
        announcer_groups.setdefault(ANNOUNCER[stem], []).append(path)
    os.makedirs(os.path.join(OUT, 'announcer'))
    for key, paths in sorted(announcer_groups.items()):
        for i, path in enumerate(paths):
            shutil.copyfile(path, os.path.join(OUT, 'announcer', key + ('.mp3' if len(paths) == 1 else f'_{i + 1}.mp3')))
        print(f'announcer/{key:16} {len(paths)} Datei(en)')
    open(os.path.join(SRC, '.gdignore'), 'w').close()


if __name__ == '__main__':
    main()
