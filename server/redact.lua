local M = {}

---@type { [1]: string, [2]: string }[]
local PATTERNS <const> = {
    { '(mysql://[^:]+:)[^@]+(@)',                  '%1***%2' },
    { '(Bearer%s+)[%w%-_%.]+',                     '%1***'   },
    { '(sk%-)[%w%-_]+',                            '%1***'   },
    { '(xox[bpoasr]%-)[%w%-]+',                    '%1***'   },
    { '(discord%.com/api/webhooks/%d+/)[%w%-_]+',  '%1***'   },
    { '([Pp]assword[%s]*[:=][%s]*)[^&;%s,"]+',     '%1***'   },
    { '([Tt]oken[%s]*[:=][%s]*)[^&;%s,"]+',        '%1***'   },
    { '([Aa]pi[_%-]?[Kk]ey[%s]*[:=][%s]*)[^&;%s,"]+', '%1***' },
    { '([Aa]uthorization[%s]*[:=][%s]*)[^&;%s,"]+', '%1***'  },
}

local MAX_DEPTH <const> = 3

local function enabled()
    return GetConvar('st:log:redact', '1') == '1'
end

---@param s string
---@return string
function M.scrubString(s)
    if type(s) ~= 'string' then return s end
    for i = 1, #PATTERNS do
        local p = PATTERNS[i]
        s = s:gsub(p[1], p[2])
    end
    return s
end

---@param v any
---@param depth integer?
---@return any
function M.scrub(v, depth)
    if not enabled() then return v end
    depth = depth or 0
    if depth > MAX_DEPTH then return v end

    local t = type(v)
    if t == 'string' then return M.scrubString(v) end
    if t == 'table' then
        local out = {}
        for k, val in pairs(v) do out[k] = M.scrub(val, depth + 1) end
        return out
    end
    return v
end

---@param s string
---@return string
function M.message(s)
    if not enabled() then return s end
    return M.scrubString(s)
end

return M
