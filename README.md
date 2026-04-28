# LOVE2D Cookbook

A personal game-dev laboratory. Working examples you can run, inspect, and steal from.
Not a tutorial. Not a framework. A workbench.

> For quick code snippets see **[RECIPES.md](./RECIPES.md)**

---

## What This Is

An interactive browser of self-contained examples — each one demonstrates one mechanic,
runs immediately, and shows its source. When you need something, you open it, see it
working, copy the relevant part.

The deeper modules (`src/systems/`, `src/characters/`) follow a **Selenide philosophy**:
one require, one constructor, sensible defaults, full power underneath.
The examples show them in action.

---

## Requirements

- [LOVE2D](https://love2d.org/) 11.4 or newer
- Windows, macOS, Linux, Android, iOS

---

## Running

```bash
love .
# or drag the folder onto the LOVE2D executable
```

---

## Starting a Game

The fastest path from zero to something playable:

**1. Copy the character demo as your game state**
```bash
cp src/states/examples/character_basics.lua src/states/my_game.lua
```

**2. Register it in `main.lua`**
```lua
local MyGame = require("src.states.my_game")
-- in States table:
my_game = MyGame,
```

**3. Strip what you don't need, change what you do**
```lua
-- different character:
player = Character.new("spider", startX)

-- different terrain:
local g = Grid.new({ height_amp=80, seed=42 })

-- second character:
local partner = Character.new("man", startX + 200)
partner:update(dt, terrain)
partner:drawSelf(camera)
```

`character_basics.lua` already has character + terrain + camera + input wired correctly.
It's your blank canvas — subtract and extend from there.

For everything else, see **RECIPES.md**.

---

## Project Structure

```
├── main.lua                  entry point, routes LOVE callbacks
├── RECIPES.md                code snippets — the fast reference
├── src/
│   ├── utils.lua             shared helpers (clamp, lerp, drawHUD...)
│   ├── input.lua             unified input (keyboard, mouse, touch, gamepad)
│   ├── gamestate.lua         state machine (switch, resume, event routing)
│   ├── systems/              reusable building blocks (mostly LOVE-free)
│   ├── characters/           character library — the first full recipe
│   └── states/
│       ├── menu.lua
│       ├── pause.lua
│       ├── gameover.lua
│       └── examples/         one file per example
```

---

## Systems (`src/systems/`)

Reusable modules. Most have zero LOVE dependency and port cleanly to other engines.

### Characters & 3D World
| System | One-liner |
|--------|-----------|
| `camera3d.lua` | 3-projection camera (sidescroll / 3/4 / iso) with `toScreen(x,y,z)` |
| `physics3d.lua` | z-up gravity, acceleration, drag, ground collision |
| `ik.lua` | 2-bone IK, 3D pole-vector leg IK, FK chain |
| `stepper.lua` | Procedural foot placement with terrain tracking |
| `spring.lua` | Damped spring — drives any value toward a target with lag/overshoot |
| `statemachine.lua` | Generic FSM — add states, auto-transition on return value |
| `grid.lua` | Procedural terrain grid with barycentric height interpolation |

### 2D Core
| System | One-liner |
|--------|-----------|
| `camera.lua` | Smooth follow, zoom, bounds, screen-to-world |
| `physics.lua` | AABB collision, platformer physics, coyote time, jump buffer |
| `tilemap.lua` | Tile rendering, collision layers, camera integration |
| `collision.lua` | rect/circle collision, MTV, sweep — zero LOVE |
| `pathfinding.lua` | A* with smoothing — zero LOVE |

### Gameplay
| System | One-liner |
|--------|-----------|
| `timer.lua` | after, every, tween, cancel |
| `health.lua` | HP, damage, iframes, death callbacks |
| `particles.lua` | Pooled emitter with spawn/update/draw callbacks |
| `anim.lua` | Frame animation, quad atlas, loop callbacks |
| `shake.lua` | Trauma-based screen shake |

### UI / Narrative
| System | One-liner |
|--------|-----------|
| `hud.lua` | Health bars, minimap, floating labels |
| `dialog.lua` | Conversation trees, choices, typewriter |
| `inventory.lua` | Item slots, drag-and-drop, equipment |
| `transition.lua` | Fade, wipe, circle, pixelate, blur |

### World
| System | One-liner |
|--------|-----------|
| `daycycle.lua` | Time of day, color keyframes, dawn/dusk callbacks |
| `lighting.lua` | 2D point lights, ambient, attenuation |
| `postfx.lua` | Shader chain — bloom, aberration, vignette, CRT |

### Persistence
| System | One-liner |
|--------|-----------|
| `serializer.lua` | Pure Lua table serialize/deserialize |
| `savemanager.lua` | Slot-based save/load |
| `leaderboard.lua` | Sorted score board, persisted |
| `settings.lua` | Schema-driven settings — toggle, slider, enum |

---

## Character Library (`src/characters/`)

A full procedural character system — the cookbook's first complete recipe.

```lua
local Character = require "src.characters.character"
local player = Character.new("man", startX)   -- that's it
```

**Profiles:** `man` `woman` `child` `troll` `thief` `cat` `duck` `spider`

**Included:** IK legs, procedural stepping, walk/run/jump/fall/land/sit states,
spring physics, near/far depth sorting, 3-projection rendering.

See **RECIPES.md → CHARACTER** for full usage.

---

## Examples (`src/states/examples/`)

### Characters
| Example | Shows |
|---------|-------|
| `character_basics` | 8 characters, terrain, 3 projection views, all states |

### Core
| Example | Shows |
|---------|-------|
| `topdown_movement` | 8-direction movement, friction, wall collision |
| `platformer_movement` | Gravity, variable jump, coyote time, jump buffer |
| `camera` | Smooth follow, zoom, pinch, bounds |
| `tilemap` | Tile rendering, collision layers |
| `collision_demo` | All collision types, interactive |
| `platformer_level` | Full level — tilemap, camera, checkpoints |

### Polish
`animation` `screen_shake` `transitions` `hud`

### Combat
`shooter` `melee_attack` `enemy_ai` `pathfinding` `health_damage` `particles`

### UI
`nav_menu` `inventory` `dialog`

### Visual
`parallax` `day_night` `lighting` `shaders` `post_fx` `basics_3d` `billboards` `iso_topdown`

### Audio
`audio_demo` `volume_control`

### Input
`keyboard_mouse_demo` `gamepad_demo` `virtual_joystick`

### Data
`save_load` `high_score` `settings_persist`

---

## Adding an Example

**1.** Create `src/states/examples/my_example.lua`:

```lua
local Utils   = require "src.utils"
local Example = {}

function Example.enter()  end
function Example.exit()   end

function Example.update(dt)
end

function Example.draw()
    Utils.drawHUD("MY EXAMPLE", "controls hint    ESC back")
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button) end
function Example.touchpressed(id, x, y)     end
function Example.gamepadpressed(j, button)  end

return Example
```

**2.** In `main.lua`, add require at the top and entry in `States` table.

**3.** Add to the menu in `src/states/menu.lua`.

---

## Controls (all examples)

| Key | Action |
|-----|--------|
| `ESC` | Back to menu |
| `P` | Pause |
| `UP / DOWN` | Navigate lists |
| `ENTER / SPACE` | Confirm |

---

## Known Rough Edges

- Most examples in `src/states/examples/` are sketches — they work but aren't recipes yet
- Quadruped / bird / spider characters not fully tested in cookbook context
- Trees not ported from characters project
- Hip sway on humanoid present in walk data but not yet rendered
- No 2D ↔ character bridge (platformer-style characters)

---

## License

MIT
