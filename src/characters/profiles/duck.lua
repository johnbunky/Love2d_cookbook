-- profiles/duck.lua
return {
    rig        = "bird",

    accel      = 200,
    drag       = 18,
    max_vx     = 90,
    jump_vy    = -340,

    -- tiny shuffling steps
    step_dist  = 22,
    step_lift  = 12,
    step_time  = 0.20,
    look_ahead = 0.10,

    -- waddle: body rocks side to side independent of step cycle
    waddle_amp  = 0.18,    -- radians of body roll
    waddle_freq = 6.0,     -- oscillations per second

    lean        = 0.04,

    color       = {0.95, 0.85, 0.40},
}
