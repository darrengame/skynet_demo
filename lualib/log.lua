local skynet = require "skynet"

local M = {}

local LEVELS = {
    DEBUG = {
        DEBUG = true,
        INFO = true,
        WARN = true,
        ERROR = true,
    },
    INFO = {
        INFO = true,
        WARN = true,
        ERROR = true,
    },
    WARN = {
        WARN = true,
        ERROR = true,
    },
    ERROR = {
        ERROR = true,
    },
}

local loglevel = skynet.getenv("loglevel")
local OUTLOG = LEVELS[loglevel]

function M.debug(...)
    if not OUTLOG.DEBUG then
        return
    end
    skynet.error("[DEBUG]", ...)
end

function M.info(...)
    if not OUTLOG.INFO then
        return
    end
    skynet.error("[INFO]", ...)
end

function M.warn(...)
    if not OUTLOG.WARN then
        return
    end
    skynet.error("[WARN]", ...)
end

function M.error(...)
    if not OUTLOG.ERROR then
        return
    end
    skynet.error("[ERROR]", ...)
    skynet.error("[ERROR]", debug.traceback())
end

return M