FORMAT.magicsize = 2
FORMAT.detectable = true
FORMAT.name = "binary cpio"
FORMAT.id = "bin"
FORMAT.align = 2

local magic = 0x71c7

local packstr = "HHHHHHHHHHHHH"

function FORMAT:detect(mgk)
	return string.unpack(">H", mgk) == magic or string.unpack("<H", mgk) == magic
end

function FORMAT:read(file)
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

function FORMAT:write(file, stat)
	if stat.size & 0xFFFFFFFF ~= stat.size then
		lcpio.error("overflow: %s: %d > %d", stat.name, stat.size, 0xFFFFFFFF)
	end
	local fz_hi, fz_lo = stat.size >> 16, stat.size & 0xFFFF
	local mt_hi, mt_lo = stat.mtime >> 16, stat.mtime & 0xFFFF
	file:write(packstr:pack(magic, stat.dev, stat.ino, stat.mode, stat.uid, stat.gid, stat.nlink, stat.rdev, mt_hi, mt_lo, #stat.name + 1, fz_hi, fz_lo))
	file:write(stat.name.."\0")
	if (#stat.name+1) & 1 > 0 then
		file:write("\0")
	end
end

function FORMAT:write_leadout(file)
	self:write(file, {
		dev = 0,
		ino = 0,
		mode = 0,
		uid = 0,
		gid = 0,
		nlink = 0,
		rdev = 0,
		mtime = 0,
		size = 0,
		name = "TRAILER!!!"
	})
end