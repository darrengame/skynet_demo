local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local socketdriver = require "skynet.socketdriver"
local log = require "log"
require "skynet.manager"

local WATCHDOG -- watchdog 服务的地址
local MAXCLIENT = 1000 -- 客户端数量上限

local connection = {} -- fd -> connection : {fd, client, agent, ip, mode}
local forwarding = {} -- agent -> connection

local client_number = 0 -- 在线客户端数量
local nodelay

local CMD = {} -- gate 服务接口
local handler = {} -- websocket 操作接口

local function unforward(c)
    if c.agent then
        forwarding[c.agent] = nil
        c.agent = nil
        c.client = nil
    end
end

local function close_fd(fd)
    local c = connection[fd]
    if c then
        unforward(c)
        connection[fd] = nil
        client_number = client_number-1
    end
end

function handler.connect(fd)
    log.debug("ws connect from:", tostring(fd), client_number, MAXCLIENT)
    if client_number >= MAXCLIENT then
        socketdriver.close(fd)
        return
    end
    if nodelay then
        socketdriver.nodelay(fd)
    end
    client_number = client_number+1
    log.debug("ws connect client number:", client_number)
    local addr = websocket.addrinfo(fd)
    local c = {
        fd = fd,
        ip = addr,
    }
    connection[fd] = c

    skynet.send(WATCHDOG, "lua", "socket", "open", fd, addr)
end

function handler.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    log.debug("ws handshake from:", tostring(fd), ", url:", url, ", addr:", addr)
end

function handler.message(fd, msg)
    log.debug("ws message from:", tostring(fd), ", msg:", msg)
    -- recv a package, forwar it
    local c = connection[fd]
    local agent = c and c.agent
    -- msg is string
    if agent then
        skynet.redirect(agent, c.client, "client", fd, msg)
    else
        skynet.send(WATCHDOG, "lua", "socket", "data", fd, msg)
    end
end

function handler.ping(fd)
    log.debug("ws ping from:", tostring(fd))
end

function handler.pong(fd)
    log.debug("ws pong from:", tostring(fd))
end

function handler.close(fd, code, reason)
    log.debug("ws close from:", tostring(fd), ", code:", code, ", reason:", reason)
    close_fd(fd)
    skynet.send(WATCHDOG, "lua", "socket", "close", fd)
end

function handler.error(fd)
    log.debug("ws error from:", tostring(fd))
    close_fd(fd)
    skynet.send(WATCHDOG, "lua", "socket", "error", fd)
end

function handler.warning(fd, size)
    skynet.send(WATCHDOG, "lua", "socket", "warning", fd, size, "K")
end

function CMD.open(source, conf)
    WATCHDOG = conf.watchdog or source
    MAXCLIENT = conf.maxclient or 1024

    local address = conf.address or "0.0.0.0"
    local port = assert(conf.port)
    local protocol = conf.protocol or "ws"
    nodelay = conf.nodelay
    local fd = socket.listen(address, port)
    log.info(string.format("Listen websocket port:%s protocol:%s", port, protocol))
    socket.start(fd, function(fd, addr)
        log.info(string.format("accept client socket_fd:%s addr:%s", fd, addr))
        websocket.accept(fd, handler, protocol, addr)
    end)
end

function CMD.forward(source, fd, client, addr)
    local c = assert(connection[fd])
    unforward(c)
    c.client = client or 0
    c.agent = addr or source
    forwarding[c.agent] = c
end

function CMD.response(source, fd, msg)
    log.debug("ws response:", tostring(fd), ", msg:", msg)
    websocket.write(fd, msg)
end

function CMD.kick(source, fd)
    websocket.close(fd)
end

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
}

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if not f then
            log.error("simple websocket can't dispatch cmd:", (cmd or nil))
            skynet.ret(skynet.pack({ok=false}))
            return
        end
        if session == 0 then
            f(source, ...)
        else
            skynet.ret(skynet.pack(f(source, ...)))
        end
    end)

    skynet.register(".ws_gate")
    log.info("ws_gate booted.")
end)