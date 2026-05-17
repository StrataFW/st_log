local format  = require 'format'
local buffer  = require 'buffer'
local file    = require 'file'
local player  = require 'player'
local dedup   = require 'dedup'
local webhook = require 'webhook'
local redact  = require 'redact'

local M = {}

local C          <const> = format.C
local TAGS       <const> = format.TAGS
local TAG_COLOR  <const> = format.TAG_COLOR
local UI_LEVEL   <const> = format.UI_LEVEL
local DEFERRABLE <const> = format.DEFERRABLE
local WEIGHT     <const> = format.WEIGHT
local RESET, BOLD, DIM = format.RESET, format.BOLD, format.DIM

local stripAnsi  = format.stripAnsi
local fmtKv      = format.fmtKv
local fmtKvPlain = format.fmtKvPlain
local capitalize = format.capitalize
local timeStamp  = format.timeStamp

local SELF = ''
---@type string[]|nil
local deferred = {}

---@param line string
local function consolePrint(line)
    if deferred then
        deferred[#deferred + 1] = line
    else
        print(line)
    end
end

dedup.init(consolePrint)

---@return integer
local function activeMinWeight()
    return WEIGHT[GetConvar('st:log:level', 'info')] or 20
end

---@param level st_log.Level
---@return boolean
local function consoleAllowed(level)
    if GetConvar('st:log:' .. level, '1') == '0' then return false end
    return (WEIGHT[level] or 0) >= activeMinWeight()
end

---@param opts { self: string, root: string }
function M.init(opts)
    SELF = opts.self
    file.init(opts.root)
end

function M.flushDeferred()
    dedup.flush()
    if not deferred then return end
    local pending = deferred
    deferred = nil
    for i = 1, #pending do print(pending[i]) end
end

---@param level st_log.Level
---@param domain string?
---@param message string
---@param extra table?
function M.emit(level, domain, message, extra)
    if level == 'debug' and GetConvar('st:debug', '0') ~= '1' then return end

    message = redact.message(tostring(message or ''))
    extra   = extra and redact.scrub(extra) or extra

    local invoker = GetInvokingResource()
    local playerTag, rest = player.buildTag(extra)

    local stack = nil
    if rest.stack then
        stack = tostring(rest.stack)
        rest.stack = nil
    end

    local domainTag = ''
    if domain and domain ~= invoker and domain ~= SELF then
        domainTag = DIM .. '[' .. RESET .. C.res .. domain .. RESET .. DIM .. ']' .. RESET .. ' '
    end

    local pretty = capitalize(tostring(message or ''))
    local body   = level == 'error' and (BOLD .. pretty .. RESET) or pretty

    local time   = C.time .. timeStamp() .. RESET
    local tag    = (TAG_COLOR[level] or C.info) .. TAGS[level] .. RESET
    local who    = playerTag and (playerTag .. ' ' .. C.sep .. '›' .. RESET .. ' ') or ''
    local kvText = next(rest) and ('  ' .. fmtKv(rest)) or ''

    local line = time .. '  ' .. tag .. '  ' .. domainTag .. who .. C.msg .. body .. RESET .. kvText

    if consoleAllowed(level) then
        local key = (domain or '') .. '|' .. level .. '|' .. stripAnsi(body) .. '|' .. (next(rest) and fmtKvPlain(rest) or '')
        if DEFERRABLE[level] then
            dedup.push(key, line)
        else
            dedup.flush()
            consolePrint(line)
        end
    end

    file.writeText(stripAnsi(line))

    if stack then
        for s in stack:gmatch('[^\n]+') do
            local indented = '        ' .. s
            file.writeText(indented)
            if consoleAllowed(level) then
                consolePrint(C.stack .. indented .. RESET)
            end
        end
    end

    local kvPlain  = next(rest) and fmtKvPlain(rest) or nil
    local tagPlain = playerTag and stripAnsi(playerTag) or nil
    local ctx
    if tagPlain and kvPlain then ctx = tagPlain .. ' ' .. kvPlain
    else                         ctx = tagPlain or kvPlain end

    local entry = {
        ts       = timeStamp(),
        level    = UI_LEVEL[level] or 'info',
        resource = domain or invoker or SELF,
        message  = stripAnsi(pretty),
        ctx      = ctx,
    }
    buffer.record(entry)

    file.writeJson({
        ts       = entry.ts,
        level    = level,
        resource = entry.resource,
        message  = entry.message,
        player   = tagPlain,
        kv       = next(rest) and rest or nil,
        stack    = stack,
    })

    webhook.enqueue(level, domain or invoker or SELF, stripAnsi(pretty), next(rest) and rest or nil, stack)
end

return M
