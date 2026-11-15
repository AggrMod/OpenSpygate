"""Draws what the drive_audio test recorded, so the sound can be looked at as well as measured.

Reads drive_audio.wav and timeline.json from a drive_audio test's output folder and writes drive_audio.png
there: a spectrogram with the firing frequency the rev counter predicts drawn over it (it should sit on the
lowest bright line), the level over time with the drive's events marked, and the wheel slip.

Requires Python 3 with numpy, scipy and matplotlib. Run:
  python tools/audio/analyse_drive_audio.py <output folder of the drive_audio test>
"""

from __future__ import annotations

import json
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal


def main() -> None:
    folder = Path(sys.argv[1])
    with wave.open(str(folder / "drive_audio.wav"), "rb") as w:
        rate = w.getframerate()
        channels = w.getnchannels()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768.0
    if channels == 2:
        x = x.reshape(-1, 2).mean(axis=1)
    timeline = json.loads((folder / "timeline.json").read_text(encoding="utf-8"))
    rows = np.array(timeline["rows"], dtype=float)
    t, rpm, speed, slip = rows[:, 0], rows[:, 1], rows[:, 3], rows[:, 4]

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(3, 1, figsize=(14, 10), sharex=True, gridspec_kw={"height_ratios": [3, 1.2, 1]})
    f, st, s = signal.spectrogram(x, rate, nperseg=4096, noverlap=3584)
    keep = f < 1600
    axes[0].pcolormesh(st, f[keep], 10 * np.log10(s[keep] + 1e-14), shading="auto", cmap="magma", vmin=-110, vmax=-40)
    axes[0].plot(t, rpm / 30.0, color="cyan", lw=0.8, alpha=0.8, label="firing frequency from the rev counter (rpm / 30)")
    axes[0].set_ylabel("Hz")
    axes[0].set_ylim(0, 1600)
    axes[0].legend(loc="upper right")
    hop = rate // 20
    level = [20 * np.log10(np.sqrt(np.mean(x[i:i + hop] ** 2)) + 1e-9) for i in range(0, len(x) - hop, hop)]
    axes[1].plot(np.arange(len(level)) * hop / rate, level, color="black", lw=0.8)
    axes[1].set_ylabel("dBFS (50 ms RMS)")
    axes[1].set_ylim(-70, 0)
    for at, name in timeline["events"]:
        for ax in axes:
            ax.axvline(at, color="green", lw=0.6, alpha=0.6)
        axes[1].text(at, -5, name, fontsize=8, rotation=90, va="top")
    axes[2].plot(t, slip, color="red", lw=0.8, label="largest wheel slip, m/s")
    axes[2].plot(t, speed, color="blue", lw=0.8, label="speed, m/s")
    axes[2].legend(loc="upper right")
    axes[2].set_xlabel("seconds")
    fig.tight_layout()
    out = folder / "drive_audio.png"
    fig.savefig(out, dpi=80)
    print(out)


if __name__ == "__main__":
    main()
