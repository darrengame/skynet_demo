local db_cache = require "db_cache"
local log = require "log"

local M = {}

-- 修改玩家名字指令实现
local function set_name(uid, name)
    local ret, err = db_cache.call_cached("set_username", "user", "user", uid, name)
    log.debug("set name:", uid, name, ret)
    if ret then
        return true, "set name succ"
    end

    return false, err
end

-- 指令参数配置
M.CMD = {
    setname = { -- 指令名
        fun = set_name, -- 指令实现逻辑
        args = {"uid", "string"} -- 指令参数格式
    }
}

return M