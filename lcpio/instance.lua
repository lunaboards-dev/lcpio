local tags = require("lcpio.tags")
local cpio_io = require("lcpio.cpio_io")
local instance = {}

local inst = {}

function instance.copy_out(stream, args)
    if args.format.init then args.format:init() end
    return setmetatable({
        format = args.format,
        noxd = args.noxd or args.format.noxd,
        total_shards = 0,
        handle = stream,
        blksize = args.blksize or 512,
        write = true
    }, {__index=inst})
end

function instance.copy_in(stream, args)
    if args.format.init then args.format:init() end
    return setmetatable({
        format = args.format,
        noxd = args.noxd or args.format.noxd,
        handle = stream,
        blksize = args.blksize or 512,
        read = true
    }, {__index=inst})
end

--#region Copy in
local xtd_map = {
    ["size"] = "true_size",
    ["atime"] = "atime",
    ["mtime"] = "mtime",
    ["ctime"] = "ctime",
    ["btime"] = "btime"
}
--- Reads the next file in the archive and returns the stat.
function inst:next_file()
    if not self.read then lcpio.error("internal error: read op on write stream") end
    local stat = self.format:read(self.handle)
    if not stat then return end
    cpio_io.align(self)
    if self.xmd then
        if self.format.widths.mtime then stat.mtime = self.xmd.mtime << self.format.widths.mtime | stat.mtime end
        if self.format.widths.atime then stat.atime = self.xmd.atime << self.format.widths.atime | stat.atime end
        if self.format.widths.ino then stat.ino = self.xmd.ino << self.format.widths.ino | stat.ino end
        if self.format.widths.gid then stat.gid = self.xmd.gid << self.format.widths.gid | stat.gid end
        if self.format.widths.uid then stat.uid = self.xmd.uid << self.format.widths.uid | stat.uid end
        self.xmd = nil
    end
    --lcpio.warning("%s %s =? %s", self.xtd, self.xtd_for, stat.name)
    if self.xtd and self.xtd_for == stat.name then
        for k, v in pairs(self.xtd) do
            --lcpio.warning("%s\t%s\t%s\t%q", k, xtd_map[k], type(v), v)
            if xtd_map[k] then
                stat[xtd_map[k]] = v
            end
        end
        self.xtd = nil
    end
    if not self.noxd then
        if stat.name:sub(1, 4) == "!!/X" then
            local extension = stat.name:sub(4, 7)
            local path = stat.name:sub(9)
            if extension == "XMD0" then
                self.xmd = stat
                --self.xtd = stat.tags
                self.handle:skip(self.xmd.size)
                cpio_io.align(self)
                return self:next_file()
            elseif extension == "XFD0" then
                local xfd_path = path:gsub("%.part%d+$", "")
                if not self.last_file then
                    lcpio.error("xfd with no parent (xfd wants %s)", xfd_path)
                elseif self.last_file ~= xfd_path then
                    lcpio.error("xfd path mismatch (%s != %s)", xfd_path, self.last_file)
                else
                    stat.xfd = true
                    return stat
                end
            elseif extension == "XTD0" then
                local fpath, ext = path:match("(.+)%.([^%.]+)$")
                local fmt = ext:lower()
                local decoder = lcpio.tagging[fmt]
                if ext == ext:upper() and not decoder then lcpio.error("%s: unknown tagging format %s", fpath, fmt) end
                if decoder then
                    -- parse
                    local dat = self:read_data(stat.size)
                    local tags = decoder.decode(dat)
                    self.xtd = tags
                    self.xtd_for = fpath
                else
                    self.handle:skip(stat.size)
                end
                cpio_io.align(self)
                return self:next_file()
            end
        end
    end
    self.last_file = stat.name
    return stat
end

function inst:read_data(amt)
    return self.handle:read(amt)
end

--#endregion Copy in

--#region Copy out

function inst:add_file(stat)
    self.format:write(self.handle, stat)
    cpio_io.align(self)
end

function inst:write_data(data)
    self.handle:write(data)
end

function inst:leadout()
    self.format:leadout(self.handle)
    cpio_io.align(self)
    self.handle:close()
end

--function inst:close()
    

--#endregion Copy out

function inst:count()
    return self.handle:count()
end

return instance