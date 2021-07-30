local skynet = require "skynet"
local log = require "log"
local json = require "json"
local db_op = require "ws_agent.db_op"
local db_cache = require "db_cache"
local gm = require "ws_agent.gm.main"
local timer = require "timer"
local search_mod = require "ws_agent.search"

local M = {} -- 模块接口
local RPC = {} -- 协议绑定处理函数

local WATCHDOG
local GATE
local fd2uid = {} -- fd 和 uid 绑定
local online_users = {} -- {[uid]=user} -- 在线玩家
local user_alive_keep_time = 10 -- 10秒超时断连

function M.init(gate, watchdog)
    GATE = gate
    WATCHDOG = watchdog
    db_op.init_db()

    -- 初始化 gm 模块
    gm.init()

    -- 注册 gm 协议
    M.regist_rpc(gm.RPC)

    -- 初始化 search 模块
    search_mod.init()
end

-- 返回协议给客户端
function M.send_res(fd, res)
    -- local msg = json.encode(res)
    skynet.call(GATE, "lua", "response", fd, res)
end

function M.login(acc, fd)
    assert(not fd2uid[fd], string.format("Already Logined. acc:%s, fd:%s", acc, fd))

    -- 从数据库加载数据
    local uid = db_op.find_and_create_user(acc)
    local user = {
        fd = fd,
        acc = acc,
    }
    online_users[uid] = user
    fd2uid[fd] = uid

    -- 通知 gate 以后消息由 agent 接管
    skynet.call(GATE, "lua", "forward", fd)

    -- 心跳定时器检查
    local timer_id = timer.timeout_repeat(user_alive_keep_time, M.check_user_online, uid)
    user.timer_id = timer_id

    -- 获取玩家信息
    local userinfo = db_cache.call_cached("get_userinfo", "user", "user", uid)

    log.info("Login Success. acc:", acc, ", fd:", fd)
    local res = {
        uid = uid,
        name = userinfo.name,
        lv = userinfo.lv,
        exp = userinfo.exp,
    }
    return {user = res}
end

function M.disconnect(fd)
    local uid = fd2uid[fd]
    if uid then
        local user = online_users[uid]
        -- 离线，清理定时器
        timer.cancel(user.timer_id)

        online_users[uid] = nil
        fd2uid[fd] = nil
    end
end

function M.close_fd(fd)
    skynet.send(GATE, "lua", "kick", fd)
    M.disconnect(fd)
end

function M.get_uid(fd)
    return fd2uid[fd]
end

-- 协议分发
function M.handle_proto(req, fd, uid)
    -- 根据协议 ID 找到对应的处理函数
    local func = RPC[req.content]
    if not func then
        log.error("proto RPC ID can't find:", req.content)
        return
    end
    local res = func(req, fd, uid)
    return res
end

-- 注册 GMRPC 处理函数
function M.regist_rpc(rpc)
    for k, v in pairs(rpc) do
        RPC[k] = v
    end
end

-- 检查是否在线
function M.check_user_online(uid)
    local user = online_users[uid]
    if not user then
        return
    end

    local now = skynet.time()
    if now - user.heartbeat >= user_alive_keep_time then
        -- 超时踢掉
        log.debug("user time out kick:", uid)
        M.close_fd(user.fd)
    end
end

-- 修改玩家名字
function M.set_username(uid, username)
    local ret = db_cache.call_cached("set_username", "user", "user", uid, username)
    if ret then
        -- 更新数据库里的名字用于搜索
        db_op.update_username(uid, username)
    end

    return ret
end

-- 消息处理
function RPC.c2s_echo(req, fd, uid)
    local res = {
        pid = "s2c_echo",
        msg = req.msg,
        uid = uid,
    }
    return res
end
--[[ 
    获取玩家名字
    {
        "pid": "c2s_get_username"
    }
]]
function RPC.c2s_get_username(req, fd, uid)
    local username = db_cache.call_cached("get_username", "user", "user", uid)
    local res = {
        pid = "s2c_get_username",
        username = username,
    }
    return res
end
--[[ 
    修改玩家名字
    {
        "pid": "c2s_set_username",
        "username": "shiyanlou"
    }
 ]]

function RPC.c2s_set_username(req, fd, uid)
    -- local ret, err = db_cache.call_cached("set_username", "user", "user", uid, req.username)
    M.set_username(uid, req.username)
    local res = {
        pid = "s2c_set_username",
        username = req.username
    }
    return res
    -- if ret then
    -- else
    --     return false, err
    -- end
end

function RPC.ping(req, fd, uid)
    local user = online_users[uid]
    if not user then
        log.error("RPC ping error: user id:", uid)
        return
    end
    user.heartbeat = skynet.time()
    -- log.info("RPC ping:", req.time, user.heartbeat, user.heartbeat - req.time)
    local res = {
        time = user.heartbeat
    }
    return {pong=res}
end

return M