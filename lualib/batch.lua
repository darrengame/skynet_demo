--- 批处理模块
local timer = require "timer"
local log = require "log"

local traceback = debug.traceback
local unpack = table.unpack

local all_batch_tasks = {} -- taskid -> taskinfo
local all_batch_tash_cnt = 0 -- 待处理任务数

local M = {}

-- 判断任务是否在执行中
function M.is_task_running(tid)
    return all_batch_tasks[tid] or false
end

-- 创建一个新的任务
local function new_empty_batch_task(tid)
    local info = {}
    all_batch_tasks[tid] = info
    all_batch_tash_cnt = all_batch_tash_cnt + 1
    return info
end

-- 任务心跳循环
local function batch_task_heartbeat(tid)
    local info = all_batch_tasks[tid]
    if not info then return end

    local task_cnt = #info.klist
    local sidx = info.deal_idx + 1
    if info.deal_idx > task_cnt then
        -- 处理完了就提前退出
        M.remove_batch_task(tid)
        return
    end

    local eidx = sidx + info.step - 1
    if eidx > task_cnt then
        eidx = task_cnt
        M.remove_batch_task(tid)
    else
        -- 没有处理完就继续开启定时器等下次再处理
        info.deal_idx = eidx
        info.timer = timer.timeout(info.interval, batch_task_heartbeat, tid)
    end

    -- 处理本次循环需要执行的逻辑
    for i = sidx, eidx do
        local ok, err = xpcall(info.fun, traceback, info.klist[i], unpack(info.args, 1, info.args.n))
        if not ok then
            log.error("run batch task error. tid:", tid, ", key:", info.klist[i], ", err:", err)
        end
    end
end

-- 删除一个任务
function M.remove_batch_task(tid)
    if all_batch_tasks[tid] and all_batch_tasks[tid].timer then
        -- 取消定时器
        timer.cancel(all_batch_tasks[tid].timer)
    end
    all_batch_tasks[tid] = nil
    all_batch_tash_cnt = all_batch_tash_cnt - 1
end

-- klist, 是一个合法的 array 类型的table, 可以使用 util_table.keys 产生
function M.new_batch_task(tid, interval, step, klist, cbfun, ...)
    if interval <= 0 then return false, "invalid interval for batch task." end
    if M.is_task_running(tid) then return true, "batch task alread running." end

    if #klist <= 0 then return true, "empty task list." end

    local info = new_empty_batch_task(tid)
    info.timer = timer.timeout(interval, batch_task_heartbeat, tid) -- 开启定时器，timer 字段为定时器的 ID
    info.deal_idx = 0   -- deal_idx 已处理的数量
    info.klist = klist  -- 批处理数组
    info.interval = interval -- 时间间隔
    info.step = step    -- 每次处理数量
    info.fun = cbfun    -- 处理函数
    info.args = table.pack(...) -- 处理函数参数

    return true
end

return M