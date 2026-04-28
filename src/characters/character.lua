-- src/characters/character.lua
-- World axes: x=left/right, y=depth, z=height (z-up)
--
-- Creates a character entity by combining:
--   profile  → physics/animation parameters (src/characters/profiles/)
--   rig      → body topology (src/characters/rigs/)
--   draw     → LÖVE rendering (src/characters/draw/)
--   states   → FSM behaviour (src/characters/states/)
--
-- USAGE:
--   local Character = require "src.characters.character"
--   local player = Character.new("man", startX)
--   -- each frame:
--   player.inputX  = <-1 / 0 / 1>   -- set before update
--   player.inputY  = <-1 / 0 / 1>   -- depth, only meaningful in 3/4 and iso
--   player.inputSit = <bool>          -- true when sit action is triggered
--   player:update(dt, terrain)
--   player:drawSelf(camera)
--
-- TERRAIN INTERFACE (optional):
--   terrain = {
--     worldW  = number,
--     worldD  = number,
--     floorAt = function(self, x, y) return z end,
--   }

local StateMachine = require "src.systems.statemachine"
local Stepper      = require "src.systems.stepper"
local Spring       = require "src.systems.spring"

local Character = {}

function Character.new(profileName, startX)
    local profile = require("src.characters.profiles." .. profileName)
    local rig     = require("src.characters.rigs."     .. profile.rig)
    local draw    = require("src.characters.draw."     .. profile.rig .. "_draw")

    -- leg length: quadrupeds use f_ul/f_ll, everything else uses ul/ll
    local b       = profile.body or {}
    local leg_len = (b.ul       and (b.ul    + b.ll))
                 or (rig.f_ul   and (rig.f_ul + rig.f_ll))
                 or (rig.ul     and (rig.ul   + rig.ll))
                 or 80   -- fallback

    local stance  = profile.stance_height or 1.0
    local FLOOR_Z = 0
    local groundZ = FLOOR_Z + leg_len * stance

    local c = {
        profileName = profileName,
        profile     = profile,
        rig         = rig,
        draw        = draw,
        leg_len     = leg_len,

        pos         = { x = startX or 400, y = 0, z = groundZ },
        vel         = { x = 0, y = 0, z = 0 },
        onGround    = true,
        facing      = 1,

        -- input fields — set by the demo/game each frame before calling :update()
        inputX      = 0,       -- -1 / 0 / 1  horizontal movement
        inputY      = 0,       -- -1 / 0 / 1  depth movement (3/4 & iso)
        inputSit    = false,   -- true while sit action is held

        groundZ     = groundZ,
        floorZ      = FLOOR_Z,

        walkPhase   = 0,
        swingAngle  = 0,
        breathTimer = 0,
        landImpact  = 0,
        lastDx      = 1,
        lastDy      = 0,
        last_dx     = 1,
        last_dy     = 0,

        dt          = 0,       -- stored by :update() for use in draw callbacks
    }

    c.springs = {
        arm      = Spring.new(0),
        sway     = Spring.new(0),
        lean     = Spring.new(0),
        bob      = Spring.new(0),
        breast_l = Spring.new(0),
        breast_r = Spring.new(0),
    }

    c.stepper         = Stepper.new(rig, profile)
    c.stepper:reset(c.pos.x, c.pos.y, FLOOR_Z)
    c.stepper.terrain = nil   -- set each frame in :update()

    c.sm = StateMachine.new(c)
    c.sm:add("idle", require "src.characters.states.idle")
    c.sm:add("walk", require "src.characters.states.walk")
    c.sm:add("jump", require "src.characters.states.jump")
    c.sm:add("fall", require "src.characters.states.fall")
    c.sm:add("land", require "src.characters.states.land")
    c.sm:add("sit",  require "src.characters.states.sit")
    c.sm:enter("idle")

    -- per-foot hip references for quadrupeds (front/rear hips differ)
    function c:quadHipRefs()
        if self.rig.feet ~= 4 then return nil end
        local vx2, vy2 = self.vel.x, self.vel.y
        local vl = math.sqrt(vx2*vx2 + vy2*vy2)
        local ddx = vl > 2 and vx2/vl or self.facing
        local ddy = vl > 2 and vy2/vl or 0
        local bl  = self.rig.body_len or 70
        local fhx = self.pos.x + ddx*bl
        local fhy = self.pos.y + ddy*bl
        return {
            [1] = { x=fhx, y=fhy }, [2] = { x=fhx, y=fhy },
            [3] = { x=self.pos.x, y=self.pos.y },
            [4] = { x=self.pos.x, y=self.pos.y },
        }
    end

    function c:update(dt, terrain)
        -- update floor/ground Z from terrain each frame
        if terrain and not self.sm:is("sit") then
            local leg_    = self.leg_len
            local stance_ = self.profile.stance_height or 1.0
            local fz      = terrain:floorAt(self.pos.x, self.pos.y)
            if fz then
                self.floorZ = fz
                local target_gz = fz + leg_ * stance_
                if self.onGround then
                    self.groundZ = target_gz
                    self.pos.z   = target_gz
                else
                    self.groundZ = self.groundZ
                                 + (target_gz - self.groundZ) * math.min(1, dt * 15)
                end
            end
        end

        -- world boundary clamp
        local worldW = (terrain and terrain.worldW) or love.graphics.getWidth()
        if self.pos.x < 40         then self.pos.x = 40;         self.vel.x = 0 end
        if self.pos.x > worldW-40  then self.pos.x = worldW-40;  self.vel.x = 0 end

        local worldD = (terrain and terrain.worldD) or 300
        if self.pos.y < -worldD then self.pos.y = -worldD; self.vel.y = 0 end
        if self.pos.y >  worldD then self.pos.y =  worldD; self.vel.y = 0 end

        self.sm:update(dt)
        self.dt = dt   -- stored so draw callbacks can use it without getDelta()

        self.stepper.terrain = terrain

        -- update facing after physics so velocity reflects this frame
        if not self.sm:is("sit") then
            local new_facing = self.facing
            if self.vel.x >  2 then new_facing =  1 end
            if self.vel.x < -2 then new_facing = -1 end
            if new_facing ~= self.facing then
                self.facing = new_facing
                self.stepper:reset(self.pos.x, self.pos.y, self.floorZ)
            end
        end
    end

    function c:drawSelf(camera)
        self.sm:draw(camera)
    end

    return c
end

return Character
