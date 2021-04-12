local M = {}

function M.syscmd(cmd)
    local t, popen = {}, io.popen
    local pfile = popen(cmd)
    for l in pfile:lines() do
        table.insert(t, l)
    end
    pfile:close()
    return t
end

function M.syscmdout(cmd)
    local pfile = io.open(cmd)
    local ret = pfile:read("*a")
    pfile:close()
    return ret
end

function M.scandir(directory)
    return M.syscmd('ls "'..directory..'"')
end

function M.mkdir(directory)
    M.syscmd('mkdir -p "'..directory..'"')
end

function M.rmfiles(directory)
    local files = M.syscmd('ls "'..directory..'"')
    for _, fname in pairs(files) do
        local pname = string.format("%s/%s", directory, fname)
        local cmd = string.format('rm -f %q', pname)
        M.syscmd(cmd)
    end
end

function M.rmdir(directory)
    M.fmfiles(directory)
    M.syscmd('rmdir "'..directory..'"')
end

function M.rmfile(fname)
    local cmd = string.format('rm -f %q', fname)
    M.syscmd(cmd)
end

function M.file_save(filename, data)
    local file = io.open(filename, "wb")
    if not file then
        return false
    end

    file.write(data)
    file.close()
    return true
end

function M.file_load(filename)
    local file = io.open(filename, "rb")
    if not file then
        return false
    end

    local data = file:read("*a")
    file:close()
    return data
end

return M