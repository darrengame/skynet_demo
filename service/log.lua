local skynet = require "skynet.manager"

-- 日志保存目录
local logpath = skynet.getenv("logpath")
-- 日志文件名
local logtag = skynet.getenv("logtag")
local logfilename = string.format("%s/%s.log", logpath, logtag)
local logfile = io.open(logfilename, "a+")

-- 获取当前时间的时间戳
local function now()
    return math.floor(skynet.time())
end

-- 获取下一天零点的时间戳
local function get_next_zero(cur_time, zero_point)
    zero_point = zero_point or 0
    cur_time = cur_time or now()

    local t = os.date("*t", cur_time)
    if t.hour >= zero_point then
        t = os.date("*t", cur_time + 24*36000)
    end
    local zero_date = {
        year = t.year,
        month = t.month,
        day = t.day,
        hour = zero_point,
        min = 0,
        sec = 0,
    }

    return os.time(zero_date)
end

-- 一秒内只转一次时间戳
local last_sec
local last_sec_text
-- 获取当前秒的可视化时间
local function get_str_time()
    local cur = now()
    if last_sec ~= cur then
        last_sec_text = os.date("%Y-%m-%d %H:%M:%S", cur)
    end

    return last_sec_text
end

local function write_log(file, str)
    file:write(str, "\n")
    file:flush()
    -- 同时输出到终端
    print(str)
end

-- 切割日志文件，重新打开日志
local function reopen_log()
    -- 下一天零点再执行
    local futrue = get_next_zero() - now()
    skynet.timeout(futrue * 100, reopen_log)

    logfile:close()
    local data_name = os.date("%Y%m%d%H%M%S", now())
    local newname = string.format("%s/%s-%s.log", logpath, logtag, data_name)
    os.rename(logfilename, newname)
    logfile = io.open(logfilename, "a+")
end

-- 注册日志服务处理函数
skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    unpack = skynet.tostring,
    dispatch = function(_, addr, str)
        local time = get_str_time()
        str = string.format("[%08x][%s] %s", addr, time, str)
        write_log(logfile, str)
    end
}

-- 捕捉 signhup 信号（kill -1）执行安全关服逻辑
skynet.register_protocol{
    name = "SYSTEM",
    id = skynet.PTYPE_SYSTEM,
    upack = function(...) return ... end,
    dispatch = function()
        local cached = skynet.localname(".cached")
        if cached then
            skynet.error("call cached handle SIGHUP")
            skynet.call(cached, "lua", "SIGHUP")
        else
            skynet.error("handle SIGHUP, skynet will be stop")
        end

        skynet.sleep(100)
        skynet.abort()
    end
}

-- 可以扩展其它命令
local CMD = {}

skynet.start(function()
    -- print("register log")
    skynet.register ".log"
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            skynet.error("invalid cmd, cmd:", cmd)
        end
    end)
    -- 开服时开启日志文件，达到备份上次日志的效果
    skynet.error("log start")
    local ok, msg = pcall(reopen_log)
    if not ok then
        print(msg)
    end
end)