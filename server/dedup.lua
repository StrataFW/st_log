local M = {}

local MAX_HOLD_MS <const> = 500

---@class st_log.DedupState
---@field key string|nil
---@field line string|nil
---@field count integer
---@field since integer

---@type st_log.DedupState
local last = { key = nil, line = nil, count = 0, since = 0 }

---@type fun(line: string)
local sink = function(_) end

local function flush()
    if not last.key then return end
    if last.count > 1 then
        sink(last.line .. ' \27[2m×' .. last.count .. '\27[0m')
    else
        sink(last.line)
    end
    last.key, last.line, last.count, last.since = nil, nil, 0, 0
end

---@param printer fun(line: string)
function M.init(printer)
    sink = printer
    CreateThread(function()
        while true do
            Wait(MAX_HOLD_MS)
            if last.key and (GetGameTimer() - last.since) >= MAX_HOLD_MS then
                flush()
            end
        end
    end)
end

---@param key string
---@param line string
function M.push(key, line)
    if last.key == key then
        last.count = last.count + 1
        return
    end
    flush()
    last.key, last.line, last.count, last.since = key, line, 1, GetGameTimer()
end

function M.flush() flush() end

return M
