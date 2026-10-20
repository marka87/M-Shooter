"""Erzeugt alle Sounds des Spiels als 16-Bit-WAV (44,1 kHz) nach assets/sounds/.

Aufruf aus dem Projektordner:
    python tools/make_sounds.py [Ordner mit Ansager-Rohaufnahmen]

- Waffen, Explosionen, Treffer, Pickups, Schritte: geschichtete Synthese (Anschlag + Koerper + Rauschen + Hall)
- Musik: Synthwave-Loop, 120 BPM, 32 Takte (64 s), A-Moll (Am - F - C - G)
- Ansager: Rohaufnahmen (z. B. aus der Windows-Sprachausgabe) werden tiefer gestimmt,
  leicht verzerrt, gedoppelt und mit Hall versehen. Ohne Ordner wird dieser Teil uebersprungen.

Benoetigt nur numpy. Das Spiel laedt diese Dateien automatisch (SoundGenerator), fehlt eine,
wird der alte prozedurale Sound erzeugt.
"""
import os
import sys
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'sounds')
rng = np.random.default_rng(1234)


# ----------------------------------------------------------------------------- Grundbausteine

def n_of(seconds):
    return int(SR * seconds)


def time(seconds):
    return np.arange(n_of(seconds)) / SR


def noise(seconds):
    return rng.uniform(-1.0, 1.0, n_of(seconds))


def brown(seconds):
    x = np.cumsum(rng.uniform(-1.0, 1.0, n_of(seconds)))
    x -= np.linspace(x[0], x[-1], len(x))  # Drift entfernen
    return x / (np.max(np.abs(x)) + 1e-9)


def env(seconds, attack=0.002, decay=0.2, curve=1.0):
    """Huellkurve: kurzer Anstieg, exponentieller Abfall mit Zeitkonstante decay."""
    t = time(seconds)
    a = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    return a * np.exp(-t / decay) ** curve


def sweep(seconds, f0, f1, shape='sine', curve=1.0):
    """Ton mit Tonhoehenverlauf f0 -> f1 (curve > 1: schnell am Anfang)."""
    t = time(seconds)
    k = (t / seconds) ** (1.0 / curve)
    freq = f0 * (f1 / f0) ** k if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * k
    phase = np.cumsum(freq) / SR
    if shape == 'sine':
        return np.sin(2 * np.pi * phase)
    if shape == 'saw':
        return 2.0 * (phase % 1.0) - 1.0
    if shape == 'square':
        return np.sign(np.sin(2 * np.pi * phase))
    if shape == 'tri':
        return 2.0 * np.abs(2.0 * (phase % 1.0) - 1.0) - 1.0
    raise ValueError(shape)


def tone(seconds, freq, shape='sine', detune=0.0):
    t = time(seconds)
    phase = t * freq * (1.0 + detune)
    if shape == 'sine':
        return np.sin(2 * np.pi * phase)
    if shape == 'saw':
        return 2.0 * (phase % 1.0) - 1.0
    if shape == 'square':
        return np.sign(np.sin(2 * np.pi * phase))
    if shape == 'pulse':
        return np.where((phase % 1.0) < 0.25, 1.0, -1.0)
    raise ValueError(shape)


def filt(x, lo=None, hi=None, order=2):
    """Hoch-/Tiefpass im Frequenzbereich (weiche Flanken, kein Phasenversatz)."""
    if len(x) == 0:
        return x
    n = 1 << int(np.ceil(np.log2(len(x) * 2)))
    spec = np.fft.rfft(x, n)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    h = np.ones_like(f)
    if hi:
        h *= 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order))
    if lo:
        h *= 1.0 / np.sqrt(1.0 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(spec * h, n)[:len(x)]


def drive(x, amount):
    return np.tanh(amount * x) / np.tanh(amount)


def pad_to(x, seconds):
    n = n_of(seconds)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(*parts):
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[:len(p)] += p
    return out


def reverb(x, length=1.2, decay=0.35, wet=0.25, tone_hz=6000, predelay=0.012):
    """Faltungshall mit kuenstlicher Impulsantwort (abklingendes, gefiltertes Rauschen)."""
    ir_t = time(length)
    ir = rng.uniform(-1, 1, len(ir_t)) * np.exp(-ir_t / decay)
    ir = filt(ir, lo=200, hi=tone_hz)
    ir = np.concatenate([np.zeros(n_of(predelay)), ir])
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    n = 1 << int(np.ceil(np.log2(len(x) + len(ir))))
    wet_sig = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[:len(x) + len(ir)]
    dry = np.pad(x, (0, len(ir)))
    out = dry * (1 - wet) + wet_sig * wet * 0.6
    return trim_tail(out)


def trim_tail(x, threshold=2e-3):
    idx = np.nonzero(np.abs(x) > threshold * np.max(np.abs(x)))[0]
    return x[:idx[-1] + 1] if len(idx) else x


def fade(x, fade_in=0.0, fade_out=0.01):
    x = x.copy()
    a, b = n_of(fade_in), n_of(fade_out)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def write(name, x, peak=0.89):
    path = os.path.join(OUT, name + '.wav')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = filt(x, lo=25)  # Gleichspannungsanteil und Infraschall entfernen
    data = (np.clip(normalize(fade(x), peak), -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f'{name:28s} {len(x) / SR:5.2f} s')


def click(seconds=0.004, hi=9000):
    return filt(noise(seconds) * env(seconds, 0.0003, seconds / 3), lo=1500, hi=hi)


def metal_ring(seconds, base, partials=(1.0, 2.76, 5.4, 8.93), decay=0.15):
    """Unharmonischer Metallklang (wie angeschlagenes Blech)."""
    out = np.zeros(n_of(seconds))
    for i, p in enumerate(partials):
        out += tone(seconds, base * p) * env(seconds, 0.0005, decay / (1 + i * 0.6)) / (1 + i)
    return out


# ----------------------------------------------------------------------------- Waffen und Effekte

def machinegun():
    d = 0.28
    body = sweep(d, 180, 55, curve=3) * env(d, 0.001, 0.035)
    crack = filt(noise(d), lo=900, hi=7000) * env(d, 0.0005, 0.03)
    tail = filt(noise(d), lo=300, hi=2500) * env(d, 0.005, 0.07) * 0.4
    x = drive(mix(click() * 0.8, body * 1.2, crack, tail), 2.5)
    return reverb(x, 0.6, 0.12, 0.18)


def shotgun():
    d = 0.9
    thump = sweep(d, 110, 38, curve=3) * env(d, 0.001, 0.09) * 1.6
    blast = filt(noise(d), lo=80, hi=9000) * env(d, 0.0005, 0.08)
    crackle = filt(noise(d), lo=2500, hi=10000) * env(d, 0.001, 0.18) * 0.35 * (rng.uniform(0, 1, n_of(d)) > 0.7)
    x = drive(mix(click(0.006) * 1.2, thump, blast, crackle), 3.0)
    return reverb(x, 1.4, 0.3, 0.3)


def rocket_fire():
    d = 0.7
    thump = sweep(d, 90, 45, curve=2) * env(d, 0.002, 0.08) * 1.2
    whoosh = filt(noise(d), lo=200, hi=2500) * env(d, 0.03, 0.25)
    hiss = filt(noise(d), lo=3000, hi=9000) * env(d, 0.01, 0.12) * 0.3
    x = drive(mix(thump, whoosh, hiss), 2.0)
    return reverb(x, 1.0, 0.25, 0.22)


def explosion():
    d = 2.2
    boom = sweep(d, 75, 22, curve=2) * env(d, 0.002, 0.35) * 1.4
    rumble = filt(brown(d), hi=500) * env(d, 0.004, 0.6) * 1.2
    blast = filt(noise(d), lo=100, hi=6000) * env(d, 0.001, 0.12)
    debris = filt(noise(d), lo=1500, hi=8000) * env(d, 0.05, 0.4) * 0.25 * (rng.uniform(0, 1, n_of(d)) > 0.85)
    x = drive(mix(click(0.008, 6000), boom, rumble, blast, debris), 2.2)
    return reverb(x, 2.4, 0.7, 0.35, tone_hz=3000)


def railgun():
    d = 1.3
    zap = sweep(d, 3200, 180, curve=4) * env(d, 0.001, 0.25)
    ring = metal_ring(d, 420, decay=0.6) * 0.5
    hum = tone(d, 95, 'saw') * env(d, 0.01, 0.5) * 0.25
    crack = filt(noise(d), lo=2000, hi=12000) * env(d, 0.0005, 0.03)
    x = drive(mix(zap, ring, filt(hum, hi=900), crack), 1.8)
    return reverb(x, 1.8, 0.5, 0.35)


def plasma():
    d = 0.3
    zap = filt(sweep(d, 1500, 380, 'square', curve=2), hi=4000) * env(d, 0.001, 0.05)
    bloop = sweep(d, 600, 200) * env(d, 0.001, 0.07) * 0.6
    return reverb(mix(zap * 0.6, bloop, click(0.003) * 0.4), 0.6, 0.12, 0.2)


def lightning():
    d = 0.14
    buzz = filt(tone(d, 110, 'square'), hi=3000) * 0.5
    crackle = filt(noise(d), lo=1200, hi=11000) * (rng.uniform(0, 1, n_of(d)) > 0.55)
    am = 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 37 * time(d)))
    return drive(mix(buzz, crackle * am) * env(d, 0.002, 0.08), 2.0)


def shock_beam():
    d = 0.9
    zap = sweep(d, 2600, 240, curve=3) * env(d, 0.001, 0.14)
    harm = sweep(d, 5200, 480, curve=3) * env(d, 0.001, 0.08) * 0.35
    body = sweep(d, 300, 90, 'saw', curve=2) * env(d, 0.002, 0.12) * 0.5
    x = drive(mix(click(0.004), zap, harm, filt(body, hi=2000)), 1.6)
    return reverb(x, 1.2, 0.35, 0.3)


def shock_ball():
    d = 0.8
    lfo = 1.0 + 0.15 * np.sin(2 * np.pi * 14 * time(d))
    wob = filt(sweep(d, 240, 110, 'saw', curve=1.5) * lfo, hi=1400) * env(d, 0.01, 0.3)
    shimmer = tone(d, 900) * env(d, 0.005, 0.15) * 0.25
    return reverb(mix(wob, shimmer), 1.0, 0.3, 0.3)


def combo():
    d = 2.8
    exp_ = explosion()
    dive = sweep(d, 1400, 50, 'saw', curve=2) * env(d, 0.005, 0.5) * 0.6
    sub = sweep(d, 55, 28) * env(d, 0.01, 0.9) * 1.2
    x = mix(exp_, filt(dive, hi=3000), sub)
    return reverb(drive(x, 1.5), 2.5, 0.9, 0.3, tone_hz=4000)


def switch():
    d = 0.18
    c1 = mix(metal_ring(d, 1800, decay=0.02) * 0.6, click(0.004))
    c2 = np.pad(mix(metal_ring(d, 1300, decay=0.03) * 0.8, click(0.005)), (n_of(0.06), 0))[:n_of(d)]
    return reverb(mix(c1, c2), 0.4, 0.08, 0.15)


def empty_click():
    d = 0.08
    return mix(click(0.003, 7000), metal_ring(d, 2400, decay=0.012) * 0.4)


def hitsound():
    d = 0.22
    return mix(tone(d, 1046.5) * env(d, 0.001, 0.07), tone(d, 2093) * env(d, 0.001, 0.04) * 0.35)


def bot_hurt():
    d = 0.3
    clank = metal_ring(d, 340, decay=0.12)
    grunt = filt(sweep(d, 220, 120, 'saw'), hi=1200) * env(d, 0.005, 0.07) * 0.6
    ring_mod = grunt * tone(d, 57)
    return reverb(drive(mix(clank, ring_mod, click(0.004)), 1.5), 0.5, 0.12, 0.2)


def bot_death():
    d = 1.2
    down = filt(sweep(d, 500, 35, 'saw', curve=1.5), hi=2500) * env(d, 0.005, 0.45)
    crunch = filt(noise(d), lo=400, hi=6000) * env(d, 0.002, 0.1)
    sparks = filt(noise(d), lo=4000, hi=12000) * env(d, 0.05, 0.3) * 0.3 * (rng.uniform(0, 1, n_of(d)) > 0.9)
    x = drive(mix(down * tone(d, 31), down * 0.5, crunch, sparks), 1.8)
    return reverb(x, 1.2, 0.35, 0.25)


def chime(notes, d=0.5, step=0.07, decay=0.25):
    out = np.zeros(n_of(d))
    for i, f in enumerate(notes):
        part = (tone(d, f) + 0.3 * tone(d, f * 2)) * env(d, 0.002, decay)
        out += np.pad(part, (n_of(step * i), 0))[:n_of(d)]
    return out


def pickup():
    return reverb(chime([784, 1175]), 0.8, 0.2, 0.25)


def weapon_pickup():
    clack = mix(metal_ring(0.5, 260, decay=0.08), click(0.006)) * 0.9
    return reverb(mix(clack, np.pad(chime([523, 784, 1046], 0.6), (n_of(0.06), 0))), 1.0, 0.25, 0.25)


def quad_pickup():
    d = 1.6
    rise = filt(sweep(d, 80, 320, 'saw', curve=0.7), hi=2500) * env(d, 0.05, 0.7)
    chord = sum(tone(d, f, 'saw', dt) for f in (220, 277.2, 329.6) for dt in (-0.004, 0.004))
    chord = filt(chord, hi=3000) * env(d, 0.15, 0.8) * 0.25
    return reverb(drive(mix(rise, chord), 1.4), 1.8, 0.6, 0.35)


def mega_pickup():
    return reverb(chime([523, 659, 784, 1046], 0.9, 0.06, 0.35), 1.4, 0.4, 0.3)


def double_jump():
    d = 0.3
    return mix(filt(noise(d), lo=300, hi=3000) * env(d, 0.04, 0.08) * 0.8, sweep(d, 200, 500) * env(d, 0.01, 0.06) * 0.3)


def jump():
    d = 0.18
    return filt(noise(d), lo=200, hi=1800) * env(d, 0.02, 0.04) * 0.6


def jump_pad():
    d = 0.8
    boom = sweep(d, 70, 180, curve=0.6) * env(d, 0.003, 0.2)
    air = filt(noise(d), lo=400, hi=4000) * env(d, 0.05, 0.25) * 0.6
    return reverb(drive(mix(boom, air), 1.6), 1.0, 0.3, 0.25)


def footstep(variant):
    d = 0.16
    pitch = [1.0, 1.08, 0.93, 1.15][variant]
    thud = sweep(d, 120 * pitch, 60 * pitch, curve=2) * env(d, 0.001, 0.025)
    grate = metal_ring(d, 900 * pitch, decay=0.02) * 0.25
    scuff = filt(noise(d), lo=1500, hi=7000) * env(d, 0.001, 0.015) * 0.3
    return mix(thud, grate, scuff)


def land():
    d = 0.35
    thud = sweep(d, 100, 40, curve=2) * env(d, 0.001, 0.05) * 1.3
    grate = metal_ring(d, 700, decay=0.05) * 0.3
    return drive(mix(thud, grate, click(0.005) * 0.4), 1.5)


# ----------------------------------------------------------------------------- Musik

BPM = 120
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 32
CHORDS = [  # Am - F - C - G, je ein Takt
    (57, [57, 60, 64]), (53, [53, 57, 60]), (48, [48, 52, 55]), (55, [55, 59, 62]),
]


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def place(buf, sound, at_seconds, gain=1.0):
    i = n_of(at_seconds)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[:end - i] * gain


def music():
    total = BAR * BARS
    n = n_of(total)
    kick_bus, snare_bus, hat_bus = np.zeros(n), np.zeros(n), np.zeros(n)
    bass_bus, pad_bus, arp_bus, lead_bus = np.zeros(n), np.zeros(n), np.zeros(n), np.zeros(n)

    kick = mix(sweep(0.35, 150, 45, curve=3) * env(0.35, 0.001, 0.09), click(0.003) * 0.3)
    snare = (filt(noise(0.3), lo=1200, hi=9000) * env(0.3, 0.001, 0.06)
             + tone(0.3, 190) * env(0.3, 0.001, 0.04) * 0.5)
    hat = filt(noise(0.06), lo=7000) * env(0.06, 0.0005, 0.012)
    kick_times = []

    def section(bar):
        if bar < 4:
            return 'intro'
        if bar < 16:
            return 'a'
        if bar < 20:
            return 'break'
        return 'b'

    # Lead-Melodie fuer Teil B (Halbe/Viertel, Tonnamen als MIDI relativ zum Akkord)
    lead_pattern = [(0, 2, 76), (2, 1, 74), (3, 1, 72), (4, 3, 72), (7, 1, 71),
                    (8, 2, 72), (10, 1, 74), (11, 1, 76), (12, 4, 74)]  # in Vierteln ueber 4 Takte

    for bar in range(BARS):
        root, chord = CHORDS[bar % 4]
        sec = section(bar)
        t0 = bar * BAR
        # Schlagzeug
        if sec in ('a', 'b'):
            for beat in range(4):
                place(kick_bus, kick, t0 + beat * BEAT)
                kick_times.append(t0 + beat * BEAT)
            for beat in (1, 3):
                place(snare_bus, snare, t0 + beat * BEAT)
            for s in range(8):
                place(hat_bus, hat, t0 + s * BEAT / 2, 1.0 if s % 2 else 0.45)
        elif sec == 'break':
            for s in range(8):
                place(hat_bus, hat, t0 + s * BEAT / 2, 0.35)
        # Bass: Sechzehntel, Grundton mit Oktavspruengen
        if sec != 'break':
            for s in range(16):
                note = root - 12 + (12 if s % 4 == 2 else 0)
                f = midi(note)
                d = BEAT / 4
                part = (tone(d, f, 'saw') + tone(d, f, 'saw', 0.006)) * env(d, 0.003, d * 0.7)
                place(bass_bus, part, t0 + s * d)
        # Flaechen: Akkord mit langsamem Anschwellen, je zwei verstimmte Saegezahn-Stimmen
        d = BAR + 0.3
        pad = np.zeros(n_of(d))
        for note in chord:
            for dt in (-0.005, 0.005):
                pad += tone(d, midi(note), 'saw', dt)
        pad *= np.clip(time(d) / 0.35, 0, 1) * np.clip((d - time(d)) / 0.3, 0, 1)
        place(pad_bus, pad, t0)
        # Arpeggio: Sechzehntel ueber zwei Oktaven (ab Teil A)
        if sec in ('a', 'break', 'b'):
            seq = [chord[0], chord[1], chord[2], chord[0] + 12, chord[2], chord[1] + 12, chord[0] + 12, chord[2] + 12]
            for s in range(16):
                f = midi(seq[s % 8] + 12)
                d = BEAT / 4
                place(arp_bus, tone(d * 1.5, f, 'pulse') * env(d * 1.5, 0.002, d * 0.5), t0 + s * d)
        # Lead in Teil B
        if sec == 'b':
            group_start = (bar - 20) // 4 * 4 + 20
            if bar == group_start:
                for start, length, note in lead_pattern:
                    d = length * BEAT
                    voice = sum(tone(d, midi(note), 'saw', dt) for dt in (-0.004, 0.0, 0.004))
                    voice *= np.clip(time(d) / 0.02, 0, 1) * np.exp(-time(d) / (d * 1.5))
                    vib = 1.0  # leichte Lautstaerke-Bewegung
                    place(lead_bus, voice * vib, bar * BAR + start * BEAT)

    # Sidechain: Bass und Flaechen kurz leiser bei jedem Kick (pumpender Synthwave-Effekt)
    duck = np.ones(n)
    shape = 1.0 - 0.6 * np.exp(-time(0.4) / 0.09)
    for kt in kick_times:
        i = n_of(kt)
        end = min(n, i + len(shape))
        duck[i:end] = np.minimum(duck[i:end], shape[:end - i])

    bass = filt(bass_bus, hi=700, order=3) * duck
    pad = filt(pad_bus, lo=150, hi=1500) * duck
    arp = filt(arp_bus, lo=300, hi=3500)
    # Echo auf dem Arpeggio (punktierte Achtel)
    delay = n_of(BEAT * 0.75)
    for k, g in ((1, 0.35), (2, 0.15)):
        arp[delay * k:] += arp[:-delay * k] * g
    lead = filt(lead_bus, lo=200, hi=4500)

    out = (kick_bus * 1.0 + snare_bus * 0.45 + hat_bus * 0.18 + bass * 0.45 + pad * 0.12
           + arp * 0.16 + lead * 0.14)
    room = reverb(snare_bus * 0.45 + arp * 0.16 + lead * 0.14 + pad * 0.12, 1.6, 0.5, 1.0)[:n] * 0.35
    out = drive(out + room, 1.3)
    return out[:n]


# ----------------------------------------------------------------------------- Ansager

def read_wav(path):
    with wave.open(path, 'rb') as w:
        frames = w.readframes(w.getnframes())
        sr = w.getframerate()
        ch = w.getnchannels()
    x = np.frombuffer(frames, dtype='<i2').astype(np.float64) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    if sr != SR:
        x = np.interp(np.arange(0, len(x), sr / SR), np.arange(len(x)), x)
    return x


def announcer(raw):
    # Stille vorne und hinten entfernen
    idx = np.nonzero(np.abs(raw) > 0.02)[0]
    x = raw[max(0, idx[0] - 200): idx[-1] + 2000]
    # Tiefer stimmen (Bandmaschinen-Effekt): 0,8-fache Geschwindigkeit
    factor = 0.8
    x = np.interp(np.arange(0, len(x), factor), np.arange(len(x)), x)
    # Roboter-Doppelung: leicht verzoegerte, ringmodulierte Kopie
    double = np.pad(x, (n_of(0.018), 0))[:len(x)] * 0.45
    double *= np.sin(2 * np.pi * 55 * np.arange(len(x)) / SR) * 0.5 + 0.5
    x = mix(x, double)
    x = drive(filt(x, lo=110, hi=7000) * 1.8, 2.2)
    return reverb(x, 1.1, 0.3, 0.28, tone_hz=5000)


# ----------------------------------------------------------------------------- Ausgabe

SFX = {
    'machinegun': machinegun, 'shotgun': shotgun, 'rocket_fire': rocket_fire, 'explosion': explosion,
    'railgun': railgun, 'plasma': plasma, 'lightning': lightning, 'shock_beam': shock_beam,
    'shock_ball': shock_ball, 'combo': combo, 'switch': switch, 'empty_click': empty_click,
    'hitsound': hitsound, 'bot_hurt': bot_hurt, 'bot_death': bot_death, 'pickup': pickup,
    'weapon_pickup': weapon_pickup, 'quad_pickup': quad_pickup, 'mega_pickup': mega_pickup,
    'double_jump': double_jump, 'jump': jump, 'jump_pad': jump_pad, 'land': land,
}

if __name__ == '__main__':
    for name, fn in SFX.items():
        write(name, fn())
    for v in range(4):
        write(f'footstep_{v + 1}', footstep(v), peak=0.7)
    write('music/arena_loop', music(), peak=0.8)
    if len(sys.argv) > 1:
        raw_dir = sys.argv[1]
        for file in sorted(os.listdir(raw_dir)):
            if file.endswith('.wav'):
                write('announcer/' + file[:-4], announcer(read_wav(os.path.join(raw_dir, file))))
    print('Fertig.')
