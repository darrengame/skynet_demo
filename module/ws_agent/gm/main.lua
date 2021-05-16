local log = require "log"
local M = {}
local RPC = {}
local gm_cmds = {}  -- 指令名：指令实现模块

local function trim(str)
    return str:match("^%s*(.-)%s*$")
end

local function parse_cmd_args(uid, args_format, ...)
    local args = table.pack(...)
    local real_args = {}
    local n = 0

    local parse_cnt = 0
    for i = 1, #args_format do
        local arg_type = args_format[i]
        if arg_type == "uid" then
            n = n+1
            real_args[n] = uid
            goto continue
        elseif arg_type == "string" then
            n = n+1
            parse_cnt = parse_cnt+1
            local arg = args[parse_cnt]
            if not arg then arg = "nil" end
            if arg == "nil" then
                real_args[n] = nil
            else
                real_args[n] = arg
            end
            goto continue
        elseif arg_type == "number" then
            n = n+1
            parse_cnt = parse_cnt+1
            local arg = args[parse_cnt]
            if not arg then arg = "nil" end
            if arg == "nil" then
                real_args[n] = nil
            else
                real_args[n] = tonumber(arg)
            end
            goto continue
        elseif arg_type == "boolean" then
            n = n+1
            parse_cnt = parse_cnt+1
            local arg = args[parse_cnt]
            if arg and arg == "true" then
                real_args[n] = true
            else
                real_args[n] = false
            end
            goto continue
        end
        ::continue::
    end
    return true, n, real_args
end

function M.init()
    -- 引入 user 指令模块
    gm_cmds.user = require "ws_agent.gm.user"
end

function M.do_cmd(CMD, uid, cmd, ...)
    -- 执行命令
    if not cmd then return false, "empty sub cmd." end
    local cb = CMD[cmd]
    if not cb then return false, "unkonw sub cmd:"..cmd end

    local fun = cb.fun
    local args_format = cb.args

    -- 解析参数
    local ok, n, args = parse_cmd_args(uid, args_format, ...)
    if not ok then
        return ok, "invalid sub args."
    end
    -- 执行指令逻辑
    return fun(table.unpack(args, 1, n))
end

M.RPC = RPC

--[[ 
    GM指令
    {
        "pid": "c2s_gm_run_cmd",
        "cmd": "cmd line"
    }
    {
        "pid": "s2c_gm_run_cmd",
        "ok": true,
        "msg": "result msg"
    }
 ]]
function RPC.c2s_gm_run_cmd(req, fd, uid)
    -- 对命令内容做切割
    -- log.debug("c2s_gm_run_cmd:", req.cmd)
    local iter = string.gmatch(trim(req.cmd), "[^ ,]+")
    -- 第一个值为指令名
    local cmd = iter()
    local args = {}
    for v in iter do
        table.insert(args, v)
    end

    local ok
    local msg
    -- 根据命令找到对应的模块
    local m = gm_cmds[cmd]
    if m then
        ok, msg = M.do_cmd(m.CMD, uid, table.unpack(args))
    else
        msg = "invalid cmd!"
    end
    local res = {
        pid = "s2c_gm_run_cmd",
        ok = ok,
        msg = msg,
    }

    return res
end

return M