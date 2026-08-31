#!/usr/bin/env python3
"""Generate simple synthesized sound effects as WAV files for the Jokarz soundboard."""
import math, struct, wave, os, random

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
        data += struct.pack('<h', int(v * 32767))
    w.writeframes(bytes(data)); w.close()
    print('wrote', path, len(samples), 'samples')

def tone(freq, dur, amp=0.5, decay=0.0, wobble=0.0, square=False):
    n = int(SR * dur); out = []
    for i in range(n):
        t = i / SR
        f = freq + wobble * math.sin(2 * math.pi * 5 * t) if wobble else freq
        ph = 2 * math.pi * f * t
        s = math.sin(ph) if not square else (1.0 if math.sin(ph) >= 0 else -1.0)
        env = math.exp(-decay * t) if decay else 1.0
        out.append(s * env * amp)
    return out

# Whistle: high pitch with a sharp initial burst + vibrato
wh = tone(2400, 0.7, amp=0.55, wobble=60)
for i in range(int(0.02 * SR)): wh[i] = 0  # sharp onset
write('whistle', wh)

# Siren: alternating low/high
sir = []
for k, (f, d) in enumerate([(700, 0.8), (950, 0.8)]):
    seg = tone(f, d, amp=0.5)
    if k == 1: seg = seg[::-1]  # continuous sweep feel
    sir += seg
write('siren', sir)

# Buzzer: low square wave
write('buzzer', tone(180, 0.5, amp=0.6, square=True))

# Chips: three quick high clicks
ch = []
for _ in range(3):
    ch += tone(3200, 0.05, amp=0.7, decay=80) + [0.0] * int(0.06 * SR)
write('chips', ch)

# Victory: ascending arpeggio C-E-G-C
victory = []
for f in [523.25, 659.25, 783.99, 1046.5]:
    victory += tone(f, 0.22, amp=0.55, decay=6)
write('victory', victory)

# Bell: decaying with harmonics
bell = []
for i in range(int(1.2 * SR)):
    t = i / SR
    env = math.exp(-5 * t)
    s = (math.sin(2*math.pi*1250*t) + 0.5*math.sin(2*math.pi*2500*t) + 0.3*math.sin(2*math.pi*3750*t))
    bell.append(s * env * 0.5)
write('bell', bell)
print('done')
