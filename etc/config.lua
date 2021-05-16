local skynet = require "skynet"

local M = {}

function M.get_db_conf()

    local ip = skynet.getenv("db_ip")
    local port = skynet.getenv("db_port")
    local dbuser = skynet.getenv("db_user")
    local dbpwd = skynet.getenv("db_pwd")
    local authdb = skynet.getenv("db_authdb")

    local cfg = {host = ip, port = port}
    if dbuser and dbpwd then
        cfg.username = dbuser
        cfg.password = dbpwd
    end
    cfg.authdb = authdb

    return cfg
end

function M.get_tbl(key)
    local s = skynet.getenv(key)
    if type(s) == "string" then
        s = load("return " .. s)()
    end
    return s
end

return M