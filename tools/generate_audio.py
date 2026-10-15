"""
Generates all Food Heroes sound effects + a looping music bed as 16-bit mono
WAV files in res://audio/. Pure standard library, no dependencies.

Run from anywhere:  python tools/generate_audio.py
Re-run any time to regenerate the sounds.
"""
# Offline asset generator for the WAV files consumed by scripts/Audio.gd.
# Running this intentionally overwrites matching files in the project's audio/ folder.
import math
import os
import random
import struct
import wave

SR = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


def tone(freq, dur, vol=0.5, wave_type="sine", decay=3.0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        ph = (freq * t) % 1.0
        if wave_type == "sine":
            s = math.sin(2 * math.pi * ph)
        elif wave_type == "square":
            s = 1.0 if ph < 0.5 else -1.0
        elif wave_type == "saw":
            s = 2.0 * ph - 1.0
        elif wave_type == "tri":
            s = 2.0 * abs(2.0 * ph - 1.0) - 1.0
        else:
            s = math.sin(2 * math.pi * ph)
        e = math.exp(-decay * (i / n))            # exponential decay
        atk = min(1.0, i / max(1.0, 0.005 * SR))  # short attack to avoid clicks
        out.append(s * vol * e * atk)
    return out


def noise(dur, vol=0.5, decay=8.0):
    n = int(SR * dur)
    return [random.uniform(-1, 1) * vol * math.exp(-decay * (i / n)) for i in range(n)]


def mix(*signals):
    n = max(len(s) for s in signals)
    out = [0.0] * n
    for sig in signals:
        for i, v in enumerate(sig):
            out[i] += v
    return out


def seq(*chunks):
    out = []
    for c in chunks:
        out.extend(c)
    return out


def save(name, samples):
    data = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s)) * 32767)
        data += struct.pack("<h", v)
    path = os.path.join(OUT_DIR, name + ".wav")
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data)
    w.close()
    print("wrote", path, "(%.2fs)" % (len(samples) / SR))


def build_music():
    # Gentle 8s arpeggio loop over C - Am - F - G.
    chords = {
        "C":  [261.63, 329.63, 392.00, 523.25],
        "Am": [220.00, 261.63, 329.63, 440.00],
        "F":  [174.61, 261.63, 349.23, 440.00],
        "G":  [196.00, 246.94, 392.00, 587.33],
    }
    music = []
    for name in ["C", "Am", "F", "G"]:
        notes = chords[name]
        bass = tone(notes[0] / 2.0, 2.0, 0.10, "sine", decay=1.2)
        arp = []
        for nf in notes:
            arp = seq(arp, tone(nf, 0.5, 0.13, "sine", decay=2.2))
        music = seq(music, mix(arp, bass))
    return music


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    random.seed(7)

    save("click", tone(720, 0.06, 0.45, "square", decay=6.0))
    save("correct", seq(tone(659, 0.09, 0.42, "sine"), tone(988, 0.13, 0.42, "sine")))
    save("wrong", seq(tone(196, 0.10, 0.5, "square"), tone(150, 0.16, 0.5, "square")))
    save("zap", mix(noise(0.18, 0.45, 11.0), tone(1300, 0.18, 0.22, "saw", decay=9.0)))
    save("heal", seq(tone(523, 0.10, 0.38, "sine"), tone(659, 0.10, 0.38, "sine"),
                     tone(784, 0.16, 0.40, "sine", decay=2.0)))
    save("slam", mix(tone(95, 0.26, 0.8, "sine", decay=7.0), noise(0.07, 0.5, 22.0)))
    save("win", seq(tone(523, 0.12, 0.5), tone(659, 0.12, 0.5),
                    tone(784, 0.12, 0.5), tone(1046, 0.24, 0.5, decay=2.0)))
    save("lose", seq(tone(392, 0.16, 0.5), tone(330, 0.16, 0.5),
                     tone(262, 0.30, 0.5, decay=2.0)))
    save("music", build_music())


if __name__ == "__main__":
    main()
