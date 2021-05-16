local skynet = require "skynet"
require "skynet.mananger"

local last = 0
local last_value

local function get_str_time()
    local cur = math.floor(skynet.time())
    if last ~= cur then
        last_value = os.date("%Y-%m-%d %H:%M:%s", cur)
    end
    return last_value
end

skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    unpack = skynet.tostring,
    dispatch = function(_, addr, str)
        local time = get_str_time()
        str = string.format("[%08x][%s] %s", addr, time, str)
        print(str)
    end
}

-- 捕捉 signhup 信号（skill -1）
skynet.register_protocol {
    name = "SYSTEM",
    id = skynet.PTYPE_SYSTEM,
    unpack = function(...) return ... end,
    dispatch = function()
        local cached = skynet.localname(".cached")
        if cached then
            skynet.error("call cached handle SIGHUP")
            skynet.call(cached, "lua", "SIGHUP")
        else
            skynet.error("handle SIGHUP, skynet will be stop")
        end

        skynet.sleep(100)
        skynet.abort()
    end
}

local CMD = {}

skynet.start(function()
    skynet.register ".log"
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("invalid cmd. cmd:", cmd)
        end
    end)
end)