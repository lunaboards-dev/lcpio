FORMAT.magicsize = 2
FORMAT.detectable = true
FORMAT.name = "64-bit cpio"
FORMAT.id = "cpio64"
FORMAT.align = 2

local packstr = "HHHHHHIIIlllll"

local mag = 0x79E7
local mag_rev = 0xE779

function FORMAT:detect(magic)
	local mgk = string.unpack("H", magic:sub(1, 2))
	return mgk == mag or mgk == mag_rev
end

function FORMAT:init()

end

function FORMAT:read(file)
	local mgk_raw = file:read(2)
	local e = "<"
	if string.unpack("<H", mgk_raw) ~= mag then
		e = ">"
	end
	if string.unpack(e.."H", mgk_raw) ~= mag then
		lcpio.error(string.format("bad magic (%x ~= %x)", string.unpack(e.."H", mgk_raw), mag))
	end
	local ent = {}
	ent.magic, ent.dev, ent.mode, ent.nlink, ent.rdev, ent.namesize, ent.ino, ent.uid, ent.gid, ent.filesize, ent.atime, ent.ctime, ent.otime, ent.mtime = string.unpack(e..packstr, mgk_raw..file:read(packstr:packsize()-2))
	ent.name = file:read(ent.namesize)
	if ent.name:sub(ent.namesize, ent.namesize) == "\0" then
		ent.name = ent.name:sub(1, ent.namesize - 1)
	end
	if (ent.namesize & 1 > 0) then
		--lcpio.warning("skip")
		file:skip(1)
	end
	--lcpio.warning(string.format("namesize: %d", ent.namesize))
	if (ent.name == "TRAILER!!!") then
		return
	end
	return {
		dev = ent.dev,
		mode = ent.mode,
		nlink = ent.nlink,
		rdev = ent.rdev,
		name = ent.name,
		inode = ent.ino,
		uid = ent.gid,
		gid = ent.gid,
		size = ent.filesize,
		atime = ent.atime,
		ctime = ent.ctime,
		otime = ent.otime,
		mtime = ent.ctime
	}
end

function FORMAT:write(file, stat)
	file:write(packstr:pack(mag, stat.dev, stat.mode, stat.nlink, stat.rdev, #stat.name+1, stat.inode, stat.uid, stat.gid, stat.size, stat.atime, stat.ctime, stat.otime or stat.mtime, stat.mtime))
	file:write(stat.name.."\0")
	if ((#stat.name+1) & 1 > 0) then
		file:write("\0")
	end
end

function FORMAT:write_leadout(file)
	--[[file:write(packstr:pack(
		mag,
		0,
		0,
		0,
		0,
		11,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0
	).."TRAILER!!!\0\0")]]
	self:write(file, {
		dev = 0,
		mode = 0,
		nlink = 0,
		rdev = 0,
		name = "TRAILER!!!",
		inode = 0,
		uid = 0,
		gid = 0,
		size = 0,
		atime = 0,
		ctime = 0,
		otime = 0,
		mtime = 0
	})
end