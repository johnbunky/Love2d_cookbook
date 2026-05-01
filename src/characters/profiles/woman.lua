-- profiles/woman.lua
return {
    rig = "humanoid",
    skins = {
        "soft",
        { name = "wire", blend = "alpha", alpha = 0.35 },
    },
    secondary = {
        breast   = { fwd = 8,  r = 7  },
        ponytail = {
            stiffness = 0.35,    -- new — pulls each segment toward straight
            segs    = 5,      -- chain segments
            seg_len = 10,     -- segment length in world units
            back    = 6,      -- root offset behind head
            r       = 4,      -- draw radius at root (soft skin tapers to tip)
            gravity = 180,    -- heavier = falls faster
            damping = 0.96,  -- closer to 1 = floatier, closer to 0.95 = snappier
        },
    },
    body = {
        spine      = 56,
        head_r     = 15,
        ul         = 50,
        ll         = 44,
        ua         = 30,
        la         = 26,
        hip_w      = 19,   -- wider hips
        shoulder_w = 16,   -- narrower shoulders — inverted ratio vs man
    },

    -- posture: positive value arches the spine (chest forward, shoulders back)
    -- creates an S-curve: hips forward, chest lifted, head slightly back
    posture_arch = 0.09,

    accel      = 540,
    drag       = 9,
    max_vx     = 195,
    jump_vy    = -490,

    step_dist  = 38,   -- shorter, more deliberate steps
    step_lift  = 26,   -- feet barely leave the floor (graceful)
    step_time  = 0.19,
    look_ahead = 0.15,

    lean       = 0.06,   -- less forward lean — more upright posture
    arm_swing  = 0.38,   -- arms swing less, more controlled

    walk_hip_rotation = 0.18,  -- hip bar rotates with stride (feminine gait)
    walk_phase_speed = 12,   -- quicker cadence (shorter legs)
    walk_bob         = 6,    -- minimal vertical bounce
    walk_sway        = 9.5,  -- pronounced hip sway — the key element
    walk_counter     = 0.15, -- very little shoulder rotation

    run_threshold    = 0.50,
    run_phase_speed  = 17,
    run_bob          = 9,
    run_sway         = 3.5,  -- sway reduces when running but stays present
    run_lean         = 0.16,
    run_arm_pump     = 0.60,
    run_counter      = 0.20,

    idle_breath    = 0.80,
    idle_fidget    = 1.2,

    color = {0.95, 0.70, 0.80},
}
