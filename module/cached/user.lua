local mng = require "cached.mng"

local M = {}
local CMD = {}

-- 初始化回调
local function init_cb(uid, cache)
    if not cache.username then
        cache.username = "New Player"
    end
end

function CMD.get_username(uid, cache)
    return cache.username
end

function CMD.set_username(uid, cache, username)
    cache.username = username
end

function M.init()
    -- 注册初始化回调
    mng.regist_init_cb("user", "user", init_cb)
    -- 注册 cache 操作函数
    mng.regist_cmd("user", "user", CMD)
end

return M