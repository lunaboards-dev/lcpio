FORMAT.magicsize = 6
FORMAT.detectable = true
FORMAT.name = "Hex ASCII cpio"
FORMAT.id = "newc"
FORMAT.align = 4
FORMAT.options = {
	["crc"] = {
		type="flag",
		desc="Use crc format"
	}
}
local packstr = -- here we go...
	"c6" .. -- magic
	"c8" .. -- inode
	"c8" .. -- mode
	"c8" .. -- uid
	"c8" .. -- gid
	"c8" .. -- nlink
	"c8" .. -- mtime
	"c8" .. -- filesize
	"c8" .. -- dev major
	"c8" .. -- dev minor
	"c8" .. -- rdev major
	"c8" .. -- rdev minor
	"c8" .. -- namesize
	"c8" -- checksum

local function tohex(i)
	return string.format("%.8x", i)
end

local magic = "070701"

function FORMAT:detect(mgk)
	return mgk:sub(1, 6) == "070701"
end

function FORMAT:read(file)
	local ent = {}
	local dat = file:read(packstr:packsize())
	if not dat or #dat ~= packstr:packsize() then lcpio.error("unexpected eof") end
	ent.magic, ent.ino, ent.mode, ent.uid, ent.gid, ent.nlink, ent.mtime, ent.filesize, ent.dev_maj, ent.dev_minor, ent.rdev_major, ent.rdev_minor, ent.namesize, ent.crc = string.unpack(packstr, dat)
	if ent.magic ~= magic then lcpio.error(string.format("bad magic (%s ~= %s)", ent.magic, magic)) end
	for k, v in pairs(ent) do
		ent[k] = tonumber(v, 16)
	end
	local t_name = file:read(ent.namesize)
	ent.name = t_name:sub(1, ent.namesize-1)
	--file:skip(1)
	if t_name:sub(ent.namesize, ent.namesize) ~= "\0" then
		lcpio.error("malformed header: name is not null terminated")
	end
	if ((packstr:packsize() + ent.namesize) & 3 > 0) then
		file:skip(4 - ((packstr:packsize() + ent.namesize) & 3))
	end
	if ent.name == "TRAILER!!!" then return end
	return {
		inode = ent.ino,
		uid = ent.uid,
		gid = ent.gid,
		nlink = ent.nlink,
		mtime = ent.mtime,
		size = ent.filesize,
		name = ent.name,
		mode = ent.mode
	}
end

function FORMAT:write(file, stat)
	local name = stat.name .. "\0"
	file:write(packstr:pack(
		magic,
		tohex(stat.inode),
		tohex(stat.mode),
		tohex(stat.uid),
		tohex(stat.gid),
		tohex(stat.nlink),
		tohex(stat.mtime),
		tohex(stat.size),
		tohex(0), -- TODO: single dev number to major/minor
		tohex(0),
		tohex(0),
		tohex(0),
		tohex(#name),
		tohex(0)
	))
	file:write(name)
	if ((packstr:packsize() + #name) & 3 > 0) then
		file:write(string.rep("\0", 4 - ((packstr:packsize() + #name) & 3)))
	end
end

function FORMAT:write_leadout(file)
	self:write(file, {
		inode = 0,
		mode = 0,
		uid = 0,
		gid = 0,
		nlink = 0,
		mtime = 0,
		size = 0,
		name = "TRAILER!!!"
	})
end

function FORMAT:check(file)

end