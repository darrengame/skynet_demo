local skynet = require "skynet"

skynet.start(function()
    -- 所有服务的启动入口
    skynet.error("Sever start")
    if not skynet.getenv('daemon') then
        -- 如果不是daemon模式启动则开启console服务
        skynet.newservice("console")
    end
    -- 开启 debug consolo 服务
    skynet.newservice("debug_console", 8000)

    -- 开启 ws_watchdog 服务
    local ws_watchdog = skynet.newservice("ws_watchdog")

    -- 配置 websockect 协议和端口
    local ws_protocol = skynet.getenv("ws_protocol")
    local ws_port = skynet.getenv("ws_port")
    local max_online_client = skynet.getenv("max_online_client")

    -- 通知 ws_watchdog 启动服务
    skynet.call(ws_watchdog, "lua", "start", {
        port = ws_port,
        maxclient = tonumber(max_online_client),
        nodelay = true,
        protocol = ws_protocol,
    })
    skynet.error("websocket watchdog listen on", ws_port)
    -- main 服务只作为入口，启动完所需的服务后就完成使命，可以退出了
    skynet.exit()
end)