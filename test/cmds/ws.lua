local websocket = require "http.websocket"
local json = require "json"
local mng = require "test.mng"
local md5 = require "md5"

local M = {}
local CMD = {}
local RPC = {}

function CMD.login(ws_id, acc)
    local token = "token"
    local checkstr = token..acc
    local sign = md5.sumhexa(checkstr)
    local req = {
        pid = "c2s_login",
        acc = acc,
        token = token,
        sign = sign
    }
    websocket.write(ws_id, json.encode(req))
end

function CMD.echo(ws_id, msg)
    local req = {
        pid = "c2s_echo",
        msg = msg,
    }
    websocket.write(ws_id, json.encode(req))
end

function M.handle_res(ws_id, res)
    local f = RPC[res.pid]
    if f then
        f(ws_id, res)
    end
end

function M.run_command(ws_id, cmd, ...)
    local f = CMD[cmd]
    if not f then
        print("not exist cmd", cmd)
        return
    end
    f(ws_id, ...)
end

function M.getname(ws_id)
    local req = {
        pid = "c2s_get_username"
    }
    websocket.write(ws_id, json.encode(req))
end

function M.setname(ws_id, name)
    local req = {
        pid = "c2s_set_username",
        username = name,
    }
    websocket.write(ws_id, json.encode(req))
end

function RPC.s2c_login(ws_id, res)
    mng.set_uid(res.uid)
end

return M