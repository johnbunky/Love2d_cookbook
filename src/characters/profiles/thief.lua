-- profiles/thief.lua
return {
    rig        = "humanoid",
    skin       = "particles",

    -- twitchy, instant response, snappy stop
    accel      = 940,
    drag       = 14,
    max_vx     = 270,
    jump_vy    = -620,

    -- short quick steps, high lift (light on feet)
    step_dist  = 36,
    step_lift  = 48,
    step_time  = 0.12,
    look_ahead = 0.22,

    -- posture: leans aggressively into movement
    lean       = 0.22,
    arm_swing  = 0.70,

    idle_breath    = 1.3,
    idle_fidget    = 2.0,
    color      = {0.75, 0.75, 0.95},
}
