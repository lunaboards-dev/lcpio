FORMAT.magicsize = 2
FORMAT.detectable = true
FORMAT.name = "Tsuki Archive"
FORMAT.id = "tsar"
FORMAT.align = 2

local packstr = "I2I2I2I2I2I6I6"

local magic = 0x5f7d
local magic_rev = 0x7d5f

function FORMAT:detect(magic)
	return (magic:sub(1, 2) == "\x5f\x7d" or magic:sub(1, 2) == "\x7d\x5f")
end

FORMAT.options = {
	["handle-forks"] = {
		type="option",
		desc="Tells lcpio what to do with forks.",
		options = {"ignore", "raw", "dir"},
		default = "ignore"
	},
	["force-endian"] = {
		type="option",
		desc="Forces endian in read/write",
		options = {"big", "little", "system", "auto"},
		default = "auto"
	}
}

function FORMAT:init()
	if (self.args.force_endian == "big") then
		self.endian = ">"
	elseif self.args.force_endian == "little" then
		self.endian = "<"
	elseif self.args.force_endian == "system" then
		self.endian = "="
	end
end

function FORMAT:read(file)
	local ent = {}
	if self.endian then
		ent.magic, ent.namesize, ent.mode, ent.uid, ent.gid, ent.filesize, ent.mtime = string.unpack(self.endian..packstr, file:read(packstr:packsize()))
		for k, v in pairs(ent) do
			lcpio.warning(k..":"..v)
		end
	else
		local mgk = file:read(2)
		if not mgk then lcpio.error("unexpected eof") end
		local e = "<"
		if string.unpack("<H", mgk) ~= magic then
			e = ">"
		end
		if string.unpack(e.."H", mgk) ~= magic then
			lcpio.error(string.format("bad magic 0x%x ~= 0x%x", string.unpack(">H", mgk), magic))
		end
		ent.magic, ent.namesize, ent.mode, ent.uid, ent.gid, ent.filesize, ent.mtime = string.unpack(e..packstr, mgk..file:read(packstr:packsize()-2))
	end
	ent.mtime = ent.mtime / 1000
	ent.name = file:read(ent.namesize)
	if ent.namesize & 1 > 0 then
		file:skip(1)
	end
	if (ent.name == "TRAILER!!!") then
		return
	end
	return {
		name = ent.name,
		mode = ent.mode,
		uid = ent.uid,
		gid = ent.gid,
		size = ent.filesize,
		mtime = ent.mtime
	}
end

function FORMAT:write(file, stat)
	--if stat.mode & 0xF000 ~= 0x4000 then
	file:write(string.pack((self.endian or "")..packstr, magic, #stat.name, stat.mode, stat.uid, stat.gid, stat.size, stat.mtime*1000)..stat.name)
	if (#stat.name & 1 > 0) then
		file:write("\0")
	end
end

function FORMAT:write_leadout(file)
	file:write(string.pack((self.endian or "=") .. packstr,
		0x5f7d,
		10,
		0,
		0,
		0,
		0,
		0
	).."TRAILER!!!")
end
