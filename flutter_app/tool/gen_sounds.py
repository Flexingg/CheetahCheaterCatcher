#!/usr/bin/env python3
"""Generate clearly-distinct synthesized sound effects as WAV files."""
import math, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
os.makedirs(OUT, exist_ok=True)

def write(name, samples):
    path = os.path.join(OUT, name + '.wav')
    w = wave.open(path, 'w')
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    data = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s))
        data += struct.pack('<h', int(v * 32000))
    w.writeframes(bytes(data)); w.close()
    print('wrote', path, len(samples))

def env(t, dur, attack=0.01, release=0.15):
    a = min(1.0, t / attack) if attack else 1.0
    r = 1.0 if t < dur - release else max(0.0, (dur - t) / release)
    return a * r

# --- Whistle: piercing referee whistle with a fast up-warble ---
def whistle():
    n = int(0.9 * SR); out = []
    for i in range(n):
        t = i / SR
        f = 2000 + 900 * math.sin(2 * math.pi * 3.5 * t)  # strong vibrato
        s = math.sin(2 * math.pi * f * t)
        out.append(s * 0.6 * env(t, 0.9, attack=0.005, release=0.3))
    return out

# --- Siren: classic rising-falling police siren ---
def siren():
    n = int(1.6 * SR); out = []
    for i in range(n):
        t = i / SR
        # sweep 500..1100 Hz, ~0.8s per cycle
        f = 500 + 300 * math.sin(2 * math.pi * 0.6 * t)
        s = math.sin(2 * math.pi * f * t) + 0.4 * math.sin(2 * math.pi * 2 * f * t)
        out.append(s * 0.5 * env(t, 1.6, attack=0.05, release=0.3))
    return out

# --- Buzzer: harsh low square wave ---
def buzzer():
    n = int(0.55 * SR); out = []
    for i in range(n):
        t = i / SR
        ph = 2 * math.pi * 130 * t
        s = 1.0 if math.sin(ph) >= 0 else -1.0
        out.append(s * 0.6 * env(t, 0.55, attack=0.005, release=0.12))
    return out

# --- Chips: five bright rapid clicks ---
def chips():
    out = []
    for _ in range(5):
        c = int(0.045 * SR)
        for i in range(c):
            t = i / SR
            s = math.sin(2 * math.pi * 2800 * t) * math.exp(-90 * t)
            out.append(s * 0.7)
        out += [0.0] * int(0.05 * SR)
    return out

# --- Bell: bright high bell with long shimmering decay ---
def bell():
    n = int(1.3 * SR); out = []
    for i in range(n):
        t = i / SR
        d = math.exp(-4.5 * t)
        s = (math.sin(2*math.pi*1568*t) + 0.5*math.sin(2*math.pi*3136*t) + 0.25*math.sin(2*math.pi*4704*t) + 0.15*math.sin(2*math.pi*6272*t))
        out.append(s * 0.5 * d)
    return out

# --- Victory: bright ascending fanfare C-E-G-C with square-ish tone ---
def victory():
    out = []
    for f in [523.25, 659.25, 783.99, 1046.5]:
        c = int(0.24 * SR)
        for i in range(c):
            t = i / SR
            ph = 2 * math.pi * f * t
            s = (0.6 * math.sin(ph)) + (0.3 * math.sin(2 * ph))  # brighter tone
            out.append(s * env(t, 0.24, attack=0.005, release=0.1) * 0.55)
    return out

write('whistle', whistle())
write('siren', siren())
write('buzzer', buzzer())
write('chips', chips())
write('bell', bell())
write('victory', victory())
print('done')
