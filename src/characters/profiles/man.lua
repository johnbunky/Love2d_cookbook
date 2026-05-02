-- profiles/man.lua
return {
    rig        = "humanoid",
    skins = {
        "wire", "face",
    },
    -- ============================================================
    -- BODY PROPORTIONS
    -- These override rig defaults. Remove any line to use the default.
    -- ============================================================
    body = {
        spine      = 60,   -- torso height hip→shoulder. taller = longer body
        head_r     = 17,   -- head radius
        ul         = 52,   -- upper leg length. longer = taller stance
        ll         = 46,   -- lower leg length
        ua         = 36,   -- upper arm
        la         = 30,   -- lower arm
        hip_w      = 18,   -- half-width of hip bar. wider = broader hips
        shoulder_w = 22,   -- half-width of shoulder bar. wider = broader shoulders
    },

    -- ============================================================
    -- PHYSICS — controls how the character moves in the world
    -- ============================================================
    accel      = 620,   -- how fast top speed is reached. high = snappy, low = sluggish
    drag       = 8,     -- how fast character stops. high = instant stop, low = slides
    max_vx     = 220,   -- top horizontal speed (pixels/sec)
    jump_vy    = -530,  -- jump impulse. more negative = higher jump

    -- ============================================================
    -- STEPPING — controls how feet plant on the ground
    -- ============================================================
    step_dist  = 52,    -- how far hip moves before triggering a new step
                        -- shorter = more frequent small steps, longer = bigger strides
    step_lift  = 34,    -- how high foot arcs during a step. higher = more prancing
    step_time  = 0.17,  -- seconds per step swing. lower = quicker feet
    look_ahead = 0.18,  -- seconds ahead foot landing is predicted. more = foot lands further forward

    -- ============================================================
    -- POSTURE — static offsets applied at all speeds
    -- ============================================================
    lean       = 0.12,  -- forward lean per unit speed (radians). more = hunches forward when running
    arm_swing  = 0.55,
    arm_bend   = 0.30,   -- elbow inward bend at rest/walk (0=straight, 1=fully bent)
    run_arm_bend = 0.65, -- elbow bend when running (arms pump with bent elbows)  -- max arm swing amplitude (radians). more = wider arm movement

    -- ============================================================
    -- WALK ANIMATION — blends toward run values as speed increases
    -- ============================================================
    walk_phase_speed = 10,   -- stride cadence. higher = legs move faster
    walk_bob         = 6,    -- vertical body bounce (pixels). more = bouncier walk
    walk_sway        = 2.5,  -- lateral hip sway (pixels)
    walk_wave        = 4.0,  -- forward/back hip oscillation (pixels). visible sinusoid in side-scroll
    walk_counter     = 0.08,  -- shoulder counter-rotation (0=none, 1=full). natural human gait ~0.3-0.5

    -- ============================================================
    -- RUN ANIMATION — target values at full speed
    -- All walk→run transitions are smooth blends driven by speed_n
    -- ============================================================
    run_threshold    = 0.55,  -- fraction of max_vx where run blend starts (0.5 = halfway)
    run_phase_speed  = 16,    -- faster stride cadence at full run
    run_bob          = 11,    -- bigger bounce when running
    run_sway         = 1.2,   -- hips tighten laterally during run
    run_lean         = 0.28,  -- more aggressive forward lean at full run
    run_arm_pump     = 0.85,  -- arm swing amplitude at full run
    run_counter      = 0.15,   -- stronger shoulder opposition when running

    -- ============================================================
    -- IDLE ANIMATION
    -- ============================================================
    idle_breath    = 0.9,
    idle_fidget    = 1.0,

    -- ============================================================
    -- LIMB SPRINGS — inertia and overshoot per limb
    -- lower stiffness = more lag, lower damping = more overshoot
    -- ============================================================
    arm_stiffness  = 10,   -- try 8 (floaty) to 35 (snappy)
    arm_damping    = 6,   -- try 6 (bouncy) to 20 (dead)
    body_stiffness = 14,   -- bob / sway / lean
    body_damping   = 9,

    -- color (r, g, b)
    color      = {0.55, 0.95, 0.75},
}
