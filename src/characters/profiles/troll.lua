-- profiles/troll.lua
return {
    rig        = "humanoid",

    -- heavy, slow to start, hard to stop
    accel      = 280,
    drag       = 3,
    max_vx     = 130,
    jump_vy    = -360,

    -- wide lumbering steps, low lift (flat-footed)
    step_dist  = 80,
    step_lift  = 18,
    step_time  = 0.30,
    look_ahead = 0.12,

    -- posture: hunched forward
    lean       = 0.06,
    arm_swing  = 0.30,

    idle_breath    = 0.5,
    idle_fidget    = 0.4,
    color      = {0.55, 0.80, 0.45},
}
