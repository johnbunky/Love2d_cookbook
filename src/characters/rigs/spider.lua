-- rigs/spider.lua
-- 8 legs in 4 pairs. Body is a compact oval. Knees splay outward.
-- Feet order: 1=front-left, 2=front-right, 3=mid-left, 4=mid-right,
--             5=rear-mid-left, 6=rear-mid-right, 7=back-left, 8=back-right

return {
    feet      = 8,
    -- gait: diagonal pairs
    gait      = {{1,6},{2,5},{3,8},{4,7}},

    -- body
    body_r    = 18,        -- body radius (drawn as oval)
    body_len  = 28,        -- front-to-back body length

    -- all legs same length, but different attachment angles
    ul        = 28,
    ll        = 24,
    knee_dir  = 1,         -- handled per-leg in draw (all knees splay out)

    -- leg attachment angles from body centre (radians, 0=right, pi=left)
    -- four pairs: front, mid-front, mid-rear, rear
    attach_angles = {
        math.pi * 0.15,    -- front-left
        -math.pi * 0.15,   -- front-right
        math.pi * 0.38,    -- mid-left
        -math.pi * 0.38,   -- mid-right
        math.pi * 0.62,    -- rear-mid-left
        -math.pi * 0.62,   -- rear-mid-right
        math.pi * 0.85,    -- back-left
        -math.pi * 0.85,   -- back-right
    },

    draw_type = "spider",
}
