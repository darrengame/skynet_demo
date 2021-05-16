local skynet = require "skynet"
local md5 = require "md5"
local log = require "log"
local timer = require "timer"

local M = {}    -- 模块接口
local RPC = {}  -- 协议绑定处理函数

local AGENT
local GATE
local TIMEOUT_AUTH = 10 -- 认证超时 10s
local noauth_fds = {}   -- 未通过认证的客户端

-- 标记哪些协议不需要登录就能访问
local no_auth_proto_list = {
    c2s_login = true,
}

local function timeout_auth(fd)
    local ti = noauth_fds[fd]
    if not ti then return end

    local now = skynet.time()
    if now - ti < TIMEOUT_AUTH then
        return
    end
    M.close_fd(fd)
end

local function check_sign(token, acc, sign)
    local checkstr = token..acc
    local checksum = md5.sumhexa(checkstr)

    return checksum == sign
end

--[[
    登录协议处理
    {
    "pid": "c2s_login",
    "token": "token",
    "acc": "玩家账号",
    "sign": "校验码"
    }
 ]]
function RPC.c2s_login(req, fd)
    -- token 验证
    if not check_sign(req.token, req.acc, req.sign) then
        log.debug("login failed. token:", req.token, ", acc:", req.acc, ", sing:", req.sign)
        M.close_fd(fd)
        return
    end
    -- 验证通过，分配agent
    local res = skynet.call(AGENT, "lua", "login", req.acc, fd)
    -- 从超时队列移除
    noauth_fds[fd] = nil
    return res
end

function M.is_no_auth(pid)
    return no_auth_proto_list[pid]
end

function M.init(gate, agent)
    GATE = gate
    AGENT = agent
end

-- 协议接收
function M.handle_proto(req, fd)
    -- 根据协议 ID 找到对应的处理函数
    local func = RPC[req.pid]
    if not func then
        log.error("proto RPC ID can't find:", req.pid)
        return
    end
    local res = func(req, fd)
    return res
end

function M.open_fd(fd)
    noauth_fds[fd] = skynet.time()
    -- log.debug("open fd auth:", TIMEOUT_AUTH+1, timeout_auth == nil)
    timer.timeout(TIMEOUT_AUTH+1, timeout_auth, fd)
end

function M.close_fd(fd)
    skynet.send(GATE, "lua", "kick", fd)
    skynet.send(AGENT, "lua", "disconnect", fd)
    noauth_fds[fd] = nil
end

function M.check_auth(fd)
    return (not noauth_fds[fd])
end

return M