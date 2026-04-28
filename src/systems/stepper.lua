-- src/systems/stepper.lua
-- Procedural foot-placement system. Moves each foot independently:
-- while planted it waits until the hip drifts too far, then swings
-- to a new target position ahead of the character.
-- Pure Lua — no engine dependencies (terrain is accessed via interface).
--
-- USAGE:
--   local Stepper = require "src.systems.stepper"
--   local s = Stepper.new(rig, profile)
--   s:reset(hipX, hipY, floorZ)           -- call after spawning or turning
--   s:update(dt, hipX, hipY, hipZ,
--            velX, velY, floorZ,
--            active, hip_refs)            -- call every frame
--   -- read s.feet[i].x / .y / .z for each foot position
--
-- TERRAIN INTERFACE (optional):
--   Assign s.terrain = { floorAt = function(self, x, y) return z end }
--   When set, each foot snaps to the terrain height at its position.
--
-- PROFILE FIELDS USED:
--   step_dist   hip-to-foot distance that triggers a new step
--   step_lift   arc height of the foot during swing (pixels)
--   step_time   duration of one swing (seconds)
--   look_ahead  seconds ahead the foot landing is predicted
--
-- RIG FIELDS USED:
--   feet          number of feet (2 = biped, 4 = quadruped, 8 = spider …)
--   max_stepping  max feet that may swing simultaneously (default 1)
--   gait          optional list of exclusion pairs  e.g. {{1,2},{3,4}}
--                 a pair means "these feet may not swing at the same time"

local Stepper = {}
Stepper.__index = Stepper

-- Create a new stepper for the given rig/profile pair.
function Stepper.new(rig, profile)
    local s = setmetatable({
        rig      = rig,
        profile  = profile,
        feet     = {},
        stepping = 0,   -- how many feet are currently mid-swing
        terrain  = nil, -- optional terrain interface (see header)
    }, Stepper)
    for i = 1, rig.feet do
        s.feet[i] = {
            x = 0, y = 0, z = 0,   -- current world position
            planted = true,
            swing   = 0,            -- 0..1 progress through swing arc
            fx = 0, fy = 0, fz = 0, -- swing start
            tx = 0, ty = 0, tz = 0, -- swing target
        }
    end
    return s
end

-- Advance all feet by dt.
--
-- hipX/Y/Z  : current hip world position
-- velX/Y    : current velocity (used to predict landing spot)
-- floorZ    : current ground height (fallback when terrain unavailable)
-- active    : true = walking/running; false = idle (feet drift to rest pose)
-- hip_refs  : optional table [i] = {x,y} overriding hip position per foot
--             (used by quadrupeds whose front/back hips differ)
function Stepper:update(dt, hipX, hipY, hipZ, velX, velY, floorZ, active, hip_refs)
    local p = self.profile

    -- Movement direction and its perpendicular (used for lateral foot spread)
    local vlen = math.sqrt(velX*velX + velY*velY)
    local dx, dy
    if vlen > 2 then
        dx, dy = velX/vlen, velY/vlen
    else
        dx, dy = 1, 0
    end
    local px, py = -dy, dx   -- perpendicular to movement direction

    -- ── IDLE: smoothly return feet toward rest positions ──────────────────
    if not active then
        local leg_len = (self.rig.f_ul and (self.rig.f_ul + self.rig.f_ll))
                     or (self.rig.ul  and (self.rig.ul  + self.rig.ll))
                     or 80
        for i, f in ipairs(self.feet) do
            local n       = self.rig.feet
            local spread  = (i - (n + 1) / 2) * 18
            local stagger = (n > 2) and ((i % 2 == 0) and 6 or -6) or 0
            local total   = spread + stagger
            local rx = hipX + px * total
            local ry = hipY + py * total
            local rz = hipZ - leg_len * 0.85
            f.x = f.x + (rx - f.x) * math.min(1, dt * 7)
            f.y = f.y + (ry - f.y) * math.min(1, dt * 7)
            f.z = f.z + (rz - f.z) * math.min(1, dt * 7)
            f.planted = false
        end
        self.stepping = 0
        return
    end

    -- ── ACTIVE: plant / swing logic ───────────────────────────────────────
    local swinging = 0
    for _, f in ipairs(self.feet) do
        if not f.planted then swinging = swinging + 1 end
    end
    self.stepping = swinging

    local max_step = self.rig.max_stepping or 1

    for i, f in ipairs(self.feet) do
        local hx = hip_refs and hip_refs[i] and hip_refs[i].x or hipX
        local hy = hip_refs and hip_refs[i] and hip_refs[i].y or hipY

        if f.planted then
            -- Snap planted foot z to terrain height at its xy (slope tracking)
            if self.terrain then
                local tz = self.terrain:floorAt(f.x, f.y, f.z + 20)
                if tz then f.z = tz end
            end

            -- Trigger a new step when the hip drifts too far from this foot
            local dist2D = math.sqrt((hx - f.x)^2 + (hy - f.y)^2)
            if dist2D > p.step_dist
               and self.stepping < max_step
               and self:canStep(i) then

                f.planted = false
                f.swing   = 0
                f.fx, f.fy, f.fz = f.x, f.y, f.z   -- swing from here

                -- Target: ahead in movement direction + lateral spread
                local n       = self.rig.feet
                local spread  = (i - (n + 1) / 2) * 18
                local stagger = (n > 2) and ((i % 2 == 0) and 6 or -6) or 0
                local total   = spread + stagger
                f.tx = hx + velX * p.look_ahead + px * total
                f.ty = hy + velY * p.look_ahead + py * total
                f.tz = (self.terrain and self.terrain:floorAt(f.tx, f.ty, 9999))
                       or floorZ

                self.stepping = self.stepping + 1
            end

        else
            -- Advance swing arc (sine loft for the foot lift)
            f.swing = math.min(1, f.swing + dt / p.step_time)
            local s = f.swing
            f.x = f.fx + (f.tx - f.fx) * s
            f.y = f.fy + (f.ty - f.fy) * s
            f.z = f.fz + (f.tz - f.fz) * s
                  + math.sin(s * math.pi) * p.step_lift

            if f.swing >= 1 then
                f.planted = true
                f.x, f.y, f.z = f.tx, f.ty, f.tz
                self.stepping = math.max(0, self.stepping - 1)
            end
        end
    end
end

-- Check gait constraints: returns false if another foot in the same gait
-- pair is currently mid-swing (prevents the character hopping on one leg).
function Stepper:canStep(i)
    local gait = self.rig.gait
    if not gait then return true end
    for _, pair in ipairs(gait) do
        for _, idx in ipairs(pair) do
            if idx == i then
                for _, other in ipairs(pair) do
                    if other ~= i and not self.feet[other].planted then
                        return false
                    end
                end
            end
        end
    end
    return true
end

-- Snap all feet to rest positions instantly (call after spawn or direction flip).
function Stepper:reset(hipX, hipY, floorZ)
    local n      = self.rig.feet
    local px, py = 0, 1   -- perpendicular to default facing direction
    for i, f in ipairs(self.feet) do
        local spread  = (i - (n + 1) / 2) * 18
        local stagger = (n > 2) and ((i % 2 == 0) and 6 or -6) or 0
        local total   = spread + stagger
        f.x, f.y, f.z = hipX + px*total, hipY + py*total, floorZ
        f.planted = true
        f.swing   = 0
    end
    self.stepping = 0
end

return Stepper
