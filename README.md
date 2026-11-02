# Hyrax Defender

**Studio Awawas** — Mario Andres Acevedo Pico, Hassan Sharif Abbud Gonzalez, Xiaowei Xue, Minhwi Oh, Eisuke Kijima

A fast-paced, single-player 3D arcade rail shooter. You are a wildlife guardian: the camera sweeps through
rocky terrain while rock hyraxes pop out to forage, and you fire non-lethal flash-pellets to scare off
plunging eagles, stalking leopards, venomous snakes and falling rocks before they reach the colony.

## Getting started

1. Install **Godot 4.7+** (standard build, not .NET): https://godotengine.org/download
2. Clone the repo, open Godot, **Import** → select `project.godot`.
3. Press **F5** to play from the main menu, or open `scenes/game/level.tscn` and press **F6** to jump straight into a stage.

## Controls

| Action | Input |
| --- | --- |
| Shoot flash-pellet | Left mouse |
| Reload | Right mouse / Space / R |
| Pause | Esc |

## Core rules (from the High Concept Document)

- **On-rails:** the camera follows `Rail` (a `Path3D`) automatically; the player only aims, shoots and reloads.
- **Instant aiming:** shots are raycasts from the mouse, with no ballistics.
- **Combo scoring:** each tagged threat or saved hyrax builds the combo. Every 5 combo adds +1 to the multiplier (max x8).
  Missing a shot, shooting a hyrax or losing a hyrax resets it.
- **Reaction hazards:** leopards and snakes sometimes rush the screen (`LOOK OUT!`). Tag them within the time limit or lose a life.
- **Lives:** 3. You lose one when a rusher reaches you and one for every 3 hyraxes captured.
- **End of run:** reach the end of the track or lose all lives. The final score adds bonuses for accuracy, best combo and hyraxes saved, and is saved to a local high-score board.

## Project layout

```
data/stages/        StageData .tres files (one per stage: seed, pacing, threat weights, colors)
scenes/menus/       Main menu
scenes/game/        level.tscn: rail, camera, environment, spawner
scenes/actors/      hyrax, eagle, leopard, snake, falling_rock
scenes/ui/          HUD (score, combo, lives, ammo, pause, results)
scripts/autoload/   GameState (score/combo/lives/ammo), HighScores (user://highscores.cfg)
scripts/            Scripts mirroring the scenes folders
assets/             Models, textures, audio, fonts (placeholders are primitive meshes for now)
```

### Adding a stage

Duplicate a file in `data/stages/`, change `id`, `display_name`, `rng_seed` and tuning, then add it to
`STAGES` in `scripts/autoload/game_state.gd`. The same seed always gives the same spawn pattern, so players can learn it.

### Adding a predator

Duplicate `scenes/actors/leopard.tscn`, swap the meshes, and tune the exported `Predator` values (speed, points,
`can_rush`, spawn offset). Then register it in `PREDATOR_SCENES` and `_pick_threat()` in `scripts/game/level.gd`.

## Git notes

- Commit the `.uid` files Godot generates next to scripts and scenes. Don't commit `.godot/` (it's ignored).
- Line endings are normalized to LF by `.gitattributes`.

> Note: the High Concept Document lists *Unity 6 + URP* as the engine. This project uses **Godot 4**, so update the document to match.
