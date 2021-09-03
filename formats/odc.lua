FORMAT.magicsize = 6
FORMAT.detectable = true
FORMAT.name = "Octal ASCII cpio"
FORMAT.id = "odc"
FORMAT.align = 1

local magic = "070707"

local packstr = "c6c6c6c6c6c6c6c6c11c6c11"

local function toint(i, long)
	--lcpio.warning(lcpio.toint(i, 8, 6))
	if long then
		return lcpio.toint(i, 8, 11)
	else
		return lcpio.toint(i, 8, 6)
	end
end

function FORMAT:detect(mgk)
	return mgk:sub(1, 6) == magic
end

function FORMAT:read(file)
	local mgk, dev, ino, mode, uid, gid, nlink, rdev, mtime, namesize, fsize = packstr:unpack(file:read(packstr:packsize()))
	if mgk ~= magic then
		lcpio.error(string.format("bad magic (%s ~= %s)", mgk, magic))
	end
	local name = file:read(tonumber(namesize, 8))
	if name:sub(#name, #name) ~= "\0" then
		lcpio.error("malformed header: name is not null-terminated.")
	end
	if name == "TRAILER!!!\0" then return end
	return {
		dev = tonumber(dev, 8),
		ino = tonumber(ino, 8),
		mode = tonumber(mode, 8),
		uid = tonumber(uid, 8),
		gid = tonumber(gid, 8),
		nlink = tonumber(nlink, 8),
		rdev = tonumber(rdev, 8),
		mtime = tonumber(mtime, 8),
		size = tonumber(fsize, 8),
		name = name:sub(1, #name)
	}
end

function FORMAT:write(file, stat)
	file:write(packstr:pack(
		magic,
		toint(stat.mode),
		toint(stat.ino),
		toint(stat.mode),
		toint(stat.uid),
		toint(stat.gid),
		toint(stat.nlink),
		toint(stat.rdev),
		toint(stat.mtime, true),
		toint(#stat.name+1),
		toint(stat.size, true)
	))
	file:write(stat.name.."\0")
end

function FORMAT:write_leadout(file)
	self:write(file, {
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