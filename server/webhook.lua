local format = require 'format'

local M = {}

local MAX_FIELDS    <const> = 24
local MAX_FIELD_LEN <const> = 1024
local MAX_DESC_LEN  <const> = 4000
local MAX_STACK_LEN <const> = 1800
local THROTTLE_MS   <const> = 250

---@type table[]
local queue = {}
local sending = false

local function url() return GetConvar('st:log:webhook', '') end
local function minLevel() return GetConvar('st:log:webhook_level', 'warn') end

---@param level st_log.Level
---@return boolean
local function shouldSend(level)
    if url() == '' then return false end
    local threshold = format.WEIGHT[minLevel()] or 30
    return (format.WEIGHT[level] or 0) >= threshold
end

local function drain()
    if sending or #queue == 0 then return end
    sending = true
    local item = table.remove(queue, 1)
    PerformHttpRequest(url(), function(status)
        sending = false
        if status >= 400 then
            print(('[st_log] webhook returned %d'):format(status))
        end
        if #queue > 0 then SetTimeout(THROTTLE_MS, drain) end
    end, 'POST', json.encode(item), { ['Content-Type'] = 'application/json' })
end

---@param level st_log.Level
---@param domain string?
---@param message string
---@param kv table?
---@param stack string?
function M.enqueue(level, domain, message, kv, stack)
    if not shouldSend(level) then return end

    local fields = {}
    if kv then
        local n = 0
        for k, v in pairs(kv) do
            if n >= MAX_FIELDS then break end
            fields[#fields + 1] = {
                name = k,
                value = ('`%s`'):format(tostring(v)):sub(1, MAX_FIELD_LEN),
                inline = true,
            }
            n = n + 1
        end
    end

    local description = message
    if stack then
        description = ('%s\n```\n%s\n```'):format(message, stack:sub(1, MAX_STACK_LEN))
    end

    queue[#queue + 1] = {
        embeds = { {
            title       = ('[%s] %s'):format(level:upper(), domain or 'strata'),
            description = description:sub(1, MAX_DESC_LEN),
            color       = format.WEBHOOK_COLOR[level] or 0x808080,
            timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            fields      = fields,
        } },
    }
    drain()
end

return M
