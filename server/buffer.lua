---@class st_log.Entry
---@field ts string
---@field level string
---@field resource string
---@field message string
---@field ctx string|nil

local LIMIT <const> = 2000

local M = {}

local data, head, count = {}, 0, 0

---@param entry st_log.Entry
function M.record(entry)
    head = head % LIMIT + 1
    data[head] = entry
    if count < LIMIT then count = count + 1 end
end

---@param fn fun(entry: st_log.Entry)
function M.walk(fn)
    if count == 0 then return end
    local idx = head - count + 1
    if idx < 1 then idx = idx + LIMIT end
    for _ = 1, count do
        local e = data[idx]
        if e then fn(e) end
        idx = idx % LIMIT + 1
    end
end

---@param n integer
---@return st_log.Entry[]
function M.tail(n)
    n = math.min(n, count)
    local out, idx = {}, head
    for i = n, 1, -1 do
        out[i] = data[idx]
        idx = idx - 1
        if idx < 1 then idx = LIMIT end
    end
    return out
end

function M.clear()
    data, head, count = {}, 0, 0
end

---@return integer
function M.size() return count end

return M
