local M = {}

local DAY <const> = 86400

---@type string[]
local NAME_PATTERNS <const> = {
    '^strata%-(%d%d%d%d)%-(%d%d)%-(%d%d)%.log$',
    '^strata%-(%d%d%d%d)%-(%d%d)%-(%d%d)%.ndjson$',
    '^strata%-(%d%d%d%d)(%d%d)(%d%d)%-%d%d%d%d%d%d%.log$',
    '^strata%-(%d%d%d%d)(%d%d)(%d%d)%-%d%d%d%d%d%d%.ndjson$',
    '^strata%-export%-(%d%d%d%d)(%d%d)(%d%d)%-%d%d%d%d%d%d%.log$',
}

local function retentionDays()
    return tonumber(GetConvar('st:log:retention_days', '30')) or 30
end

---@param name string
---@return integer|nil
local function fileEpoch(name)
    for i = 1, #NAME_PATTERNS do
        local y, mo, d = name:match(NAME_PATTERNS[i])
        if y then
            return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 0 })
        end
    end
end

---@param root string
---@return string[]
local function listDir(root)
    local out = {}
    local p = io.popen(('ls "%s" 2>/dev/null'):format(root))
    if p then
        for line in p:lines() do out[#out + 1] = line end
        p:close()
        if #out > 0 then return out end
    end
    p = io.popen(('dir /b "%s" 2>nul'):format((root:gsub('/', '\\'))))
    if p then
        for line in p:lines() do out[#out + 1] = line end
        p:close()
    end
    return out
end

---@param root string
---@return integer  removed
local function sweep(root)
    local days = retentionDays()
    if days <= 0 then return 0 end

    local cutoff = os.time() - days * DAY
    local removed = 0

    for _, name in ipairs(listDir(root)) do
        local epoch = fileEpoch(name)
        if epoch and epoch < cutoff then
            local ok = os.remove(root .. '/' .. name)
            if ok then removed = removed + 1 end
        end
    end

    return removed
end

---@param root string
---@param onSweep fun(removed: integer)?
function M.start(root, onSweep)
    CreateThread(function()
        Wait(5000)
        local n = sweep(root)
        if onSweep then onSweep(n) end
        while true do
            Wait(6 * 60 * 60 * 1000)
            local r = sweep(root)
            if onSweep then onSweep(r) end
        end
    end)
end

return M
