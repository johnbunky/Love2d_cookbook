# LOVE2D Game Development Cookbook

A comprehensive, interactive reference for LOVE2D game development. Every system and pattern a 2D game needs — built from scratch, fully documented, and runnable as live examples.

---

## What This Is

This is not a game — it is a **living cookbook**. Each menu item launches a self-contained, interactive example that demonstrates a specific system or technique. The goal is to have a single project you can open to answer the question *"how do I do X in LOVE2D?"* — and see it working immediately.

---

## Requirements

- [LOVE2D](https://love2d.org/) 11.4 or newer
- Windows, macOS, Linux, Android, or iOS

---

## Running

```bash
# From the project root
love .

# Or drag the folder onto the LOVE2D executable
# Or package as .love file:
zip -r cookbook.love . -x "*.git*"
```

---

## Project Structure

```
.
├── conf.lua                  # LOVE2D configuration
├── main.lua                  # Entry point, routes all LOVE callbacks
├── assets/
│   ├── fonts/
│   ├── images/
│   └── sounds/
└── src/
    ├── utils.lua             # Shared helpers (clamp, lerp, distance...)
    ├── input.lua             # Unified input (keyboard, mouse, touch, gamepad)
    ├── assets.lua            # Asset loader with caching
    ├── gamestate.lua         # State machine (switch, resume, event routing)
    ├── class.lua             # Simple OOP base class
    ├── systems/              # Reusable, engine-agnostic systems
    └── states/
        ├── menu.lua          # Main navigation menu
        ├── pause.lua         # Pause overlay
        ├── gameover.lua      # Game over screen
        └── examples/         # One file per example
```

---

## Systems (`src/systems/`)

Reusable modules with clean APIs. Most are LOVE-free and portable to other engines.

### Math
| System | Description |
|--------|-------------|
| `vec3.lua` | 3D vector math — add, sub, dot, cross, normalize, length |
| `mat4.lua` | 4x4 matrix math — multiply, translate, rotate, scale, perspective, lookAt |

### Core
| System | Description |
|--------|-------------|
| `camera.lua` | Smooth follow, world bounds, zoom, snap, screen-to-world, visible tile range |
| `physics.lua` | AABB resolution, velocity, gravity, friction, grounding |
| `tilemap.lua` | Tile loading, rendering, collision queries, layer support |
| `collision.lua` | rectRect, circleCircle, circleRect, MTV, sweep, broad phase — zero LOVE |
| `pathfinding.lua` | A* on grid, diagonal movement, wall-cut prevention, path smoothing — zero LOVE |

### Gameplay
| System | Description |
|--------|-------------|
| `timer.lua` | after, every, tween, cancel — no globals needed |
| `health.lua` | HP, damage, healing, invincibility frames, death callbacks |
| `particles.lua` | Particle emitter with pool, per-particle spawn/update/draw callbacks |
| `anim.lua` | Frame animation, quad atlas, playback control, callbacks on loop |
| `shake.lua` | Trauma-based screen shake with decay |

### UI / Narrative
| System | Description |
|--------|-------------|
| `hud.lua` | Health bars, stamina bars, minimap, crosshair, floating labels |
| `dialog.lua` | Conversation trees, speaker portraits, choices, callbacks |
| `inventory.lua` | Item slots, stacking, equipment slots, drag-and-drop |
| `transition.lua` | Screen transitions — fade, wipe, circle, pixelate, blur |

### World
| System | Description |
|--------|-------------|
| `daycycle.lua` | Time of day, color keyframes, callbacks at dawn/noon/dusk/midnight |
| `lighting.lua` | 2D point lights, ambient, attenuation, colored light |
| `postfx.lua` | Canvas shader chain — bloom, chromatic aberration, vignette, CRT |

### Input
| System | Description |
|--------|-------------|
| `vjoystick.lua` | Virtual joystick — floating origin, deadzone, multi-touch ID tracking — zero LOVE |

### Persistence
| System | Description |
|--------|-------------|
| `serializer.lua` | Pure Lua table serialize/deserialize — zero LOVE |
| `savemanager.lua` | Slot-based save/load using love.filesystem + Serializer |
| `leaderboard.lua` | Sorted score board, max entries, persist to file |
| `settings.lua` | Schema-driven settings — toggle, slider, enum — load/save/reset |

---

## Examples (`src/states/examples/`)

### Core (6)
| Example | Key Concepts |
|---------|-------------|
| `topdown_movement` | 8-direction movement, speed, friction, wall collision |
| `platformer_movement` | Gravity, jump, coyote time, wall-slide |
| `camera` | Smooth follow, zoom, pinch-to-zoom, mouse wheel, bounds |
| `tilemap` | Tile rendering, collision layers, camera integration |
| `collision_demo` | Interactive rect/circle drag — all collision types visualized |
| `platformer_level` | Full platformer with tilemap, camera, checkpoints, moving platforms |

### Polish (4)
| Example | Key Concepts |
|---------|-------------|
| `animation` | Sprite atlas, frame sequences, blend modes, callbacks |
| `screen_shake` | Trauma system, multiple shake sources, decay |
| `transitions` | 6 transition types — fade, wipe, circle, pixelate, blur, slide |
| `hud` | Health bars, stamina, minimap, crosshair, floating damage numbers |

### Combat (6)
| Example | Key Concepts |
|---------|-------------|
| `shooter` | Projectile pooling, spread, homing, piercing, enemy waves |
| `melee_attack` | Hitbox, swing arc, combo counter, knockback, iframes |
| `enemy_ai` | State machine — idle, patrol, chase, attack — LOS detection |
| `pathfinding` | A* on grid, path smoothing, dynamic obstacle toggling |
| `health_damage` | Damage types, armor, invincibility, death, respawn |
| `particles` | 8 emitter types — fire, smoke, sparks, snow, explosion, magic |

### UI (3)
| Example | Key Concepts |
|---------|-------------|
| `nav_menu` | Scrollable menu, keyboard/mouse/touch/gamepad navigation |
| `inventory` | Grid inventory, drag-and-drop, equipment slots, stacking |
| `dialog` | Multi-speaker dialog, choices, branching, typewriter effect |

### Visual (8)
| Example | Key Concepts |
|---------|-------------|
| `parallax` | Multi-layer scrolling, drag to pan, speed ratios |
| `day_night` | Day/night cycle, sun/moon arc, sky gradient, stars |
| `lighting` | Dynamic 2D point lights, shadows, colored ambient |
| `shaders` | GLSL pixel shaders — wave, CRT, outline, grayscale |
| `post_fx` | Full-screen shader chain — bloom, aberration, vignette |
| `basics_3d` | 3D cube in LOVE2D — mat4/vec3, perspective, rotation |
| `billboards` | Sprite billboards with depth sort, shadows, procedural sprites |
| `iso_topdown` | Isometric map, raised platforms, depth sorting, jump physics |

### Audio (2)
| Example | Key Concepts |
|---------|-------------|
| `audio_demo` | 9 procedurally generated sounds — no audio files needed |
| `volume_control` | 5-channel mixer, pitch control, spatial audio (3D positioning) |

### Input (3)
| Example | Key Concepts |
|---------|-------------|
| `keyboard_mouse` | Key events, held keys, mouse trail, click ripples, wheel |
| `gamepad_demo` | Gamepad detection, all axes/buttons, hot-plug, raw fallback |
| `virtual_joystick` | Floating stick, multi-touch buttons, keyboard fallback |

### Data (3)
| Example | Key Concepts |
|---------|-------------|
| `save_load` | 3 save slots, serialize/deserialize, file timestamps |
| `high_score` | Persistent leaderboard, mini dodge game, name entry |
| `settings_persist` | Schema-driven settings, categories, live apply, reset to defaults |

---

## Controls (all examples)

| Input | Action |
|-------|--------|
| `ESC` | Back to menu |
| `P` | Pause |
| `UP / DOWN` | Navigate lists |
| `ENTER / SPACE` | Confirm |
| Mouse / Touch | Click or tap items |
| Gamepad | D-pad navigate, A confirm |

---

## Architecture

### State Machine

All screens are states. Switching is one call:

```lua
Gamestate.switch(States.my_example)
```

Every state can implement any of:

```lua
state.enter()
state.exit()
state.update(dt)
state.draw()
state.keypressed(key)
state.keyreleased(key)
state.mousepressed(x, y, button)
state.mousemoved(x, y, dx, dy)
state.mousereleased(x, y, button)
state.touchpressed(id, x, y)
state.touchmoved(id, x, y)
state.touchreleased(id, x, y)
state.wheelmoved(x, y)
state.gamepadpressed(joystick, button)
state.joystickadded(joystick)
state.joystickremoved(joystick)
state.textinput(text)
```

### Using a System

```lua
-- Timer
local Timer = require("src.systems.timer")
local t = Timer.new()
Timer.after(t, 2.0, function() print("2 seconds later") end)
Timer.every(t, 0.5, function() print("every half second") end)
-- In update:
Timer.update(t, dt)

-- Camera
local Camera = require("src.systems.camera")
local cam = Camera.new(worldW, worldH, screenW, screenH)
-- In update:
Camera.follow(cam, player, dt)
-- In draw:
Camera.apply(cam)
  -- draw world here
Camera.clear()

-- Pathfinding
local PF = require("src.systems.pathfinding")
local pf = PF.new(cols, rows, tileSize)
pf:setGrid(flatGrid)  -- 0=walkable, 1=wall
local path   = pf:find(startCol, startRow, goalCol, goalRow)
local smooth = pf:smooth(path)

-- Save / Load
local SM = require("src.systems.savemanager")
SM.setup("saves/", 3)
SM.save(1, { level=5, gold=120, name="Hero" })
local data = SM.load(1)

-- Virtual Joystick
local VJoystick = require("src.systems.vjoystick")
local vj = VJoystick.new({ radius=70, deadzone=0.12 })
-- In touchpressed:
vj:activate(x, y, touchId)
-- In touchmoved:
vj:move(x, y, touchId)
-- In touchreleased:
vj:release(touchId)
-- In update:
local ax, ay = vj:axes()
```

---

## Adding a New Example

1. Create `src/states/examples/my_example.lua`:

```lua
local Utils   = require("src.utils")
local Timer   = require("src.systems.timer")
local Example = {}

local W, H
local timer

function Example.enter()
    W, H  = love.graphics.getWidth(), love.graphics.getHeight()
    timer = Timer.new()
end

function Example.exit()
    Timer.clear(timer)
end

function Example.update(dt)
    Timer.update(timer, dt)
end

function Example.draw()
    -- your drawing here
    Utils.drawHUD("MY EXAMPLE", "controls hint    ESC back")
end

function Example.keypressed(key)
    Utils.handlePause(key, Example)
end

return Example
```

2. Require it in `main.lua`:

```lua
local MyExample = require("src.states.examples.my_example")
```

3. Register it in the States table:

```lua
States = {
    ...
    my_example = MyExample,
}
```

4. Add it to the menu in `src/states/menu.lua`:

```lua
{ label = "My Example", state = "my_example" },
```

---

## Known Issues / Tech Debt

- **Isometric depth sorting** — player sprite can be occluded by tiles at certain positions (painter's algorithm limitation with 3D geometry)
- **Nav menu hover** — mouse hover highlight not implemented
- **Gamepad sliders** — no repeat-on-hold for held D-pad
- **UTF-8 helpers** — `utf8len` / `utf8sub` not yet in `utils.lua`
- **Window scaling** — UI uses fixed coordinates; needs virtual resolution system for multi-resolution support
- **love.physics** — Box2D bindings (joints, constraints, rigid bodies) not yet covered
- **love.video** — `.ogv` video playback not yet covered

---

## License

MIT — use freely in your own projects.
