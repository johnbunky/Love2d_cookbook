-- src/characters/character.lua
-- World axes: x=left/right, y=depth, z=height (z-up)
--
-- SECONDARY MOTION (profile.secondary):
--
--   breast = {
--       fwd        = 12,    -- forward offset from chest (px)
--       r          = 7,     -- draw radius in soft skin
--       follow     = 0.10,  -- vel.z multiplier → spring target
--       stiffness  = 14,
--       damping    = 6,
--   },
--
--   ponytail = {
--       segs    = 5,      -- number of chain segments
--       seg_len = 10,     -- length of each segment (world units)
--       gravity = 280,    -- chain gravity
--       damping = 0.982,  -- velocity damping per frame
--       back    = 6,      -- root offset backward from head center
--       r       = 4,      -- draw radius at root (soft skin)
--   },

local StateMachine = require "src.systems.statemachine"
local Stepper      = require "src.systems.stepper"
local Spring       = require "src.systems.spring"
local Chain        = require "src.systems.chain"

local Character = {}

function Character.new(profileName, startX)
    local profile = require("src.characters.profiles." .. profileName)
    local rig     = require("src.characters.rigs."     .. profile.rig)
    local draw    = require("src.characters.draw."     .. profile.rig .. "_draw")

    local b       = profile.body or {}
    local leg_len = (b.ul       and (b.ul    + b.ll))
                 or (rig.f_ul   and (rig.f_ul + rig.f_ll))
                 or (rig.ul     and (rig.ul   + rig.ll))
                 or 80

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

        inputX      = 0,
        inputY      = 0,
        inputSit    = false,

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

        dt          = 0,
    }

    -- core springs (always present)
    c.springs = {
        arm      = Spring.new(0),
        sway     = Spring.new(0),
        lean     = Spring.new(0),
        bob      = Spring.new(0),
        squash   = Spring.new(1),   -- rest = 1 (normal height), compress below 1
        breast_l = Spring.new(0),
        breast_r = Spring.new(0),
    }

    -- secondary chains (created only when profile defines them)
    c.chain = {}
    local sec = profile.secondary
    if sec then
        if sec.ponytail then
            local pt = sec.ponytail
            c.chain.ponytail = Chain.new({
                segs      = pt.segs      or 5,
                seg_len   = pt.seg_len   or 10,
                gravity   = pt.gravity   or 280,
                damping   = pt.damping   or 0.982,
                iters     = pt.iters     or 3,
                stiffness = pt.stiffness or 0,
            })
            -- will be reset to correct position on first update
        end
    end

    c.stepper         = Stepper.new(rig, profile)
    c.stepper:reset(c.pos.x, c.pos.y, FLOOR_Z)
    c.stepper.terrain = nil

    c.sm = StateMachine.new(c)
    c.sm:add("idle", require "src.characters.states.idle")
    c.sm:add("walk", require "src.characters.states.walk")
    c.sm:add("jump", require "src.characters.states.jump")
    c.sm:add("fall", require "src.characters.states.fall")
    c.sm:add("land", require "src.characters.states.land")
    c.sm:add("sit",  require "src.characters.states.sit")
    c.sm:enter("idle")

    function c:quadHipRefs()
        if self.rig.feet ~= 4 then return nil end
        local vx2, vy2 = self.vel.x, self.vel.y
        local vl = math.sqrt(vx2*vx2 + vy2*vy2)
        local ddx = vl > 2 and vx2/vl or self.facing
        local ddy = vl > 2 and vy2/vl or 0
        local bl  = self.rig.body_len or 70
        return {
            [1] = { x=self.pos.x + ddx*bl, y=self.pos.y + ddy*bl },
            [2] = { x=self.pos.x + ddx*bl, y=self.pos.y + ddy*bl },
            [3] = { x=self.pos.x,           y=self.pos.y           },
            [4] = { x=self.pos.x,           y=self.pos.y           },
        }
    end

    function c:update(dt, terrain)
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

        local worldW = (terrain and terrain.worldW) or love.graphics.getWidth()
        if self.pos.x < 40        then self.pos.x = 40;        self.vel.x = 0 end
        if self.pos.x > worldW-40 then self.pos.x = worldW-40; self.vel.x = 0 end

        local worldD = (terrain and terrain.worldD) or 300
        if self.pos.y < -worldD then self.pos.y = -worldD; self.vel.y = 0 end
        if self.pos.y >  worldD then self.pos.y =  worldD; self.vel.y = 0 end

        self.sm:update(dt)
        self.dt = dt

        -- ── secondary motion ─────────────────────────────────────────────────
        local sec2 = self.profile.secondary
        if sec2 then

            -- breast: driven by vertical velocity
            -- lower stiffness = more lag behind target = more visible oscillation
            if sec2.breast and self.springs.breast_l then
                local stiff  = sec2.breast.stiffness or 8    -- was 14, lower = more lag
                local damp   = sec2.breast.damping   or 5
                local follow = sec2.breast.follow    or 0.18  -- was 0.10
                local target = -self.vel.z * follow
                self.springs.breast_l:update(dt, target,        stiff, damp)
                self.springs.breast_r:update(dt, target * 0.93, stiff, damp)
            end

            -- ponytail chain: root anchored to back of head
            if sec2.ponytail and self.chain.ponytail then
                local pt   = sec2.ponytail
                local back = pt.back or 6   -- offset behind head

                -- head world position: same calc as humanoid_draw
                -- spine top = pos + groundZ offset already in pos.z
                -- We approximate here using pos + rig spine + head_r
                local rig2   = self.rig
                local b2     = self.profile.body or {}
                local spine  = b2.spine   or rig2.spine   or 60
                local head_r = b2.head_r  or rig2.head_r  or 17

                -- movement direction (same logic as draw)
                local vx2, vy2 = self.vel.x, self.vel.y
                local vlen2 = math.sqrt(vx2*vx2 + vy2*vy2)
                local ddx, ddy
                if vlen2 > 4 then
                    ddx, ddy = vx2/vlen2, vy2/vlen2
                else
                    ddx, ddy = self.lastDx or self.facing, self.lastDy or 0
                end

                -- root = head center, pushed backward (opposite of facing)
                local rx = self.pos.x - ddx * back
                local ry = self.pos.y - ddy * back
                local rz = self.pos.z + spine + head_r * 0.5

                -- first frame: snap chain into position
                if not self.chain.ponytail._inited then
                    Chain.reset(self.chain.ponytail, rx, ry, rz)
                    self.chain.ponytail._inited = true
                end

                -- body colliders: two spheres approximating the torso
                -- keeps the ponytail from passing through chest and pelvis
                local spine2  = b2.spine   or rig2.spine   or 60
                local hip_r   = (b2.hip_w      or rig2.hip_w      or 18) * 0.7
                local chest_r = (b2.shoulder_w or rig2.shoulder_w or 22) * 0.65
                local colliders = {
                    { x=self.pos.x, y=self.pos.y,
                      z=self.pos.z + spine2*0.15,  r=hip_r   },  -- pelvis
                    { x=self.pos.x, y=self.pos.y,
                      z=self.pos.z + spine2*0.80,  r=chest_r },  -- chest
                }

                Chain.update(self.chain.ponytail, dt, rx, ry, rz, colliders)
            end

        end

        self.stepper.terrain = terrain

        -- facing update
        if not self.sm:is("sit") then
            local new_facing = self.facing
            if self.vel.x >  2 then new_facing =  1 end
            if self.vel.x < -2 then new_facing = -1 end
            if new_facing ~= self.facing then
                self.facing = new_facing
                self.stepper:reset(self.pos.x, self.pos.y, self.floorZ)
                -- reset secondary springs on turn
                if sec2 and sec2.breast then
                    self.springs.breast_l:reset(0)
                    self.springs.breast_r:reset(0)
                end
            end
        end
    end

    function c:drawSelf(camera)
        self.sm:draw(camera)
    end

    return c
end

return Character
