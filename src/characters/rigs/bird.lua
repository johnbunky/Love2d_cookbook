-- rigs/bird.lua
-- Two-legged, horizontal spine, backward-bending knees.
-- Covers duck, chicken, small dinosaur-like creatures.

return {
    feet     = 2,
    gait     = {{1, 2}},

    -- body is mostly horizontal
    spine    = 28,         -- short, nearly horizontal
    spine_ang = -0.2,      -- slight upward tilt toward head
    head_r   = 12,
    neck_len = 22,

    -- legs attach below a horizontal body
    ul       = 28,
    ll       = 26,
    knee_dir = -1,         -- backward-bending knees

    -- wing (treated as a simple FK arm, usually folded)
    wing_len = 34,
    wing_fold = 0.85,      -- 0=fully open, 1=fully folded

    draw_type = "bird",
}
