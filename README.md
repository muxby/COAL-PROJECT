# Racing Car Game

Console racing game written in 32-bit x86 assembly (MASM) with the Irvine32 library.
COAL Final Project, Fall 2026.

You race four computer cars over 3 laps in each of two levels. Level 1 is a wide grassy
track, Level 2 is a narrow desert track where the opponents change lanes.

## Files

| File | Purpose |
|---|---|
| `RacingCar.asm` | The complete game (single source file) |
| `RacingCar.sln`, `RacingCar.vcxproj` | Visual Studio solution (x86 / Win32, MASM) |
| `build615.bat` | Build script for MASM 6.15 |
| `StarterCode.asm` | Starter file given with the project |
| `highscore.dat` | Created by the game: highest score and the name of its holder |

## Build and run

The console window must be **120 x 30** characters (the Visual Studio default).

**Visual Studio**

1. Install the Irvine32 library in `C:\Irvine` (or change `IrvineDir` in `RacingCar.vcxproj`).
2. Open `RacingCar.sln`, choose the `x86` platform and press `Ctrl+F5`.
3. If Visual Studio asks to retarget the project to your toolset, accept.

**MASM 6.15**

Copy `RacingCar.asm` and `build615.bat` to a folder, run `build615.bat`, then run `RacingCar.exe`.
Edit `MASMDIR` at the top of the script if MASM is not in `C:\Masm615`.

## Controls

| Key | Action |
|---|---|
| `A` / `D` or Left / Right | Steer |
| `W` / `S` or Up / Down | Gear up / down (5 gears) |
| `SPACE` | Fire a nitro charge |
| `P` | Pause, `P` again to resume |
| `X` | Quit the race and return to the Start screen |
| `1` .. `5` | Menu options on the Start, Pause and Result screens |

## Scoring

| Event | Score |
|---|---|
| Coin | +10 |
| Lap completed | +50 |
| Hitting an opponent car | -15 |
| Hitting a barrier | -10 |
| Touching the track boundary | -5 |
| Finishing 1st / 2nd / 3rd / 4th / 5th | +200 / +150 / +100 / +50 / 0 |

The score never goes below zero. A hit also slows the car for 2 seconds.

## Features

- Six screens: Start, Instructions, Name, Game, Pause, Result
- Scrolling track with a 3-2-1 countdown, HUD (name, level, lap, score, time, best, position)
- Side panel with gear gauge, car status, lap progress bar and live standings
- Coins, barriers and speed boosters placed at random every lap; opponents can take boosters
  and are slowed by barriers and boundaries too
- Level settings (track width, items, lane changing) are stored in a table, so both levels
  use the same race procedures
- Highest score saved to a file with Irvine32 file procedures
- Extras: difficulty setting, sound on/off, race timer, finish animation

## Creative extras

- **Nitro**: every 5 coins fill one nitro charge (max 3); `SPACE` fires it for 3 seconds of boost
- **Coin magnet** `(M)`: coins ahead of the car slide towards it for 6 seconds
- **Shield** `[S]`: absorbs the next crash with a car or a barrier
- **Oil spills** `~~~~`: no points lost, but the car skids sideways for a moment
- **Sliding barriers**: in Level 2 two barriers per lap move from kerb to kerb
- **Pick your car**: red, yellow or white, chosen after typing the name
- **Lap map**: a strip in the side panel with a coloured marker for all five cars
- **Race commentary**: messages for overtakes, lost places and the final lap
- **Animated Start screen**: a little car keeps driving under the menu

## How the drawing works

Each frame is built in a memory buffer and compared with the frame already on the screen.
Only the cells that changed are written to the console, so the picture does not flicker.
