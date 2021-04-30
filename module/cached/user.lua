local mng = require "cached.mng"
local data_lvexp = require "data.lvexp"
local event = require "event"
local event_type = require "cached.event_type"

local M = {}
local CMD = {}

-- 初始化回调
local function init_cb(uid, cache)
    if not cache.username then
        cache.username = "New Player"
    end
    if not cache.lv then
        cache.lv = 1
    end
    if not cache.exp then
        cache.exp = 0
    end
end

-- 获取下一级经验
local function get_next_lv(lv)
    local newlv = lv+1
    local cfg = data_lvexp[newlv]
    if not cfg then
        return false
    end
    return true, newlv, cfg.exp
end

function CMD.get_username(uid, cache)
    return cache.username
end

function CMD.set_username(uid, cache, username)
    cache.username = username
    return true
end

-- 获取玩家信息
function CMD.get_userinfo(uid, cache)
    local userinfo = {
        username = cache.username,
        lv = cache.lv,
        exp = cache.exp,
    }
    return userinfo
end

-- 添加经验
function CMD.add_exp(uid, cache, exp)
    M.add_exp(uid, cache, exp)
    return cache.lv, cache.exp
end

function M.init()
    -- 注册初始化回调
    mng.regist_init_cb("user", "user", init_cb)
    -- 注册 cache 操作函数
    mng.regist_cmd("user", "user", CMD)
end

-- 加经验接口
function M.add_exp(uid, cache, exp)
    cache.exp = cache.exp + exp
    local lvchanged = false
    while true do
        local lv = cache.lv
        local cur_exp = cache.exp
        local succ, newlv, need_exp = get_next_lv(lv)
        if succ and need_exp <= cur_exp then
            cur_exp = cur_exp - need_exp
            cache.exp = cur_exp
            cache.lv = newlv
            lvchanged = true
        else
            break
        end
    end

    -- 数据同步给客户端
    local res = {
        pid = "s2c_update_lvexp",
        lv = cache.lv,
        exp = cache.exp,
    }
    mng.send_to_client(uid, res)

    -- TODO:发出等级变化事件通知
    if lvchanged then
        event.fire_event(event_type.EVENT_TYPE_UPLEVEL, uid, cache.lv)
    end
end

return M