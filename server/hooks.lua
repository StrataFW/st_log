local file  = require 'file'
local dedup = require 'dedup'

local M = {}

local IDENT_PREFERENCE <const> = { 'fivem', 'discord', 'license', 'steam', 'ip' }

---@param src integer
---@return string
local function primaryIdent(src)
    local idents = GetPlayerIdentifiers(src) or {}
    for i = 1, #IDENT_PREFERENCE do
        local prefix = IDENT_PREFERENCE[i]
        for j = 1, #idents do
            if idents[j]:sub(1, #prefix) == prefix then return idents[j] end
        end
    end
    return idents[1] or 'unknown'
end

---@param emit fun(level: st_log.Level, domain: string?, message: string, kv: table?)
function M.register(emit)
    AddEventHandler('playerJoining', function()
        emit('conn', 'session', 'joined', { src = source, ident = primaryIdent(source) })
    end)

    AddEventHandler('playerDropped', function(reason)
        emit('drop', 'session', 'left', { src = source, reason = reason or 'unknown' })
    end)

    AddEventHandler('chatMessage', function(src, _author, message)
        emit('chat', 'chat', message, { src = src })
    end)

    AddEventHandler('ox:playerLoaded', function(playerId, isNew)
        emit('info', 'ox_core', 'character loaded', { src = playerId, new = isNew or false })
    end)

    AddEventHandler('ox:playerLogout', function(playerId)
        emit('info', 'ox_core', 'character logout', { src = playerId })
    end)

    AddEventHandler('onResourceStop', function(name)
        if name ~= GetCurrentResourceName() then return end
        dedup.flush()
        file.close()
    end)
end

return M
