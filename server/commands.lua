local buffer = require 'buffer'
local file   = require 'file'
local format = require 'format'

local M = {}

---@param fn fun(source: integer, args: string[], raw: string)
---@return fun(source: integer, args: string[], raw: string)
local function consoleOnly(fn)
    return function(source, args, raw)
        if source ~= 0 then return end
        fn(source, args, raw)
    end
end

---@param emit fun(level: st_log.Level, domain: string?, message: string, kv: table?)
function M.register(emit)
    RegisterCommand('logdebug', consoleOnly(function(_, args)
        local arg = (args[1] or ''):lower()
        if arg == 'on' or arg == '1' or arg == 'true' then
            SetConvar('st:debug', '1')
            emit('sys', 'st_log', 'debug logging enabled')
        elseif arg == 'off' or arg == '0' or arg == 'false' then
            SetConvar('st:debug', '0')
            emit('sys', 'st_log', 'debug logging disabled')
        else
            local on = GetConvar('st:debug', '0') == '1'
            emit('sys', 'st_log', ('debug is %s. Use: logdebug on|off'):format(on and 'on' or 'off'))
        end
    end), true)

    RegisterCommand('logmute', consoleOnly(function(_, args)
        local cat = args[1]
        if not cat then
            emit('sys', 'st_log', 'usage: logmute <category> [on|off]')
            return
        end
        local arg = (args[2] or 'on'):lower()
        local mute = arg ~= 'off' and arg ~= '0' and arg ~= 'false'
        SetConvar('st:log:' .. cat, mute and '0' or '1')
        emit('sys', 'st_log', ('console %s for [%s]'):format(mute and 'muted' or 'unmuted', cat))
    end), true)

    RegisterCommand('loglevel', consoleOnly(function(_, args)
        local lvl = (args[1] or ''):lower()
        if lvl == '' then
            emit('sys', 'st_log', 'current min level: ' .. GetConvar('st:log:level', 'info'))
            return
        end
        if not format.WEIGHT[lvl] then
            emit('sys', 'st_log', 'unknown level. Use: debug|info|warn|error')
            return
        end
        SetConvar('st:log:level', lvl)
        emit('sys', 'st_log', 'min console level set to ' .. lvl)
    end), true)

    RegisterCommand('logtail', consoleOnly(function(_, args)
        local n = tonumber(args[1]) or 50
        local entries = buffer.tail(n)
        for i = 1, #entries do
            local e = entries[i]
            print(('%s %-5s [%s] %s%s'):format(
                e.ts, e.level, e.resource, e.message,
                e.ctx and (' | ' .. e.ctx) or ''))
        end
    end), true)

    RegisterCommand('logexport', consoleOnly(function()
        local lines = {}
        buffer.walk(function(e)
            lines[#lines + 1] = ('%s %-5s [%s] %s%s'):format(
                e.ts, e.level, e.resource, e.message,
                e.ctx and (' | ' .. e.ctx) or '')
        end)
        local path = file.exportSnapshot(lines)
        emit('sys', 'st_log', path and ('exported to ' .. path) or 'export failed')
    end), true)
end

return M
