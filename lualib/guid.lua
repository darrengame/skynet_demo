local skynet = require "skynet"

local M = {}
local guidd

function M.init(cfg)
    skynet.call(guidd, "lua", "init", cfg)
end

function M.get_guid(idtype)
    return skynet.call(guidd, "lua", "get_guid", idtype)
end

skynet.init(function()
    guidd = skynet.uniqueservice("guidd")
end)

return M