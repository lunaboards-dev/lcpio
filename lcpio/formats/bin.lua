local fmt = {}
fmt.long_name = "binary cpio"
fmt.magicsize = 2
fmt.align = 2
fmt.widths = {
    mtime = 32,
    size = 32,
    uid = 16,
    gid = 16,
    dev = 16,
    rdev = 16,
    nlink = 16,
    ino = 16,
    mode = 16
}

local packstr = "HHHHHHHHHHHHH"

local magic = 0x71c7

function fmt:detect(mgk)
    if string.unpack(">H", mgk) == magic then
        self.endian = ">"
        return true
    elseif string.unpack("<H", mgk) == magic then
        self.endian = "<"
        return true
    end
end

function fmt:read(file)
    local header = file:read(packstr:packsize())
	local e = "<"
	local mgk = string.unpack("<H", header)
	if mgk ~= magic then
		e = ">"
	end
	if string.unpack(e.."H", header) ~= magic then
		lcpio.error("malformed header: bad magic")
	end
	local ent = {}
	ent.magic, ent.dev, ent.ino, ent.mode, ent.uid, ent.gid, ent.nlink, ent.rdev, ent.mtime_hi, ent.mtime_lo, ent.namesize, ent.filesize_hi, ent.filesize_lo = string.unpack(e..packstr, header)
	ent.mtime = (ent.mtime_hi << 16) | ent.mtime_lo
	ent.size = (ent.filesize_hi << 16) | ent.filesize_lo
	local name = file:read(ent.namesize)
	if name:sub(ent.namesize, ent.namesize) ~= "\0" then
		lcpio.error("malformed header: name is not null terminated")
	end
	ent.name = name:sub(1, ent.namesize-1)
	if ent.namesize & 1 > 0 then
		file:skip(1)
	end
	if ent.name == "TRAILER!!!" then
		return
	end
	return ent
end

function fmt:write(file, stat)
    --[[if stat.size & 0xFFFFFFFF ~= stat.size then
		lcpio.error("overflow: %s: %d > %d", stat.name, stat.size, 0xFFFFFFFF)
	end]]
    --lcpio.debug("reported size: %d", stat.size)
	local fz_hi, fz_lo = stat.size >> 16, stat.size & 0xFFFF
	local mt_hi, mt_lo = stat.mtime >> 16, stat.mtime & 0xFFFF
	-- lmao stat.ino can overflow, probably not a good thing
    -- ^ not anymore!
	file:write(packstr:pack(magic, stat.dev, stat.ino & 0xFFFF, stat.mode, stat.uid, stat.gid, stat.nlink, stat.rdev, mt_hi, mt_lo, #stat.name + 1, fz_hi, fz_lo))
	file:write(stat.name.."\0")
    lcpio.debug("writeout: %s", stat.name)
end

function fmt:leadout(file)
    self:write(file, {
        ino = 0,
        dev = 0,
        gid = 0,
        uid = 0,
        mtime = 0,
        size = 0,
        name = "TRAILER!!!",
        nlink = 0,
        rdev = 0,
        mode = 0
    })
end

return fmt