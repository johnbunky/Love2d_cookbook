# RECIPES

> Drop-in solutions. Copy, paste, adjust one value, done.
> Full source in `src/systems/` and `src/characters/`.

---

## CHARACTER

```lua
local Character = require "src.characters.character"

local player = Character.new("man", startX)

-- every frame:
player.inputX   = -1 / 0 / 1      -- horizontal
player.inputY   = -1 / 0 / 1      -- depth (3/4 and iso only)
player.inputSit = love.keyboard.isDown("q")
player:update(dt, terrain)
player:drawSelf(camera)

-- jump (on keypress, not held):
if player.sm:is("idle") or player.sm:is("walk") then
    player.sm:enter("jump")
end
```

**Profiles** (drop-in swap): `man` `woman` `child` `troll` `thief` `cat` `duck` `spider`

**What you get for free:** IK legs, procedural stepping, walk/run blend,
jump/fall/land/sit states, spring physics, near/far depth sorting, 3 projections.

---

## CAMERA

```lua
local Camera3D = require "src.systems.camera3d"

local camera = Camera3D.new(worldW, love.graphics.getHeight())

-- every frame:
camera:follow(player.pos.x, player.pos.y, player.pos.z, dt)

-- in draw:
local sx, sy = camera:toScreen(worldX, worldY, worldZ)

-- cycle views (sidescroll → 3/4 → isometric):
camera:nextView()
camera:snapTo(player.pos.x, player.pos.y, player.pos.z)

-- current view name:
camera.view   -- "sidescroll" | "threequarter" | "isometric"
```

---

## TERRAIN

```lua
local Grid     = require "src.systems.grid"
local GridMesh = require "src.characters.grid_mesh"

local g = Grid.new({
    x0=0, y0=-250, cols=30, rows=10,
    cell_w=80, cell_h=50,
    height_amp=50, jitter=0.28, seed=137,
})
local mesh = GridMesh.new(g, { show_edges=true })

-- terrain adapter (pass this to player:update):
local terrain = {
    worldW  = WORLD_W,
    worldD  = WORLD_D,
    floorAt = function(self, x, y) return g:floorAt(x, y) end,
}

-- in draw (before characters):
mesh:draw(camera)
```

**Flat terrain** (no grid, quick prototype):
```lua
local terrain = {
    worldW=2400, worldD=300,
    floorAt = function(self, x, y) return 0 end,
}
```

---

## AUTOMATA

```lua
local Automata = require "src.systems.automata"

local g = Automata.new(120, 80)
g.wrap = true           -- false for cave/fire, true for Conway/maze
g:fill(0.45)            -- random seed at 45% density
g:step(Automata.rules.cave)   -- advance one generation
-- read: g.cells[y][x]  (0 = dead / empty)

-- built-in rules:
--   conway   B3/S23          classic Game of Life
--   cave     B5678/S45678    smooth cave walls — run ~5 steps then stop
--   maze     B3/S12345       long corridor tendrils from sparse seeds
--   coral    B3/S45678       slow outward growth, like lichen
--   seeds    B2/S            every cell lives exactly one generation
--   fire     custom          multi-state 0-255 heat, rises with decay

-- custom rule from Golly notation:
g:step(Automata.parseBS("B36/S23"))

-- manual cell edits (mouse painting, spawning entities, etc.):
g:set(cx, cy, 1)
local v = g:get(x, y)   -- safe read, respects g.wrap
```

**Cave dungeon recipe** — produces a ready-to-use tilemap in ~5 steps:
```lua
local g = Automata.new(80, 50)
g.wrap = false
g:fill(0.47)
for i = 1, 5 do g:step(Automata.rules.cave) end
-- g.cells[y][x] is now your tilemap: 1 = wall, 0 = floor
```

---

## SPRING

```lua
local Spring = require "src.systems.spring"

local s = Spring.new(0)           -- initial value
s:update(dt, target, stiffness, damping)
-- read: s.value

-- tuning:
--   stiffness 8-10  damping 6    → floaty, some overshoot
--   stiffness 14    damping 9    → medium, natural
--   stiffness 30    damping 18   → snappy, almost no bounce
```

---

## STATE MACHINE

```lua
local StateMachine = require "src.systems.statemachine"

local sm = StateMachine.new(entity)
sm:add("idle", require "src.characters.states.idle")
sm:add("walk", require "src.characters.states.walk")
sm:enter("idle")

sm:update(dt)       -- auto-transitions when state returns next name
sm:draw(camera)     -- forwards extra args to state.draw
sm:is("idle")       -- current state check
```

**State table interface** (all optional):
```lua
{ enter(e), exit(e), update(e,dt) → "nextstate"|nil, draw(e,...) }
```

---

## IK

```lua
local IK = require "src.systems.ik"

-- 2-bone (leg, arm):
local kx, ky = IK.solve2(hx,hy, fx,fy, upperLen, lowerLen, dir)
-- dir: 1=knee forward, -1=knee backward (birds)

-- 3D pole-vector leg:
local kx,ky,kz = IK.solveLeg(hx,hy,hz, fx,fy,fz, ul,ll, poleX,poleY)

-- FK chain (tail, spine):
local pts = IK.fkChain(rx, ry, { {angle=a, length=l}, ... })
```

---

## STEPPER

```lua
local Stepper = require "src.systems.stepper"

local s = Stepper.new(rig, profile)
s:reset(hipX, hipY, floorZ)
s:update(dt, hipX,hipY,hipZ, velX,velY, floorZ, active, hipRefs)
-- read: s.feet[i].x / .y / .z

-- optional terrain tracking:
s.terrain = { floorAt = function(self,x,y) return z end }
```

---

## DRAW2D

Reusable screen-space drawing primitives. No skeleton knowledge — useful for
characters, props, trees, UI, terrain features, anything.

```lua
local Draw = require "src.systems.draw2d"

-- project a world bone to screen first:
local sx, sy = camera:toScreen(bone.x, bone.y, bone.z)
```

| Function | Description | Common uses |
|---|---|---|
| `Draw.capsule(x1,y1,r1, x2,y2,r2)` | Filled tapered oval | Limbs, branches, rope |
| `Draw.ocapsule(x1,y1,r1, x2,y2,r2, fill, outline)` | Outlined capsule | Character limbs |
| `Draw.plate(x1,y1, x2,y2, w)` | Filled rectangle segment | Robot parts, planks |
| `Draw.oplate(x1,y1, x2,y2, w, fill, outline)` | Outlined plate | Robot limbs |
| `Draw.ocirc(x,y,r, fill, outline)` | Outlined circle | Joints, eyes, buttons |
| `Draw.ball(x,y,r, fill, outline)` | Shaded sphere illusion | Heads, fruit, planets |
| `Draw.bolt(x,y,r, col)` | Rivet with specular dot | Robot joints, screws |
| `Draw.ohex(x,y,r, fill, outline)` | Outlined hexagon | Robot head, tiles |
| `Draw.opolygon(verts, fill, outline)` | Outlined filled polygon | Custom shapes |
| `Draw.safe(x,y)` | Returns false if coord is NaN or > 5000px | Guard before draw |

**Note:** Use `Draw.plate` / `Draw.oplate` instead of hand-rolled quads for
rectangular segments — LÖVE's polygon triangulator produces degenerate triangles
on short or near-vertical segments. `push/rotate/rectangle` is immune.

---

## SKINS

A skin decides how a character's skeleton is drawn.
The skeleton (IK legs, FK arms, near/far sorting) is always the same.
Only the visual output changes.

```lua
-- single skin:
skin = "soft"    -- "wire" | "soft" | "robot"  (default: "wire")

-- layered stack (Option B) — skins draw in order, each on top of the last:
skins = {
    "soft",
    { name = "particles", blend = "add",   alpha = 0.6 },
    { name = "wire",      blend = "alpha", alpha = 0.3 },
}
-- blend: "alpha"(default) | "add" | "multiply" | "subtract"
-- alpha: master opacity 0-1 (default 1)
```

The skin stack is lazy-loaded and cached on the character instance —
no `require` overhead after the first frame.

---

### Built-in skins

**`wire`** — line skeleton, default. No profile setup needed.

**`soft`** — outlined capsule body.

```lua
skin  = "soft",
color = { 0.91, 0.76, 0.62 },   -- base color

-- optional:
outline_color = { 0.3, 0.2, 0.15, 1 },
far_darken    = 0.50,            -- 0 = no dimming, 1 = black

widths = {
    -- screen pixels, proportional to rig by default
    leg_top = 10,  leg_bot = 7,  foot      = 5,
    arm_top =  8,  arm_bot = 6,  hand      = 4,
    torso_top = 18,              torso_bot = 14,
},
```

**`robot`** — rectangular plates, hexagon head, bolts at joints.

```lua
skin  = "robot",
color = { 0.78, 0.82, 0.88 },   -- metal tone

-- optional:
outline_color = { 0.10, 0.10, 0.12, 1 },
far_darken    = 0.45,

widths = { },   -- same keys as soft

robot = {
    joint_size  = 3.5,
    joint_color = { 0.75, 0.78, 0.82, 1 },
},
```

**`particles`** — emits particles from bone positions each frame.

```lua
skin  = "particles",
color = { 1, 0.6, 0.2 },   -- base particle color

particles = {
    count      = 1,     -- particles emitted per bone per frame
    lifetime   = 0.45,  -- seconds
    speed      = 18,    -- px/s
    r          = 3.5,   -- initial radius px
    gravity    = 30,    -- downward pull px/s²
    emit_bones = { "near_hand", "far_hand", "near_foot", "far_foot" },

    -- bridge to your existing emitter system (optional):
    -- emitter = emitters.sparks   -- skin calls emitter.spawn(sx,sy) each frame
},
```

---

### Secondary motion

Spring-driven body parts that react to physics automatically.
Add a `secondary` table to any profile to enable:

```lua
secondary = {
    breast = {
        fwd        = 12,    -- forward offset from chest center (px)
        r          = 7,     -- draw radius in soft skin (px)
        follow     = 0.10,  -- vel.z multiplier → spring target
        stiffness  = 14,    -- spring stiffness
        damping    = 6,     -- spring damping
    },
},
```

Springs are ticked automatically in `character:update()` — no extra wiring needed.
The skin reads the result from the bones table (`bones.breast_l`, `bones.breast_r`).
Only drawn when the skin supports it (`soft` does, `wire` and `robot` don't).

**Tuning guide:**
```
follow 0.05   → subtle, barely noticeable
follow 0.10   → natural, reacts clearly to jumps and landings
follow 0.20   → exaggerated, cartoon physics

stiffness 14  damping 6   → bouncy, some overshoot (good for secondary)
stiffness 20  damping 12  → snappier, less bounce
```

---

### Skin interface

Every skin is a module with one required function:

```lua
-- Skin.draw(bones, rig, profile, camera, c)
function MySkin.draw(bones, rig, profile, camera, _c)
    local sx, sy = camera:toScreen(bone.x, bone.y, bone.z)
    -- draw with love.graphics.* or Draw2d
end
```

Stateful skins (e.g. particles) also declare:

```lua
-- called automatically before draw() each frame
function MySkin.update(bones, rig, profile, dt, c)
    -- store state in c.skin_state = {}
end
```

**Bones table** — all world-space `{x,y,z}`, project with `camera:toScreen`:

```
spine:       hip  chest  head
near arm:    near_shoulder  near_elbow  near_hand
far arm:     far_shoulder   far_elbow   far_hand
near leg:    near_hip  near_knee  near_foot
far leg:     far_hip   far_knee   far_foot
bars:        hip_left  hip_right  shoulder_left  shoulder_right
orientation: facing (1/-1)   left_near (bool)

secondary (present only when profile.secondary defines them):
             breast_l  breast_r  ponytail  belly
```

**Rules:**
- Always set your own color before every draw call — never assume previous state
- Draw order: far limbs → torso → near limbs → secondary → head
- Use `Draw.safe(sx,sy)` to guard projections before drawing
- Use `Draw.plate` not hand-rolled polygons for rectangular segments

**Debug overlay:** hold **R** in `robot` skin for a full bone console.
Copy `draw_debug()` from `robot.lua` into any skin.

---

### Writing a new skin

```lua
local MySkin = {}
local Draw = require "src.systems.draw2d"

local function proj(b, cam) return cam:toScreen(b.x, b.y, b.z) end

function MySkin.draw(bones, rig, profile, camera, _c)
    local col = profile.color
    local far = profile.far_darken or 0.5
    local fill    = { col[1],     col[2],     col[3],     1    }
    local outline = { col[1]*0.3, col[2]*0.3, col[3]*0.3, 1    }
    local far_fill = { col[1]*far, col[2]*far, col[3]*far, 0.85 }

    -- far layer
    local function limb(a, b, r1, r2, f, o)
        local ax,ay = proj(a, camera);  local bx,by = proj(b, camera)
        Draw.ocapsule(ax,ay,r1, bx,by,r2, f, o)
    end
    limb(bones.far_shoulder, bones.far_elbow, 5, 4, far_fill, outline)
    -- ... other far limbs ...

    -- torso, near limbs, head ...
    Draw.ball(proj(bones.head, camera), rig.head_r or 17, fill, outline)
end

return MySkin
```

---

## PHYSICS (3D z-up)

```lua
local Physics = require "src.systems.physics3d"

-- entity needs: pos{x,y,z}, vel{x,y,z}, inputX, inputY,
--               groundZ, onGround, profile{accel,drag,max_vx,jump_vy}

Physics.update(entity, dt)   -- gravity, input, ground collision
Physics.jump(entity)         -- upward impulse
```

---

## FULL MINIMAL DEMO

```lua
-- the working reference: src/states/examples/character_basics.lua
-- character + terrain + camera3d + all 3 views + 8 profiles
-- copy it as a starting point for anything new
```

---

## KNOWN ROUGH EDGES

- Hip sway animation missing on humanoid (walk.lua has the data, draw doesn't use it yet)
- Quadruped/bird/spider not tested in cookbook context yet
- Trees not ported from characters project
- No 2D camera / character bridge (for sidescroll platformer style)
- `src/states/examples/` — most examples are sketches, not recipes yet
- Ponytail and belly secondary motion: architecture designed, not yet implemented

---

## WORLD AXES

```
x = left / right
y = depth (into screen)
z = height (up)   ← gravity pulls z down
```
