local skynet = require "skynet"

local M = {}
local cached

function M.call_cached(func_name, mod, sub_mod, id, ...)
    return skynet.call(cached, "lua", "run", func_name, mod, sub_mod, id, ...)
end

skynet.init(function()
    cached = skynet.uniqueservice("cached")
end)

return M