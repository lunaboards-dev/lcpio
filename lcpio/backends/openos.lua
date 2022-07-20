-- OpenComputers backend, for friends and stuff.
local computer = lcpio.prequire("computer", true)
local fs = lcpio.prequire("filesystem", true)

local backend = {}

backend.separator = "/"
backend.force_synth_ino = true
backend.paths = {
    "/usr/lib/lcpio2"
}

function backend.detect()
    return fs and computer
end

function backend.exists(path)
    return fs.exists
end

function backend.stat(path)
    if fs.exists(path) then
        local mtime = fs.lastModified(path)
        if os.date("*t", mtime).year > 2100 then -- this should give us some time to figure this bug out
            mtime = mtime // 1000
        end
        if fs.isDirectory(path) then
            return {
                mode = 0x41ed,
                size = 0,
                dev = 0,
                rdev_maj = 0,
                rdev_min = 0,
                dev_maj = 0,
                dev_min = 0,
                nlinks = 2,
                ino = 0,
                uid = 1000,
                gid = 1000,
                mtime = mtime,
                atime = mtime,
                ctime = 0
            }
        else
            return {
                mode = 0x81a4,
                size = fs.size(path),
                dev = 0,
                rdev_maj = 0,
                rdev_min = 0,
                dev_maj = 0,
                dev_min = 0,
                nlinks = 1,
                ino = 0,
                uid = 1000,
                gid = 1000,
                mtime = mtime,
                atime = mtime,
                ctime = 0
            }
        end
    end
end

function backend.name_lookup(stat)
    return string.format("%d", stat.uid), string.format("%d", stat.gid)
end

function backend.dir(path)
    return fs.list(path)
end

return backend