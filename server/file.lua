---@class st_log.SinkState
---@field handle file*|nil
---@field date string|nil
---@field bytes integer
---@field gaveUp boolean
---@field queue string[]

local FLUSH_INTERVAL_MS <const> = 50

local M = {}

local cfg = { root = '' }

---@type st_log.SinkState
local text = { handle = nil, date = nil, bytes = 0, gaveUp = false, queue = {} }

---@type st_log.SinkState
local nd = { handle = nil, date = nil, bytes = 0, gaveUp = false, queue = {} }

local function fileEnabled() return GetConvar('st:log:file', '1') == '1' end
local function jsonEnabled() return GetConvar('st:log:json', '0') == '1' end
local function maxBytes()
    local mb = tonumber(GetConvar('st:log:max_size_mb', '10')) or 10
    return mb * 1024 * 1024
end

local function today() return os.date('%Y-%m-%d') --[[@as string]] end
local function stamp() return os.date('%Y%m%d-%H%M%S') --[[@as string]] end

---@param state st_log.SinkState
---@param ext string
local function rotate(state, ext)
    if state.gaveUp then return end
    local day = today()
    local limit = maxBytes()

    if state.handle and state.bytes >= limit and state.date then
        pcall(state.handle.close, state.handle)
        local original = ('%s/strata-%s.%s'):format(cfg.root, state.date, ext)
        local rolled   = ('%s/strata-%s.%s'):format(cfg.root, stamp(), ext)
        os.rename(original, rolled)
        state.handle, state.date, state.bytes = nil, nil, 0
    end

    if state.handle and state.date == day then return end

    if state.handle then pcall(state.handle.close, state.handle) end

    local path = ('%s/strata-%s.%s'):format(cfg.root, day, ext)
    local h, err = io.open(path, 'a')
    if not h then
        state.gaveUp = true
        print(('[st_log] %s logging disabled: %s'):format(ext, tostring(err)))
        return
    end

    state.handle, state.date = h, day
    state.bytes = h:seek('end') or 0

    if ext == 'log' then
        local header = ('==== %s log opened\n'):format(os.date('%Y-%m-%d %H:%M:%S'))
        h:write(header)
        state.bytes = state.bytes + #header
        h:flush()
    end
end

---@param state st_log.SinkState
---@param ext string
local function drainSink(state, ext)
    if #state.queue == 0 then return end
    rotate(state, ext)
    local h = state.handle
    if not h then
        state.queue = {}
        return
    end
    local lines = state.queue
    state.queue = {}
    for i = 1, #lines do
        local line = lines[i]
        h:write(line)
        state.bytes = state.bytes + #line
    end
    h:flush()
end

local function drainAll()
    drainSink(text, 'log')
    drainSink(nd,   'ndjson')
end

---@param root string
function M.init(root)
    cfg.root = root
    CreateThread(function()
        while true do
            Wait(FLUSH_INTERVAL_MS)
            local ok, err = pcall(drainAll)
            if not ok then print('[st_log] file drain error: ' .. tostring(err)) end
        end
    end)
end

---@param rawLine string
function M.writeText(rawLine)
    if not fileEnabled() then return end
    text.queue[#text.queue + 1] = rawLine .. '\n'
end

---@param entry table
function M.writeJson(entry)
    if not jsonEnabled() then return end
    nd.queue[#nd.queue + 1] = json.encode(entry) .. '\n'
end

---@param lines string[]
---@return string|nil
function M.exportSnapshot(lines)
    local path = ('%s/strata-export-%s.log'):format(cfg.root, stamp())
    local h, err = io.open(path, 'w')
    if not h then
        print(('[st_log] export failed: %s'):format(tostring(err)))
        return nil
    end
    for i = 1, #lines do h:write(lines[i], '\n') end
    h:close()
    return path
end

function M.flush()
    pcall(drainAll)
end

function M.close()
    pcall(drainAll)
    if text.handle then pcall(text.handle.close, text.handle); text.handle = nil end
    if nd.handle   then pcall(nd.handle.close,   nd.handle);   nd.handle   = nil end
end

return M
