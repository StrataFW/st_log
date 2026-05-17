local SELF     <const> = GetCurrentResourceName()
local RES_ROOT <const> = GetResourcePath(SELF)

do
    local cache = {}
    function _G.require(name)
        local cached = cache[name]
        if cached ~= nil then return cached end
        local src = LoadResourceFile(SELF, 'server/' .. name .. '.lua')
        if not src then error('module not found: ' .. tostring(name), 2) end
        local chunk, err = load(src, '@@' .. SELF .. '/server/' .. name .. '.lua', 't')
        if not chunk then error(err, 2) end
        local result = chunk()
        cache[name] = result == nil and true or result
        return cache[name]
    end
end

local Emit      <const> = require 'emit'
local Buffer    <const> = require 'buffer'
local File      <const> = require 'file'
local Hooks     <const> = require 'hooks'
local Commands  <const> = require 'commands'
local Retention <const> = require 'retention'

Emit.init({ self = SELF, root = RES_ROOT })
Hooks.register(Emit.emit)
Commands.register(Emit.emit)

---@param level st_log.Level
---@param domain string?
---@param message string
---@param kv table?
local function safeEmit(level, domain, message, kv)
    local ok, err = pcall(Emit.emit, level, domain, message, kv)
    if not ok then print('[st_log] emit failed: ' .. tostring(err)) end
end

exports('emit',           safeEmit)
exports('flushDeferred',  Emit.flushDeferred)
exports('writeLogLine',   File.writeText)
exports('recordEntry',    Buffer.record)
exports('clear',          Buffer.clear)
exports('tail',           function(n) return Buffer.tail(tonumber(n) or 200) end)
exports('export',         function()
    local lines = {}
    Buffer.walk(function(e)
        lines[#lines + 1] = ('%s %-5s [%s] %s%s'):format(
            e.ts, e.level, e.resource, e.message,
            e.ctx and (' | ' .. e.ctx) or '')
    end)
    return File.exportSnapshot(lines)
end)

Retention.start(RES_ROOT, function(removed)
    if removed > 0 then
        safeEmit('sys', 'st_log', 'retention sweep complete', { removed = removed })
    end
end)

CreateThread(function()
    Wait(2000)
    safeEmit('sys', 'st_log', 'logging system online', {
        debug     = GetConvar('st:debug', '0') == '1' and 'on' or 'off',
        file      = GetConvar('st:log:file', '1') == '1' and 'on' or 'off',
        json      = GetConvar('st:log:json', '0') == '1' and 'on' or 'off',
        webhook   = GetConvar('st:log:webhook', '') ~= '' and 'on' or 'off',
        redact    = GetConvar('st:log:redact', '1') == '1' and 'on' or 'off',
        level     = GetConvar('st:log:level', 'info'),
        retention = (tonumber(GetConvar('st:log:retention_days', '30')) or 30) .. 'd',
    })
end)
