---@alias st_log.Level 'info'|'warn'|'error'|'debug'|'conn'|'drop'|'chat'|'admin'|'sys'

local M = {}

local function rgb(r, g, b) return ('\27[38;2;%d;%d;%dm'):format(r, g, b) end

M.RESET, M.BOLD, M.DIM = '\27[0m', '\27[1m', '\27[2m'

M.C = {
    time     = rgb(110, 110, 110),
    res      = rgb(160, 160, 160),
    msg      = rgb(232, 232, 232),
    kv_k     = rgb(120, 160, 200),
    kv_v     = rgb(190, 220, 255),
    info     = rgb(110, 200, 230),
    warn     = rgb(245, 200,  90),
    error    = rgb(255,  90,  90),
    debug    = rgb(140, 140, 140),
    conn_in  = rgb( 95, 215, 135),
    conn_out = rgb(220, 130, 130),
    chat     = rgb(180, 180, 220),
    admin    = rgb(220, 130, 220),
    sys      = rgb( 34, 139, 230),
    pl_name  = rgb(220, 220, 220),
    pl_net   = rgb(120, 180, 220),
    pl_sid   = rgb(180, 220, 160),
    sep      = rgb( 95,  95,  95),
    stack    = rgb(150, 150, 150),
}

---@type table<st_log.Level, string>
M.TAGS = {
    info = ' INFO  ', warn = ' WARN  ', error = ' ERROR ', debug = ' DEBUG ',
    conn = ' CONN+ ', drop = ' CONN- ', chat  = ' CHAT  ', admin = ' ADMIN ', sys = ' SYS   ',
}

---@type table<st_log.Level, string>
M.TAG_COLOR = {
    info = M.C.info, warn = M.C.warn, error = M.C.error, debug = M.C.debug,
    conn = M.C.conn_in, drop = M.C.conn_out, chat = M.C.chat, admin = M.C.admin, sys = M.C.sys,
}

---@type table<st_log.Level, 'info'|'warn'|'error'|'debug'>
M.UI_LEVEL = {
    debug = 'debug', info = 'info', warn = 'warn', error = 'error',
    sys = 'info', chat = 'info', admin = 'info', conn = 'info', drop = 'info',
}

---@type table<st_log.Level, integer>
M.WEBHOOK_COLOR = {
    info  = 0x6EC8E6, warn  = 0xF5C85A, error = 0xFF5A5A, debug = 0x8C8C8C,
    sys   = 0x228BE6, admin = 0xDC82DC, chat  = 0xB4B4DC,
    conn  = 0x5FD787, drop  = 0xDC8282,
}

---@type table<st_log.Level, integer>
M.WEIGHT = {
    debug = 0,
    conn = 10, drop = 10, chat = 10, admin = 10, sys = 10,
    info = 20, warn = 30, error = 40,
}

---@type table<st_log.Level, boolean>
M.DEFERRABLE = {
    info = true, sys = true, conn = true, drop = true,
    chat = true, admin = true, debug = true,
}

---@return string
function M.timeStamp() return os.date('%H:%M:%S') --[[@as string]] end

---@param s string
---@return string
function M.stripAnsi(s) return (s:gsub('\27%[[%d;]*m', '')) end

---@param s string
---@return string
function M.capitalize(s)
    if not s or s == '' then return s end
    local first = s:sub(1, 1)
    return first:match('%l') and (first:upper() .. s:sub(2)) or s
end

---@param t table?
---@return string[]
local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = tostring(k) end
    table.sort(out)
    return out
end

---@param v any
---@return string
local function fmtValue(v)
    return type(v) == 'table' and json.encode(v) or tostring(v)
end

---@param t table?
---@return string
function M.fmtKv(t)
    if not t or not next(t) then return '' end
    local keys = sortedKeys(t)
    local parts, kvK, kvV, dim, reset = {}, M.C.kv_k, M.C.kv_v, M.DIM, M.RESET
    for i = 1, #keys do
        local k = keys[i]
        parts[i] = kvK .. k .. reset .. dim .. '=' .. reset .. kvV .. fmtValue(t[k]) .. reset
    end
    return table.concat(parts, ' ')
end

---@param t table?
---@return string
function M.fmtKvPlain(t)
    if not t or not next(t) then return '' end
    local keys, parts = sortedKeys(t), {}
    for i = 1, #keys do
        local k = keys[i]
        parts[i] = k .. '=' .. fmtValue(t[k])
    end
    return table.concat(parts, ' ')
end

return M
