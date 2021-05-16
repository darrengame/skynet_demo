local skynet = require "skynet"
local log = require "log"

local traceback = debug.traceback
local tpack = table.pack
local tunpack = table.unpack
local collectgarbage = collectgarbage
local xpcall = xpcall

local M = {}

local is_init = false
local timer_inc_id = 1
local cur_frame = 0
local timer2frame = {}
local frame2callouts = {}
local timer_size = 0
local frame_size = 0
local last_mem = 0
local step_men = 100

local function del_timer(id)
    if not timer2frame[id] then return end

    local frame = timer2frame[id]
    local callouts = frame2callouts[frame]
    if not callouts then return end
    if not callouts.timers then return end

    if callouts.timers[id] then
        callouts.timers[id] = nil
        callouts.size = callouts.size-1
    end

    if callouts.size == 0 then
        frame2callouts[frame] = nil
        frame_size = frame_size-1
    end

    timer2frame[id] = nil
    timer_size = timer_size - 1
end

local function init_callout(id, sec, f, args, is_repeat)
    local fixframe
    local _frame = sec
    if _frame == 0 then
        _frame = 1
    end

    fixframe = cur_frame + _frame

    local callouts = frame2callouts[fixframe]
    if not callouts then
        callouts = {timers = {}, size = 1}
        frame2callouts[fixframe] = callouts
        frame_size = frame_size+1
    else
        callouts.size = callouts.size + 1
    end

    callouts.timers[id] = {f, args, is_repeat, sec}
    timer2frame[id] = fixframe

    timer_size = timer_size+1

    if timer_size == 50000 then
        log.warn("timer is to many!!!")
    end
end

local function timer_loop()
    local diff = collectgarbage("count") - last_mem
    last_mem = last_mem + diff
    if diff > 1 then
        local step = step_men + (diff/10)//1
        if step > 2048 then
            step = 2048
        end
        step_men = step
        collectgarbage("step", step_men)
    else
        local step = (step_men*0.9)//1
        if step < 100 then
            step = 100
        end
        step_men = step
        collectgarbage("step", step_men)
    end

    skynet.timeout(100, timer_loop)
    cur_frame = cur_frame + 1
    
    if timer_size <= 0 then return end

    local callouts = frame2callouts[cur_frame]
    if not callouts then return end

    if callouts.size <= 0 then
        frame2callouts[cur_frame] = nil
        frame_size = frame_size - 1
    end

    for id, info in pairs(callouts.timers) do
        local f = info[1]
        local args = info[2]
        local ok, err = xpcall(f, traceback, tunpack(args, 1, args.n))
        if not ok then
            log.error("crontab is run is error:", err)
        end

        del_timer(id)

        local is_repeat = info[3]
        if is_repeat then
            local sec = info[4]
            init_callout(id, sec, f, args, true)
        end
    end
    if frame2callouts[cur_frame] then
        frame2callouts[cur_frame] = nil
        frame_size = frame_size-1
    end
end

function M.exist(id)
    if timer2frame[id] then
        return true
    end
    return false
end

function M.timeout(sec, f, ...)
    assert(sec > 0)

    timer_inc_id = timer_inc_id+1
    init_callout(timer_inc_id, sec, f, tpack(...), false)
    return timer_inc_id
end

function M.cancel(id)
    del_timer(id)
end

function M.timeout_repeat(sec, f, ...)
    assert(sec > 0)
    timer_inc_id = timer_inc_id+1
    init_callout(timer_inc_id, sec, f, tpack(...), true)
    return timer_inc_id
end

function M.get_remain(id)
    local frame = timer2frame[id]
    if frame then
        -- 每帧都1秒
        return frame - cur_frame
    end
    return -1
end

function M.show()
    log.info("timer_size:", timer_size, ", frame_size:", frame_size)
    local util_table = require "util.table"
    log.info("timer2frame:", util_table.tostring(timer2frame))
    log.info("frame2callouts:", util_table.tostring(frame2callouts))
end

if not is_init then
    skynet.timeout(100, timer_loop)
    log.info("timer init succ.")
    is_init = true
end

return M