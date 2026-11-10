# Cyberpunk Cyberware — Garry's Mod (v2.1, English)

A Cyberpunk 2077-style cyberware addon: 7 body systems, 78 implants (Mk.1–Mk.5), a cyberdeck with RAM and 14 quickhacks, Humanity, Cyberpsychosis and the Blackwall.

Installation: extract the `cyberpunk_cyberware_en` folder into `garrysmod/addons/`. Install only one language version (Russian or English).

## Controls (defaults, rebindable in F8 → “Settings”)

| Key | Action |
|---|---|
| F8 | Personal menu: body schematic, stats, quickhacks, settings |
| F6 / `/ripperdoc` | Ripperdoc terminal (admins only) |
| Z | Sandevistan / Berserk (press again to end Sandevistan early) |
| X | Cyberdeck quickhack menu (1–9 select, X / RMB / Esc close) |
| V | Kerenzikov dash |
| F | Kiroshi optics scan |
| G | Projectile Launch System |
| B | Optical Camo |

Chat: `/implants` opens the personal menu.

## Humanity and Cyberpsychosis

- Cost per implant: Mk.1 4, Mk.2 6, Mk.3 8, Mk.4 11, Mk.5 14 (optics 4–10, OS 10–22). Default limit: 100.
- Stages: below 50 Unstable, below 25 Cyberpsychosis, below 0 Terminal stage. Roughly: 6 Mk.3 implants means Unstable, 8 means Cyberpsychosis, and a full Mk.3 set reaches the Terminal stage.
- The thresholds are always visible: stage markers and a “to threshold: N” hint on the HUD, a large banner when a threshold is crossed, and a humanity forecast in the Ripperdoc terminal.
- Effects escalate by stage (the camera never shakes):
  - Unstable: intrusive-thought subtitles, whispers, red vignette.
  - Cyberpsychosis: phantom hallucinations, phantom sounds behind you, and people nearby briefly highlighted as enemies. You deal +10% damage, but spread is ×1.25.
  - Terminal: blackouts and rage episodes (+30% melee, +15% speed, −10% damage taken for 8 s). Nearby players get a message and see a red outline, an RP cue that someone is losing it. Kiroshi optics tag cyberpsychos.

## Blackwall

- The Ripperdoc grants the “Whisper from Beyond the Blackwall” and “Blackwall Breach” quickhacks. They are very strong but add **Corruption** (0–100).
- Each point of Corruption removes 0.5 Humanity. Corruption starts to decay 20 s after the last breach.
- At 100, an overload hits: damage, a 5 s EMP, and Corruption resets to 60.
- The “Blackwall Gateway” Mk.5 cyberdeck halves Corruption gained and empowers Breach.
- A Ripperdoc can purge Corruption with the “Purge Blackwall” button.

## Client console variables

- `cyber_hud 0/1`: cyberware HUD
- `cyber_psycho_fx 0..1`: psychosis visual effect intensity
- `cyber_ghosts 0/1`: Sandevistan afterimages
- `cyber_ui_sounds 0/1`: UI sounds
- `cyber_key_<action>`: key codes (easier to change in the menu)

## Balance

- Total bonus caps (`CYBERWARE.Config.Caps`): +200 HP, 50% damage reduction, 30% dodge, +35% speed, +150% melee, +50% firearms, 6 HP regen, 25% lifesteal.
- Regeneration only works out of combat (4 s after taking damage).
- Quickhacks spend RAM and have their own cooldowns.

All parameters (thresholds, psychosis consequences, Blackwall) live in `lua/autorun/cyberware_config.lua`. Implant IDs are unchanged, so existing SQLite saves load fine. The save table is shared with the Russian version.
