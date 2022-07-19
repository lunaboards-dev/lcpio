-- Only read support.
local fmt = {}
fmt.readonly = true
fmt.align = 2
fmt.magicsize = 2
fmt.long_name = "64-bit cpio"

local packstr = "HHHHHHIIIlllll"

local mag = 0x79E7
local mag_rev = 0xE779

function fmt:detect(magic)
	local mgk = string.unpack("H", magic:sub(1, 2))
	return mgk == mag or mgk == mag_rev
end

function fmt:read(file)
	local mgk_raw = file:read(2)
	local e = "<"
	if string.unpack("<H", mgk_raw) ~= mag then
		e = ">"
	end
	if string.unpack(e.."H", mgk_raw) ~= mag then
		lcpio.error(string.format("bad magic (%x ~= %x)", string.unpack(e.."H", mgk_raw), mag))
	end
	local ent = {}
	ent.magic, ent.dev, ent.mode, ent.nlink, ent.rdev, ent.namesize, ent.ino, ent.uid, ent.gid, ent.filesize, ent.atime, ent.ctime, ent.btime, ent.mtime = string.unpack(e..packstr, mgk_raw..file:read(packstr:packsize()-2))
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
		btime = ent.btime,
		mtime = ent.mtime
	}
end

return fmt