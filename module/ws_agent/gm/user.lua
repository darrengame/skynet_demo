local db_cache = require "db_cache"
local log = require "log"
local skynet = require "skynet"
local json = require "json"
local search_mod = require "ws_agent.search"
local util_table = require "util.table"
local mng = require "ws_agent.mng"

local M = {}

-- 修改玩家名字指令实现
local function set_name(uid, name)
    -- local ret, err = db_cache.call_cached("set_username", "user", "user", uid, name)
    local ret = mng.set_username(uid, name)
    log.debug("set name:", uid, name, ret)
    if ret then
        return true, "set name succ"
    end

    return false
end

-- 添加经验
local function add_exp(uid, exp)
    local newlv, newexp = db_cache.call_cached("add_exp", "user", "user", uid, exp)
    if newlv then
        return true, string.format("add exp succ. newlv:%s, newexp:%s", newlv, newexp)
    end
    return false, "add exp failed"
end

local function broadcast_msg(msg)
    local res = {
        pid = "s2c_msg",
        msg = msg,
    }
    skynet.call(".ws_gate", "lua", "broadcast", json.encode(res))
end

local function search(name)
    local ret_list = search_mod.search(name)
    log.info("search:", util_table.tostring(ret_list))
end

-- 指令参数配置
M.CMD = {
    setname = { -- 指令名
        fun = set_name, -- 指令实现逻辑
        args = {"uid", "string"} -- 指令参数格式
    },
    addexp = { -- 指令名
        fun = add_exp, -- 指令实现逻辑
        args = {"uid", "number"} -- 指令参数格式
    },
    bmsg = {
        fun = broadcast_msg,
        args = {"string"}
    },
    search = {
        fun = search,
        args = {"string"},
    }
}

return M