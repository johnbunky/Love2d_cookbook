return {
    rig        = "quadruped",
    accel      = 700, drag=12, max_vx=260, jump_vy=-480,
    step_dist  = 38, step_lift=32, step_time=0.13, look_ahead=0.18,
    stance_height = 0.72,   -- hip rests at 72% of leg reach — leaves room for knee bend   -- hip bar rotation amplitude per stride
    paw_r        = 5,      -- paw ellipse radius
    lean       = 0.08,
    color      = {0.90, 0.80, 0.65},
}
