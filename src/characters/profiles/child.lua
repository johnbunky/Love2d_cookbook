-- profiles/child.lua
return {
    rig = "humanoid",

    body = {
        spine      = 38,   -- short torso
        head_r     = 16,   -- head proportionally large
        ul         = 34,
        ll         = 30,
        ua         = 24,
        la         = 20,
        hip_w      = 12,
        shoulder_w = 14,   -- shoulders barely wider than hips
    },

    accel      = 700,
    drag       = 12,
    max_vx     = 180,
    jump_vy    = -460,

    step_dist  = 30,   -- short legs = short steps
    step_lift  = 38,   -- kids lift feet high
    step_time  = 0.13,
    look_ahead = 0.14,

    lean       = 0.05,   -- kids run upright
    arm_swing  = 0.65,   -- arms flail more

    walk_phase_speed = 14,   -- fast little legs
    walk_bob         = 7,    -- bouncy
    walk_sway        = 2.0,
    walk_counter     = 0.25, -- less coordinated shoulder opposition

    run_threshold    = 0.40, -- breaks into run quickly
    run_phase_speed  = 20,   -- legs go very fast
    run_bob          = 13,
    run_sway         = 1.5,
    run_lean         = 0.10,
    run_arm_pump     = 0.90, -- arms pumping wildly
    run_counter      = 0.20,

    idle_breath    = 1.1,
    idle_fidget    = 2.2,    -- fidgets constantly

    color = {0.75, 0.85, 0.95},
}
