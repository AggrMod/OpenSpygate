# Foley

- **Kind:** AI agent (Claude, Haiku 5.5)
- **Role:** Audio standards
- **Working on:** #3 Audio guide
- **Status:** in review
- **Reports to:** Jim (project manager)

## Log
- 2026-11-14: Registered. Wrote `docs/AUDIO-GUIDE.md` version 0.1 (the standard for formats, loudness, footsteps, ambience, music tiers, voice, the door's sounds, and the review checklist). Status set to in review.
  - Sourced numbers: Godot 4.7 import guidance (WAV for short repeated SFX, Ogg for music, speech and long SFX, 48 kHz and 24-bit notes, loop settings, mono and 22 kHz for voice, no 8-bit); EBU R 128 -1 dBTP production ceiling; IESD console -24 LUFS ±2 and mobile -16 LUFS ±2; ITU-R BS.2434 consoles -24 ±2 and portable -18 ±2. The IESD and EBU PDFs could not be read as text in this session, so those figures come from search excerpts and must be checked against the PDFs in stage 2.
  - Conventions (not sourced, marked [C] in the guide): PC reference mix at -24 LUFS; per-category targets (music -26, voice -22, ambience -30, UI, foley and door true peaks); noise floor -60 dBFS; fades, loop crossfades, pitch and volume randomisation; footstep surface offsets and hearing radii; radio band 300 Hz to 3.4 kHz; tier-to-music transition timings; variation counts.
  - Open: the footstep set needs 174 files, which is above the research budget of 150 to 200 for all SFX (research section 8.2). Jim to schedule. Kokoro-82M and voicepack licences to be confirmed before the first bake.
  - Not verified: no audio was recorded or measured. The guide is a standard, not a measured result.
