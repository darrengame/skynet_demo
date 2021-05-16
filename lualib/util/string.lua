local gsub = string.gsub

local M = {}

function M.split(str, reps)
    local rt = {}
    local i = 0
    gsub(str, '[^'..reps..']+', function(w)
        i = i+1
        rt[i] = w
    end)
    return rt
end

return M