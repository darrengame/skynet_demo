-- 模糊搜索
local skynet = require "skynet"
local lru_cache = require "lru_cache"
local db_op = require "ws_agent.db_op"

local M = {}
local lru_cache_data

function M.init()
    -- 先尝试取 cache 里的数据
    local search_max_cache = tonumber(skynet.getenv("search_max_cache"))
    lru_cache_data = lru_cache.new(search_max_cache)
end

function M.search(name)
    -- 先尝试取 cache 里的数据
    local now = skynet.time()
    local cache_ret = lru_cache_data:get(name)
    if cache_ret and cache_ret.expire > now and cache_ret.search_list then
        return cache_ret.search_list
    end

    -- 从数据库里搜索数据，然后存入 cache
    local limit = tonumber(skynet.getenv("search_limit"))
    local search_list = db_op.find_by_name(name, limit)
    local expire = tonumber(skynet.getenv("search_expire"))
    lru_cache_data:set(name, {expire = now + expire, search_list = search_list})

    return search_list
end

return M