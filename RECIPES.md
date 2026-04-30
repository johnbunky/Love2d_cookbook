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

---

## WORLD AXES

```
x = left / right
y = depth (into screen)
z = height (up)   ← gravity pulls z down
```
