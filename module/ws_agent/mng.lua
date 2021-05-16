local skynet = require "skynet"
local log = require "log"
local json = require "json"
local db_op = require "ws_agent.db_op"
local db_cache = require "db_cache"

local M = {} -- 模块接口
local RPC = {} -- 协议绑定处理函数

local WATCHDOG
local GATE
local fd2uid = {} -- fd 和 uid 绑定
local online_users = {} -- {[uid]=user} -- 在线玩家

function M.init(gate, watchdog)
    GATE = gate
    WATCHDOG = watchdog
    db_op.init_db()
end

-- 返回协议给客户端
function M.send_res(fd, res)
    local msg = json.encode(res)
    skynet.call(GATE, "lua", "response", fd, msg)
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

    log.info("Login Success. acc:", acc, ", fd:", fd)
    local res = {
        pid = "s2c_login",
        uid = uid,
        msg = "Login Success",
    }
    return res
end

function M.disconnect(fd)
    local uid = fd2uid[fd]
    if uid then
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
    local func = RPC[req.pid]
    if not func then
        log.error("proto RPC ID can't find:", req.pid)
        return
    end
    local res = func(req, fd)
    return res
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
    db_cache.call_cached("set_username", "user", "user", uid, req.username)
    local res = {
        pid = "s2c_set_username",
        username = req.username
    }
    return res
end

return M