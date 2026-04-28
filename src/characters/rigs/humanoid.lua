-- rigs/humanoid.lua
-- Topology only. Proportions live in the profile under "body" table.

return {
    feet      = 2,
    gait      = {{1, 2}},
    knee_dir  = 1,
    draw_type = "biped",

    -- fallback proportions (used if profile.body is nil)
    spine     = 60,
    head_r    = 17,
    ul        = 52,
    ll        = 46,
    ua        = 36,
    la        = 30,
    hip_w     = 18,
    shoulder_w= 22,
}
