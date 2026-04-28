-- profiles/dog.lua
return {
    rig        = "quadruped",

    accel      = 800,
    drag       = 10,
    max_vx     = 300,
    jump_vy    = -480,

    step_dist  = 45,
    step_lift  = 28,
    step_time  = 0.14,
    look_ahead = 0.16,

    -- speed threshold to switch from trot to gallop state
    gallop_threshold = 200,
    hip_rotation = 0.28,
    paw_r        = 6,

    lean       = 0.10,

    color      = {0.90, 0.75, 0.55},
}
