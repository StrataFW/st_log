if Log then return end

---@class Log
Log = {}

---@param level string
---@param domain string|nil
---@param msg string|nil
---@param kv table|nil
local function send(level, domain, msg, kv)
    exports.st_log:emit(level, domain, msg or '', kv)
end

---@param domain string|nil
---@param msg string
---@param kv table|nil
function Log.info(domain, msg, kv)       send('info',  domain, msg, kv) end
function Log.warn(domain, msg, kv)       send('warn',  domain, msg, kv) end
function Log.sys(domain, msg, kv)        send('sys',   domain, msg, kv) end
function Log.chat(domain, msg, kv)       send('chat',  domain, msg, kv) end
function Log.admin(domain, msg, kv)      send('admin', domain, msg, kv) end
function Log.connect(domain, msg, kv)    send('conn',  domain, msg, kv) end
function Log.disconnect(domain, msg, kv) send('drop',  domain, msg, kv) end

---@param domain string|nil
---@param msg string
---@param kv table|nil
function Log.error(domain, msg, kv)
    local stack = debug.traceback(nil, 2)
    if kv then kv.stack = stack else kv = { stack = stack } end
    send('error', domain, msg, kv)
end

---@param domain string|nil
---@param msg string
---@param kv table|nil
function Log.debug(domain, msg, kv)
    if GetConvar('st:debug', '0') ~= '1' then return end
    send('debug', domain, msg, kv)
end

---@param source integer
---@param name string
---@param args string[]|nil
function Log.command(source, name, args)
    Log.admin('cmd', name, {
        src  = source,
        args = args and table.concat(args, ' ') or nil,
    })
end

---@generic F : function
---@param domain string
---@param label string
---@param fn F
---@return F
function Log.wrap(domain, label, fn)
    return function(...)
        local results = table.pack(pcall(fn, ...))
        if not results[1] then
            Log.error(domain, ('%s: %s'):format(label, tostring(results[2])))
            return nil
        end
        return table.unpack(results, 2, results.n)
    end
end
