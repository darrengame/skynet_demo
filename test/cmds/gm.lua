local websocket = require "http.websocket"
local json = require "json"

local M = {}

function M.run_command(ws_id, ...)
    local cmd = table.concat({...}, " ")
    local req = {
        pid = "c2s_gm_run_cmd",
        cmd = cmd,
    }
    websocket.write(ws_id, json.encode(req))
end

return M