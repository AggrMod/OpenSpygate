"""Renders the car's sounds from nothing but arithmetic: no samples, no recordings.

Writes mono 16-bit WAV files into game/audio/vehicle/ (relative to this repository):

  engine_on_<rpm>.wav   the engine pulling, one loop per engine speed
  engine_off_<rpm>.wav  the engine on a closed throttle (overrun), one loop per engine speed
  tyre_roll.wav         tyre noise on asphalt, loop; the game raises pitch and level with speed
  tyre_skid.wav         a sliding tyre's squeal, loop; the game sets its level from wheel slip
  wind.wav              air over the body, loop; the game raises it with speed squared
  door_open.wav, door_close.wav, impact.wav   one-shots

Each loop file ends with a copy of its first 16 frames: the game loops at (length - 16), see LOOP_GUARD.
Every loop is made periodic by construction: the random parts are drawn once per loop length and
repeated, the filters are run over three copies and the middle copy is kept, so the end of the file runs
straight into its start with no click. Engine loops hold a whole number of engine cycles.

The engine is a four-cylinder, four-stroke petrol engine: two firings per revolution. Each firing is an
exhaust pulse; small differences between cylinders give the uneven, lumpy sound at low speed. The pulses go
through fixed resonances (the exhaust pipe and silencer) so that, as in a real car, the firing rate changes
with engine speed but the tone colour does not.

Requires Python 3 with numpy and scipy. Run:  python tools/audio/render_vehicle_sounds.py
"""

from __future__ import annotations

import json
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 32000
LOOP_GUARD = 16                                        # frames repeated after each loop's end (see write)
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "audio" / "vehicle"

ON_RPMS = [900, 1500, 2400, 3600, 5000, 6600]
OFF_RPMS = [1500, 2400, 3600, 5000, 6600]
FIRING_ORDER_VARIATION = [0.00, 0.07, -0.05, 0.03]     # each cylinder's pulse strength, relative
CYLINDER_DELAY_MS = [0.00, 0.12, -0.08, 0.05]          # and its timing


def db(x: float) -> float:
    return 20.0 * np.log10(max(x, 1e-12))


def periodic_filter(b, a, x: np.ndarray) -> np.ndarray:
    """Filters a periodic signal so the output is periodic too: run over three copies, keep the middle."""
    n = len(x)
    y = signal.lfilter(b, a, np.tile(x, 3))
    return y[n:2 * n]


def resonator(freq: float, q: float):
    """A band-pass peak at freq with quality q, as (b, a)."""
    return signal.iirpeak(freq, q, fs=SR)


def lowpass(freq: float, order: int = 2):
    return signal.butter(order, freq, btype="low", fs=SR)


def highpass(freq: float, order: int = 2):
    return signal.butter(order, freq, btype="high", fs=SR)


def bandpass(lo: float, hi: float, order: int = 2):
    return signal.butter(order, [lo, hi], btype="band", fs=SR)


def periodic_lfo(n: int, rng: np.random.Generator, rates_hz: list[float], depth: float) -> np.ndarray:
    """A slow wobble made of sines that each fit a whole number of times into n samples."""
    t = np.arange(n) / SR
    seconds = n / SR
    out = np.zeros(n)
    for rate in rates_hz:
        cycles = max(1, round(rate * seconds))
        out += np.sin(2 * np.pi * cycles * t / seconds + rng.uniform(0, 2 * np.pi))
    return out / max(len(rates_hz), 1) * depth


def place_impulses(n: int, times: np.ndarray, amps: np.ndarray) -> np.ndarray:
    """Impulses at fractional sample positions, wrapping round the loop."""
    x = np.zeros(n)
    pos = times * SR
    i0 = np.floor(pos).astype(int)
    frac = pos - i0
    np.add.at(x, i0 % n, amps * (1.0 - frac))
    np.add.at(x, (i0 + 1) % n, amps * frac)
    return x


def engine_loop(rpm: float, on_load: bool, seconds: float = 1.25) -> tuple[np.ndarray, float]:
    rng = np.random.default_rng(int(rpm) * 7 + (1 if on_load else 2))
    cycle_hz = rpm / 60.0 / 2.0                      # one engine cycle is two revolutions
    # A whole number of cycles that is also a whole number of frames, so the loop runs at exactly this rpm
    # and every layer keeps step with the others in the game.
    cycles = max(2, round(seconds * cycle_hz))
    while abs(cycles * SR / cycle_hz - round(cycles * SR / cycle_hz)) > 1e-6:
        cycles += 1
    n = round(cycles / cycle_hz * SR)
    firings = cycles * 4
    period = n / SR / firings                       # exact, so the loop holds whole cycles
    true_rpm = 60.0 / (period * 2.0)
    k = np.arange(firings)
    cyl = k % 4
    jitter = rng.normal(0.0, 0.035 if on_load else 0.09, firings)
    strength = (1.0 if on_load else 0.30) * (1.0 + np.take(FIRING_ORDER_VARIATION, cyl) + jitter)
    times = k * period + np.take(CYLINDER_DELAY_MS, cyl) / 1000.0 + rng.normal(0.0, 0.00006, firings)
    x = place_impulses(n, times, strength)

    # The exhaust pulse: a quick pressure rise and a slower fall, then a slight suction. Slow engines
    # push softer, rounder pulses; the silencer takes the edge off them.
    speed = (rpm - 900.0) / 5700.0
    tau = (0.0013 - 0.0008 * speed) if on_load else (0.0016 - 0.0007 * speed)
    t = np.arange(int(0.012 * SR)) / SR
    pulse = (t / tau) * np.exp(1.0 - t / tau) - 0.35 * (t / (tau * 4)) * np.exp(1.0 - t / (tau * 4))
    x = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(pulse, n)))   # circular, so it wraps round the loop

    # Fixed resonances of the pipe and silencer, and a pipe echo (comb).
    body = np.zeros(n)
    for freq, q, gain in [(88.0, 1.6, 1.0), (165.0, 2.2, 0.9), (410.0, 2.5, 0.55), (980.0, 3.0, 0.30), (2300.0, 3.5, 0.14)]:
        b, a = resonator(freq, q)
        body += gain * periodic_filter(b, a, x)
    body = 0.55 * body + 0.45 * x
    delay = int(round(2 * 2.6 / 343.0 * SR))
    comb_b = np.zeros(delay + 1)
    comb_b[0] = 1.0
    comb_a = np.zeros(delay + 1)
    comb_a[0] = 1.0
    comb_a[delay] = -0.32
    body = periodic_filter(comb_b, comb_a, body)
    b, a = lowpass((1800.0 + 2200.0 * rpm / 6600.0) if on_load else (1100.0 + 600.0 * rpm / 6600.0), 2)
    exhaust = periodic_filter(b, a, body)

    # Intake roar: noise shaped by each firing, stronger when pulling hard and fast.
    noise = rng.normal(0.0, 1.0, n)
    b, a = bandpass(250.0, 1600.0, 2)
    roar = periodic_filter(b, a, noise)
    envelope = periodic_filter(*lowpass(min(4.0 / period, 900.0), 1), np.abs(x))
    envelope /= max(np.max(envelope), 1e-9)
    intake_level = (0.10 + 0.25 * (rpm / 6600.0)) * (1.0 if on_load else 0.25)

    # Valve train: soft ticks at camshaft rate, heard most at idle.
    ticks = place_impulses(n, (np.arange(firings * 2) * period / 2.0) % (n / SR), rng.uniform(0.6, 1.0, firings * 2))
    b, a = bandpass(3000.0, 7000.0, 2)
    tick = periodic_filter(b, a, ticks)

    out = exhaust / max(np.std(exhaust), 1e-9)
    out += intake_level * (roar / max(np.std(roar), 1e-9)) * (0.4 + envelope)
    out += 0.05 * (tick / max(np.std(tick), 1e-9)) * (1.0 - rpm / 9000.0)
    if not on_load and rpm >= 2400:
        # Overrun burble: a few soft, sparse pops in the silencer.
        pops = np.zeros(n)
        count = int(n / SR * (3 + rpm / 1200.0))
        for at in rng.integers(0, n, count):
            length = int(SR * rng.uniform(0.004, 0.010))
            burst = rng.normal(0, 1, length) * np.exp(-np.arange(length) / (length / 4))
            idx = (at + np.arange(length)) % n
            pops[idx] += burst * rng.uniform(0.2, 0.6)
        b, a = bandpass(150.0, 1200.0, 2)
        out += 0.6 * periodic_filter(b, a, pops)
    out -= np.mean(out)
    return out, true_rpm


def tyre_roll(seconds: float = 2.0) -> np.ndarray:
    rng = np.random.default_rng(11)
    n = int(seconds * SR)
    noise = rng.normal(0, 1, n)
    rumble = periodic_filter(*bandpass(60.0, 320.0, 2), noise)
    hiss = periodic_filter(*bandpass(500.0, 2200.0, 2), rng.normal(0, 1, n))
    # The tread passes the road in a repeating but uneven pattern.
    tread = 1.0 + periodic_lfo(n, rng, [9.0, 13.0, 23.0], 0.25)
    out = (rumble / np.std(rumble) + 0.35 * hiss / np.std(hiss)) * tread
    return out - np.mean(out)


def tyre_skid(seconds: float = 2.0) -> np.ndarray:
    rng = np.random.default_rng(23)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    wobble = periodic_lfo(n, rng, [0.5, 1.5, 3.5, 7.0], 0.035)
    out = np.zeros(n)
    for ratio, level in [(1.0, 1.0), (1.97, 0.45), (2.93, 0.22), (4.05, 0.08)]:
        cycles = round(1180.0 * ratio * seconds)            # whole cycles, so the tone loops cleanly
        phase = 2 * np.pi * cycles * t / seconds + 2 * np.pi * np.cumsum(wobble) * 1180.0 * ratio / SR
        out += level * np.sin(phase)
    # Stick-slip chatter of the rubber, and the hiss of the slide.
    chatter = 0.65 + 0.35 * np.clip(periodic_lfo(n, rng, [37.0, 52.0, 71.0], 2.0), -1, 1)
    hiss = periodic_filter(*bandpass(1500.0, 5000.0, 2), rng.normal(0, 1, n))
    out = out * chatter + 0.5 * hiss / np.std(hiss)
    return out - np.mean(out)


def wind(seconds: float = 3.0) -> np.ndarray:
    rng = np.random.default_rng(31)
    n = int(seconds * SR)
    white = rng.normal(0, 1, n)
    # Pinkish: sum of bands, each moving slowly so the air seems to gust.
    out = np.zeros(n)
    for lo, hi, level in [(120.0, 400.0, 1.0), (400.0, 1200.0, 0.6), (1200.0, 4000.0, 0.25)]:
        band = periodic_filter(*bandpass(lo, hi, 2), rng.normal(0, 1, n))
        out += level * band / np.std(band) * (1.0 + periodic_lfo(n, rng, [0.4, 0.9, 1.7], 0.35))
    del white
    return out - np.mean(out)


def decaying(freq: float, seconds: float, decay: float, n: int, start: int = 0, drop: float = 0.0) -> np.ndarray:
    """A decaying sine from sample start, optionally falling in pitch by the fraction drop."""
    out = np.zeros(n)
    t = np.arange(n - start) / SR
    f = freq * (1.0 - drop * (1.0 - np.exp(-t / max(decay, 1e-4))))
    phase = 2 * np.pi * np.cumsum(f) / SR
    out[start:] = np.sin(phase) * np.exp(-t / decay)
    return out


def click(n: int, start: int, rng: np.random.Generator, lo: float, hi: float, ms: float) -> np.ndarray:
    out = np.zeros(n)
    length = int(SR * ms / 1000.0)
    burst = rng.normal(0, 1, length) * np.exp(-np.arange(length) / (length / 5))
    out[start:start + length] = burst
    return signal.lfilter(*bandpass(lo, hi, 2), out)


def door_close() -> np.ndarray:
    rng = np.random.default_rng(41)
    n = int(0.7 * SR)
    hit = int(0.004 * SR)
    out = 1.0 * decaying(72.0, 0.7, 0.07, n, hit, 0.15)            # the air in the cabin and the door skin
    out += 0.6 * decaying(118.0, 0.7, 0.05, n, hit, 0.1)
    out += 0.25 * decaying(260.0, 0.7, 0.03, n, hit)
    out += 0.35 * click(n, hit, rng, 1800.0, 6000.0, 6.0)           # the latch
    out += 0.12 * decaying(2900.0, 0.7, 0.025, n, hit) + 0.08 * decaying(4300.0, 0.7, 0.018, n, hit)
    out += 0.10 * click(n, hit + int(0.035 * SR), rng, 1200.0, 4000.0, 4.0)   # the second catch
    return out


def door_open() -> np.ndarray:
    rng = np.random.default_rng(43)
    n = int(0.5 * SR)
    pull = int(0.004 * SR)
    release = pull + int(0.06 * SR)
    out = 0.25 * click(n, pull, rng, 1500.0, 5000.0, 4.0)           # the handle
    out += 0.45 * click(n, release, rng, 1500.0, 6000.0, 5.0)       # the latch letting go
    out += 0.10 * decaying(3100.0, 0.5, 0.02, n, release)
    out += 0.45 * decaying(55.0, 0.5, 0.06, n, release, 0.1)        # the seal coming away
    seal = signal.lfilter(*bandpass(200.0, 900.0, 2), rng.normal(0, 1, n)) * np.exp(-np.maximum(np.arange(n) - release, 0) / (0.05 * SR))
    seal[:release] = 0.0
    out += 0.08 * seal / max(np.std(seal[release:]), 1e-9)
    return out


def impact() -> np.ndarray:
    rng = np.random.default_rng(47)
    n = int(0.9 * SR)
    hit = int(0.003 * SR)
    out = 1.0 * decaying(58.0, 0.9, 0.12, n, hit, 0.35)
    burst = click(n, hit, rng, 60.0, 900.0, 25.0)
    out += 0.8 * burst / max(np.max(np.abs(burst)), 1e-9)
    for freq, level, decay in [(340.0, 0.25, 0.16), (610.0, 0.18, 0.12), (985.0, 0.12, 0.09), (1730.0, 0.06, 0.06)]:
        out += level * decaying(freq * rng.uniform(0.98, 1.02), 0.9, decay, n, hit)     # body panels ringing
    out += 0.15 * click(n, hit, rng, 2000.0, 7000.0, 8.0)
    return out


def fade(x: np.ndarray, fade_in_ms: float, fade_out_ms: float) -> np.ndarray:
    x = x.copy()
    a = max(1, int(SR * fade_in_ms / 1000.0))
    b = max(1, int(SR * fade_out_ms / 1000.0))
    x[:a] *= np.linspace(0.0, 1.0, a)
    x[-b:] *= np.linspace(1.0, 0.0, b)
    return x


def to_peak(x: np.ndarray, peak_dbfs: float) -> np.ndarray:
    return x / max(np.max(np.abs(x)), 1e-12) * 10 ** (peak_dbfs / 20.0)


def soft_limit(x: np.ndarray, ceiling_dbfs: float) -> np.ndarray:
    c = 10 ** (ceiling_dbfs / 20.0)
    return c * np.tanh(x / c)


def write(name: str, x: np.ndarray, report: dict, loop: bool) -> None:
    # A loop carries a copy of its first LOOP_GUARD frames after its end. The engine's resampler reads a few
    # frames past the loop end before it wraps; with the copy there it reads the right ones, not silence.
    body = np.concatenate([x, x[:LOOP_GUARD]]) if loop else x
    pcm = np.clip(np.round(body * 32767.0), -32768, 32767).astype("<i2")
    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    seam = abs(float(x[0]) - float(x[-1]))
    steps = np.abs(np.diff(x))
    report[name] = {
        "seconds": round(len(x) / SR, 3),
        "peak_dbfs": round(db(float(np.max(np.abs(x)))), 2),
        "rms_dbfs": round(db(float(np.sqrt(np.mean(x ** 2)))), 2),
        "loop": loop,
        "loop_end_frame": len(x) if loop else None,
        "seam_step": round(seam, 5),
        "p999_step": round(float(np.percentile(steps, 99.9)), 5),
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    report: dict = {}
    # The engine loops share one gain so that their levels keep the real relation between speeds and loads.
    loops = {}
    for rpm in ON_RPMS:
        loops[f"engine_on_{rpm:04d}.wav"] = engine_loop(rpm, True)
    for rpm in OFF_RPMS:
        loops[f"engine_off_{rpm:04d}.wav"] = engine_loop(rpm, False)
    for name, (x, true_rpm) in loops.items():
        on = "_on_" in name
        rpm = true_rpm
        # Louder when pulling and when fast; the game adds its own level on top.
        level_db = (-22.0 if on else -29.0) + 5.0 * (rpm / 6600.0)
        y = x / max(np.sqrt(np.mean(x ** 2)), 1e-12) * 10 ** (level_db / 20.0)
        y = soft_limit(y, -6.5)
        write(name, y, report, True)
        report[name]["rpm"] = round(true_rpm, 2)
    write("tyre_roll.wav", soft_limit(to_peak(tyre_roll(), -9.0), -6.5), report, True)
    write("tyre_skid.wav", soft_limit(to_peak(tyre_skid(), -7.0), -6.5), report, True)
    write("wind.wav", soft_limit(to_peak(wind(), -9.0), -6.5), report, True)
    write("door_open.wav", fade(to_peak(door_open(), -12.0), 0.0, 20.0), report, False)
    write("door_close.wav", fade(to_peak(door_close(), -8.0), 0.0, 30.0), report, False)
    write("impact.wav", fade(to_peak(impact(), -5.0), 0.0, 40.0), report, False)
    with open(OUT / "sounds.json", "w", encoding="utf-8") as f:
        json.dump({"sample_rate": SR, "generator": "tools/audio/render_vehicle_sounds.py", "files": report}, f, indent=2)
    for name, r in report.items():
        print(f"{name:24s} {r['seconds']:6.3f} s  peak {r['peak_dbfs']:6.1f} dBFS  rms {r['rms_dbfs']:6.1f} dBFS  seam {r['seam_step']:.4f}  p99.9 step {r['p999_step']:.4f}")


if __name__ == "__main__":
    main()
