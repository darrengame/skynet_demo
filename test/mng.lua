local M = {}

local uid

function M.set_uid(_uid)
    uid = _uid
end

function M.get_uid()
    return uid
end

return M