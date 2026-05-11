# RECIPES

> Drop-in solutions. Copy, paste, adjust one value, done.
> Full source in `src/systems/` and `src/characters/`.

---

## TWEEN

```lua
local Tween = require "src.systems.tween"

local t = Tween.new(0, 1, 0.5, "quad_out")
t:update(dt)
-- read: t.value   check: t.done

-- easings: linear, quad_in/out/inout, cubic_in/out/inout,
--          back_out, elastic_out, bounce_out

-- change target mid-flight (UI hover, health drain):
t:retarget(newTarget, duration)
```

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

## CHAIN

Verlet chain solver. Useful for ponytails, tails, scarves, ropes, tentacles —
anything that's a sequence of connected points with physics.

```lua
local Chain = require "src.systems.chain"

local c = Chain.new({
    segs      = 5,      -- number of segments (points = segs + 1)
    seg_len   = 10,     -- rest length per segment (world units)
    gravity   = 280,    -- downward pull per second
    damping   = 0.982,  -- velocity multiplier per frame
    stiffness = 0.35,   -- angular stiffness: 0=rope, 0.35=hair, 0.8=rod
    iters     = 3,      -- constraint iterations (more = stiffer)
})

Chain.reset(c, rootX, rootY, rootZ)   -- snap straight down, zero velocity

-- every frame — colliders prevent clipping through body:
local colliders = {
    { x=hipX, y=hipY, z=pelvisZ, r=12 },
    { x=hipX, y=hipY, z=chestZ,  r=16 },
}
Chain.update(c, dt, rootX, rootY, rootZ, colliders)

-- read points (1=root, #c.pts=tip):
for i, pt in ipairs(c.pts) do
    local sx, sy = camera:toScreen(pt.x, pt.y, pt.z)
end
```

**Tuning:**
```
stiffness 0.0  → pure rope    damping 0.982 → floaty
stiffness 0.35 → hair         damping 0.96  → settles in ~1s
stiffness 0.8  → stiff braid  damping 0.90  → snappy
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

-- project a world point to screen first:
local sx, sy = camera:toScreen(wx, wy, wz)
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

**Note:** Use `Draw.plate` / `Draw.oplate` instead of hand-rolled quads —
LÖVE's polygon triangulator produces degenerate triangles on short or near-vertical
segments. `push/rotate/rectangle` is immune.

---

## SKINS

A skin decides how a character's skeleton is drawn.
The skeleton (IK legs, FK arms, near/far sorting) is always the same.

```lua
-- single skin:
skin = "soft"    -- "wire"|"soft"|"robot"|"toon"|"sketch"|"ghost"  (default: "wire")

-- layered stack — draws in order, each on top of the last:
skins = {
    "soft",
    "face",
    { name = "particles", blend = "add",   alpha = 0.6 },
    { name = "ghost",     blend = "add",   alpha = 0.4 },
    { name = "wire",      blend = "alpha", alpha = 0.3 },
}
-- blend: "alpha"(default) | "add" | "multiply" | "subtract"
-- alpha: master opacity 0-1 (default 1)
```

Stack is lazy-loaded and cached. Multiple stateful skins coexist safely —
each owns `c.skin_state.<skinname>`.

---

### Built-in skins

**`wire`** — line skeleton, default. No setup needed.

**`soft`** — outlined capsule body.
```lua
skin  = "soft",
color = { 0.91, 0.76, 0.62 },
outline_color = { 0.3, 0.2, 0.15, 1 },
far_darken    = 0.50,
widths = { leg_top=10, leg_bot=7, foot=5, arm_top=8, arm_bot=6, hand=4,
           torso_top=18, torso_bot=14 },
```

**`robot`** — rectangular plates, hexagon head, bolts.
```lua
skin  = "robot",
color = { 0.78, 0.82, 0.88 },
robot = { joint_size=3.5, joint_color={0.75,0.78,0.82,1} },
```

**`toon`** — flat color, thick outline, no shading.
```lua
skin  = "toon",
color = { 0.40, 0.70, 0.95 },
toon  = { outline_w=5 },
```

**`sketch`** — outline only, no fill. Ink style. Pair with `face`.
```lua
skins = { "sketch", "face" },
color = { 0.08, 0.06, 0.05 },
sketch = { near_w=2.5, far_w=1.2, far_alpha=0.38 },
```

**`ghost`** — soft glow, no outline. Spirit / energy style.
```lua
-- standalone:
skin  = "ghost",
color = { 0.55, 0.80, 1.0 },
ghost = { alpha=0.55, core_alpha=0.30, glow_scale=1.5 },

-- aura over soft body:
skins = { "soft", { name="ghost", blend="add", alpha=0.4 } },
```

**`particles`** — emits particles from bone positions.
```lua
skin  = "particles",
color = { 1, 0.6, 0.2 },
particles = {
    count=1, lifetime=0.45, speed=18, r=3.5, gravity=30,
    emit_bones = { "near_hand", "far_hand", "near_foot", "far_foot" },
    -- emitter = emitters.sparks   -- bridge to your existing emitter system
},
```

**`face`** — expressive face layer. Always place last in the stack.
Reacts to state automatically (idle/walk/jump/fall/land/sit).
Face features are placed in world space — works in all three projections.
```lua
skins = { "soft", "face" },
face = {
    fwd    = 9,    -- face plane distance in front of head (world units)
    spread = 6,    -- half eye separation
    rise   = 3,    -- eye height above head center
},
```

---

### Secondary motion

Spring and chain-driven body parts. Tick automatically in `character:update()`.

```lua
secondary = {
    breast = {
        fwd       = 12,    -- forward offset from chest (px)
        r         = 7,     -- draw radius in soft skin
        follow    = 0.10,  -- vel.z multiplier → spring target
        stiffness = 8,
        damping   = 5,
    },
    ponytail = {
        segs      = 5,
        seg_len   = 10,    -- world units
        back      = 6,     -- root behind head
        r         = 4,     -- draw radius at root
        gravity   = 180,
        damping   = 0.96,
        stiffness = 0.35,
    },
},
```

Bones appear in the table only when defined. `soft` draws breast + ponytail.
Body collision spheres for ponytail are computed automatically from rig dimensions.

---

### Skin interface

```lua
-- required:
function MySkin.draw(bones, rig, profile, camera, c) end

-- optional — stateful skins only:
function MySkin.update(bones, rig, profile, dt, c)
    if not c.skin_state         then c.skin_state         = {} end
    if not c.skin_state.myskin  then c.skin_state.myskin  = {} end
    local s = c.skin_state.myskin
end
```

**Bones** — world-space `{x,y,z}`, project with `camera:toScreen`:
```
spine:       hip  chest  head
near arm:    near_shoulder  near_elbow  near_hand
far arm:     far_shoulder   far_elbow   far_hand
near leg:    near_hip  near_knee  near_foot
far leg:     far_hip   far_knee   far_foot
bars:        hip_left  hip_right  shoulder_left  shoulder_right
orientation: facing(1/-1)  left_near(bool)
secondary:   breast_l  breast_r  ponytail  belly  (when defined)
```

**Rules:**
- Always set your own color before every draw call
- Draw order: far → torso → near → secondary → head
- Use `Draw.safe(sx,sy)` to guard projections
- Use `Draw.plate` not hand-rolled polygons for rectangular segments
- Namespace state: `c.skin_state.<skinname>`

**Debug:** hold **R** in `robot` skin — full bone console, world+screen coords.

---

### Minimal new skin template

```lua
local MySkin = {}
local Draw = require "src.systems.draw2d"
local function proj(b, cam) return cam:toScreen(b.x, b.y, b.z) end

function MySkin.draw(bones, rig, profile, camera, _c)
    local col     = profile.color
    local far     = profile.far_darken or 0.5
    local fill    = {col[1],     col[2],     col[3],     1   }
    local outline = {col[1]*0.3, col[2]*0.3, col[3]*0.3, 1   }
    local ffill   = {col[1]*far, col[2]*far, col[3]*far, 0.85}

    local function limb(a, b, r1, r2, f, o)
        local ax,ay = proj(a,camera); local bx,by = proj(b,camera)
        Draw.ocapsule(ax,ay,r1, bx,by,r2, f, o)
    end

    limb(bones.far_shoulder,  bones.far_elbow,  5,4, ffill, outline)
    limb(bones.far_elbow,     bones.far_hand,   4,3, ffill, outline)
    limb(bones.far_hip,       bones.far_knee,   7,5, ffill, outline)
    limb(bones.far_knee,      bones.far_foot,   5,3, ffill, outline)
    limb(bones.hip,           bones.chest,     14,16, fill, outline)
    limb(bones.near_hip,      bones.near_knee,  7,5,  fill, outline)
    limb(bones.near_knee,     bones.near_foot,  5,3,  fill, outline)
    limb(bones.near_shoulder, bones.near_elbow, 5,4,  fill, outline)
    limb(bones.near_elbow,    bones.near_hand,  4,3,  fill, outline)

    local hdx,hdy = proj(bones.head, camera)
    Draw.ball(hdx, hdy, rig.head_r or 17, fill, outline)
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

- Quadruped/bird/spider profiles not tested in cookbook context yet
- Trees not ported from characters project
- No 2D camera / character bridge (for sidescroll platformer style)
- `src/states/examples/` — most examples are sketches, not recipes yet
- Belly secondary motion: architecture designed, not yet implemented
- Robot skin: degenerate triangle artifact in some edge cases (tracking open)

---

## WORLD AXES

```
x = left / right
y = depth (into screen)
z = height (up)   ← gravity pulls z down
```
