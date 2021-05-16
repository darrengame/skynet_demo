-- 道具
local event = require "event"
local event_type = require "cached.event_type"
local mng = require "cached.mng"
local skynet = require "skynet"
local log = require "log"

local M = {}
local CMD = {}

-- 初始化回调
local function init_cb(uid, cache)
    if not cache.items then
        cache.items = {}
    end
end

--- 接收玩家升级事件
---@param uid 用户uid
---@param lv 等级
local function on_uplevel(uid, lv)
    log.debug("on_uplevel. uid:", uid, ", lv:", lv)
end

function M.init()
    -- 注册初始化回调
    mng.regist_init_cb("user", "item", init_cb)
    -- 注册 cache 操作函数
    mng.regist_cmd("user", "item", CMD)
    -- 监听事件
    event.add_listener(event_type.EVENT_TYPE_UPLEVEL, on_uplevel)
end

return M