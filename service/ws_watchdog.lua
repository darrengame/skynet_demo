local skynet = require "skynet"
local mng = require "ws_watchdog.mng"
local json = require "json"
local log = require "log"
local util_table = require "util.table"

local GATE
local AGENT
local SOCKET = {}
local CMD = {}

function SOCKET.open(fd, addr)
    log.debug("New client from:", addr)
    mng.open_fd(fd)
end

function SOCKET.close(fd)
    log.debug("socket close", fd)
    mng.close_fd(fd)
end

function SOCKET.error(fd, msg)
    log.debug("socket error", fd, msg)
    mng.close_fd(fd)
end

function SOCKET.warning(fd, size)
    log.warn("socket warning", fd, size, "K")
end

function SOCKET.data(fd, req)
    log.debug("socket data", fd, req)
    -- 解析客户端消息，pid为协议ID
    -- local req = json.decode(msg)
    if not req.content then
        log.error("Unknow proto. fd:", fd, ", req:", req)
        return
    end
    -- 判断客户端是否已经认证
    if not mng.check_auth(fd) then
        -- 没有通过认证且不是登录协议则踢下线
        if not mng.is_no_auth(req.content) then
            log.warn("auth failed. fd:", fd, ", req:", req)
            mng.close_fd(fd)
            return
        end
    end
    -- 协议处理逻辑
    local res = mng.handle_proto(req, fd)
    if res then
        skynet.call(GATE, "lua", "response", fd, res)
    end
end

function CMD.start(conf)
    -- 开启 gate 服务
    skynet.call(GATE, "lua", "open", conf)
end

function CMD.kick(fd)
    -- 踢下线
    mng.close_fd(fd)
end

skynet.start(function()
    -- 服务入口
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            f(...)
        else
            local f = assert(CMD[cmd])
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)

    -- 启动 ws_gate 服务
    GATE = skynet.newservice("ws_gate")
    -- 启动 ws_agent 服务
    AGENT = skynet.newservice("ws_agent")
    mng.init(GATE, AGENT)
    skynet.call(AGENT, "lua", "init", GATE, skynet.self())
end)