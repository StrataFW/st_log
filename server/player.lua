local format = require 'format'

local M = {}

local PLAYER_KEYS <const> = {
    src = true, player = true, netId = true,
    charId = true, userId = true, stateId = true,
}

local C, RESET = format.C, format.RESET

---@param extra table?
---@return string?  tag
---@return table    rest
function M.buildTag(extra)
    if type(extra) ~= 'table' then return nil, {} end

    local src     = rawget(extra, 'src')
    local name    = rawget(extra, 'player')
    local netId   = rawget(extra, 'netId')
    local charId  = rawget(extra, 'charId')
    local stateId = rawget(extra, 'stateId')

    if src and src ~= 0 then
        if not name  then name  = GetPlayerName(src) end
        if not netId then netId = src end

        local ox = _G.Ox
        if ox and ox.GetPlayer then
            local ok, p = pcall(ox.GetPlayer, src)
            if ok and p then
                charId  = charId  or p.charId
                stateId = stateId or p.stateId
            end
        end
    end

    local rest = {}
    for k, v in pairs(extra) do
        if not PLAYER_KEYS[k] then rest[k] = v end
    end

    if not (name or netId or charId or stateId) then return nil, rest end

    local parts = {}
    if name  then parts[#parts + 1] = C.pl_name .. tostring(name) .. RESET end
    if netId then parts[#parts + 1] = C.pl_net .. '#' .. netId .. RESET end

    local charLabel = stateId or charId
    if charLabel then
        parts[#parts + 1] = C.sep .. '·' .. RESET .. ' ' .. C.pl_sid .. tostring(charLabel) .. RESET
    end

    return table.concat(parts, ' '), rest
end

return M
