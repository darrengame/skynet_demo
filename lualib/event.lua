--- 事件模块
local skynet = require "skynet"
local log = require "log"

local xpcall = xpcall

local M = {}

local handler_inc_id = 1
local dispatchs = {}    -- event type -> callback:{id -> fun}
local handlers = {}     -- handler id -> event type

-- 加入监听列表
function M.add_listener(event_type, fun)
    local callbacks = dispatchs[event_type]
    if not callbacks then
        callbacks = {}
        dispatchs[event_type] = callbacks
    end

    handler_inc_id = handler_inc_id + 1
    local id = handler_inc_id
    callbacks[id] = fun
    handlers[id] = event_type

    return id
end

-- 从监听列表删除
function M.del_listener(id)
    local event_type = handlers[id]
    if not event_type then return end

    handlers[id] = nil
    log.error("delete event listener. type:", event_type, "handler_id:", id)

    local callbacks = dispatchs[event_type]
    if not callbacks then return end
    callbacks[id] = nil
end

--- 触发一个事件
---@param event_type 事件类型
function M.fire_event(event_type, ...)
    local callbacks = dispatchs[event_type]
    if not callbacks or not next(callbacks) then return end

    local result = true
    for id, fun in pairs(callbacks) do
        local ok, err = xpcall(fun, debug.traceback, ...)
        if not ok then
            log.error("fire event error. eventtype:", event_type, ", handler_id:", id, ", err:", err)
            result = false
        end
    end
    return result
end

return M