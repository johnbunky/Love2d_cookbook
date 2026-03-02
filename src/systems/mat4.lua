-- src/systems/mat4.lua
-- 4x4 column-major matrix math for 3D transforms. Engine-agnostic.
-- Compatible with LÖVE's love.graphics.transformPoint and shader uniforms.
--
-- Stored as flat array [1..16], column-major (OpenGL convention):
--   [1]  [5]  [9]  [13]
--   [2]  [6]  [10] [14]
--   [3]  [7]  [11] [15]
--   [4]  [8]  [12] [16]
--
-- Usage:
--   local Mat4 = require("src.systems.mat4")
--   local m = Mat4.identity()
--   local t = Mat4.translate(1, 2, 3)
--   local r = Mat4.rotateY(math.pi/4)
--   local s = Mat4.scale(2, 2, 2)
--   local mvp = Mat4.mul(Mat4.mul(proj, view), model)
--   local x,y,z,w = Mat4.mulVec4(mvp, px,py,pz,1)

local Mat4 = {}

-- -------------------------
-- Constructor helpers
-- -------------------------
function Mat4.new(t)
    -- t: flat array of 16 values, or nil for zeros
    local m = {}
    for i = 1, 16 do m[i] = t and (t[i] or 0) or 0 end
    return m
end

function Mat4.identity()
    return {
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1,
    }
end

function Mat4.clone(m)
    local r = {}
    for i = 1,16 do r[i] = m[i] end
    return r
end

-- -------------------------
-- Matrix multiply: C = A * B
-- -------------------------
function Mat4.mul(a, b)
    local c = {}
    for col = 0, 3 do
        for row = 0, 3 do
            local sum = 0
            for k = 0, 3 do
                sum = sum + a[k*4+row+1] * b[col*4+k+1]
            end
            c[col*4+row+1] = sum
        end
    end
    return c
end

-- -------------------------
-- Transform a vec4 by matrix: returns x,y,z,w
-- -------------------------
function Mat4.mulVec4(m, x, y, z, w)
    w = w or 1
    return
        m[1]*x + m[5]*y + m[9]*z  + m[13]*w,
        m[2]*x + m[6]*y + m[10]*z + m[14]*w,
        m[3]*x + m[7]*y + m[11]*z + m[15]*w,
        m[4]*x + m[8]*y + m[12]*z + m[16]*w
end

-- Project a 3D point and return 2D screen coords
-- Returns nil if behind camera
function Mat4.project(mvp, x, y, z, screenW, screenH)
    local cx,cy,cz,cw = Mat4.mulVec4(mvp, x, y, z, 1)
    if cw <= 0 then return nil end
    local nx = cx / cw
    local ny = cy / cw
    return
        (nx + 1) * 0.5 * screenW,
        (1 - ny) * 0.5 * screenH,
        cz / cw   -- depth
end

-- -------------------------
-- Transform factories
-- -------------------------
function Mat4.translate(x, y, z)
    local m = Mat4.identity()
    m[13] = x
    m[14] = y
    m[15] = z
    return m
end

function Mat4.scale(x, y, z)
    local m = Mat4.identity()
    m[1]  = x
    m[6]  = y
    m[11] = z
    return m
end

function Mat4.rotateX(angle)
    local c, s = math.cos(angle), math.sin(angle)
    local m = Mat4.identity()
    m[6]  =  c;  m[10] = -s
    m[7]  =  s;  m[11] =  c
    return m
end

function Mat4.rotateY(angle)
    local c, s = math.cos(angle), math.sin(angle)
    local m = Mat4.identity()
    m[1]  =  c;  m[9]  =  s
    m[3]  = -s;  m[11] =  c
    return m
end

function Mat4.rotateZ(angle)
    local c, s = math.cos(angle), math.sin(angle)
    local m = Mat4.identity()
    m[1]  =  c;  m[5]  = -s
    m[2]  =  s;  m[6]  =  c
    return m
end

-- Euler rotation: yaw (Y), pitch (X), roll (Z)
function Mat4.rotateEuler(yaw, pitch, roll)
    return Mat4.mul(Mat4.mul(Mat4.rotateY(yaw), Mat4.rotateX(pitch)), Mat4.rotateZ(roll))
end

-- -------------------------
-- Camera transforms
-- -------------------------

-- lookAt: classic view matrix
function Mat4.lookAt(eyeX,eyeY,eyeZ, atX,atY,atZ, upX,upY,upZ)
    local Vec3 = require("src.systems.vec3")
    local eye  = Vec3.new(eyeX, eyeY, eyeZ)
    local at   = Vec3.new(atX,  atY,  atZ)
    local up   = Vec3.new(upX or 0, upY or 1, upZ or 0)

    local f = Vec3.normalize(Vec3.sub(at, eye))   -- forward
    local r = Vec3.normalize(Vec3.cross(f, up))   -- right
    local u = Vec3.cross(r, f)                    -- up (recomputed)

    return {
        r.x,            u.x,           -f.x,          0,
        r.y,            u.y,           -f.y,          0,
        r.z,            u.z,           -f.z,          0,
       -Vec3.dot(r,eye),-Vec3.dot(u,eye), Vec3.dot(f,eye), 1,
    }
end

-- Perspective projection
function Mat4.perspective(fovY, aspect, near, far)
    local t   = math.tan(fovY * 0.5)
    local m   = Mat4.new()
    m[1]  = 1 / (aspect * t)
    m[6]  = 1 / t
    m[11] = -(far + near) / (far - near)
    m[12] = -1
    m[15] = -(2 * far * near) / (far - near)
    m[16] = 0
    return m
end

-- Orthographic projection
function Mat4.ortho(left, right, bottom, top, near, far)
    local m = Mat4.identity()
    m[1]  =  2 / (right - left)
    m[6]  =  2 / (top - bottom)
    m[11] = -2 / (far - near)
    m[13] = -(right + left) / (right - left)
    m[14] = -(top + bottom) / (top - bottom)
    m[15] = -(far + near)   / (far - near)
    return m
end

-- -------------------------
-- Transpose and inverse
-- -------------------------
function Mat4.transpose(m)
    return {
        m[1], m[5], m[9],  m[13],
        m[2], m[6], m[10], m[14],
        m[3], m[7], m[11], m[15],
        m[4], m[8], m[12], m[16],
    }
end

-- Full 4x4 inverse (general case)
function Mat4.inverse(m)
    local inv = {}
    inv[1]  =  m[6]*m[11]*m[16] - m[6]*m[12]*m[15] - m[10]*m[7]*m[16] + m[10]*m[8]*m[15] + m[14]*m[7]*m[12] - m[14]*m[8]*m[11]
    inv[5]  = -m[5]*m[11]*m[16] + m[5]*m[12]*m[15] + m[9]*m[7]*m[16]  - m[9]*m[8]*m[15]  - m[13]*m[7]*m[12] + m[13]*m[8]*m[11]
    inv[9]  =  m[5]*m[10]*m[16] - m[5]*m[12]*m[14] - m[9]*m[6]*m[16]  + m[9]*m[8]*m[14]  + m[13]*m[6]*m[12] - m[13]*m[8]*m[10]
    inv[13] = -m[5]*m[10]*m[15] + m[5]*m[11]*m[14] + m[9]*m[6]*m[15]  - m[9]*m[7]*m[14]  - m[13]*m[6]*m[11] + m[13]*m[7]*m[10]
    inv[2]  = -m[2]*m[11]*m[16] + m[2]*m[12]*m[15] + m[10]*m[3]*m[16] - m[10]*m[4]*m[15] - m[14]*m[3]*m[12] + m[14]*m[4]*m[11]
    inv[6]  =  m[1]*m[11]*m[16] - m[1]*m[12]*m[15] - m[9]*m[3]*m[16]  + m[9]*m[4]*m[15]  + m[13]*m[3]*m[12] - m[13]*m[4]*m[11]
    inv[10] = -m[1]*m[10]*m[16] + m[1]*m[12]*m[14] + m[9]*m[2]*m[16]  - m[9]*m[4]*m[14]  - m[13]*m[2]*m[12] + m[13]*m[4]*m[10]
    inv[14] =  m[1]*m[10]*m[15] - m[1]*m[11]*m[14] - m[9]*m[2]*m[15]  + m[9]*m[3]*m[14]  + m[13]*m[2]*m[11] - m[13]*m[3]*m[10]
    inv[3]  =  m[2]*m[7]*m[16]  - m[2]*m[8]*m[15]  - m[6]*m[3]*m[16]  + m[6]*m[4]*m[15]  + m[14]*m[3]*m[8]  - m[14]*m[4]*m[7]
    inv[7]  = -m[1]*m[7]*m[16]  + m[1]*m[8]*m[15]  + m[5]*m[3]*m[16]  - m[5]*m[4]*m[15]  - m[13]*m[3]*m[8]  + m[13]*m[4]*m[7]
    inv[11] =  m[1]*m[6]*m[16]  - m[1]*m[8]*m[14]  - m[5]*m[2]*m[16]  + m[5]*m[4]*m[14]  + m[13]*m[2]*m[8]  - m[13]*m[4]*m[6]
    inv[15] = -m[1]*m[6]*m[15]  + m[1]*m[7]*m[14]  + m[5]*m[2]*m[15]  - m[5]*m[3]*m[14]  - m[13]*m[2]*m[7]  + m[13]*m[3]*m[6]
    inv[4]  = -m[2]*m[7]*m[12]  + m[2]*m[8]*m[11]  + m[6]*m[3]*m[12]  - m[6]*m[4]*m[11]  - m[10]*m[3]*m[8]  + m[10]*m[4]*m[7]
    inv[8]  =  m[1]*m[7]*m[12]  - m[1]*m[8]*m[11]  - m[5]*m[3]*m[12]  + m[5]*m[4]*m[11]  + m[9]*m[3]*m[8]   - m[9]*m[4]*m[7]
    inv[12] = -m[1]*m[6]*m[12]  + m[1]*m[8]*m[10]  + m[5]*m[2]*m[12]  - m[5]*m[4]*m[10]  - m[9]*m[2]*m[8]   + m[9]*m[4]*m[6]
    inv[16] =  m[1]*m[6]*m[11]  - m[1]*m[7]*m[10]  - m[5]*m[2]*m[11]  + m[5]*m[3]*m[10]  + m[9]*m[2]*m[7]   - m[9]*m[3]*m[6]

    local det = m[1]*inv[1] + m[2]*inv[5] + m[3]*inv[9] + m[4]*inv[13]
    if math.abs(det) < 1e-12 then return nil end
    local invDet = 1 / det
    for i = 1, 16 do inv[i] = inv[i] * invDet end
    return inv
end

-- -------------------------
-- Flatten for LÖVE shader uniform
-- love.graphics shader:send("uMVP", Mat4.toShader(mvp))
-- -------------------------
function Mat4.toShader(m)
    -- LÖVE expects row-major for mat4 uniforms, so we transpose
    return Mat4.transpose(m)
end

function Mat4.toString(m)
    return string.format(
        "[%.2f %.2f %.2f %.2f]\n[%.2f %.2f %.2f %.2f]\n[%.2f %.2f %.2f %.2f]\n[%.2f %.2f %.2f %.2f]",
        m[1],m[5],m[9],m[13], m[2],m[6],m[10],m[14],
        m[3],m[7],m[11],m[15], m[4],m[8],m[12],m[16])
end

return Mat4
