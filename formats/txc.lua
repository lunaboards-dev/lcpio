local pwd = require("posix.pwd")
local grp = require("posix.grp")

FORMAT.magicsize = 4
FORMAT.align = 2
FORMAT.detectable = true
FORMAT.name = "tagged extendable cpio"
FORMAT.id = "txc"
FORMAT.options = {
	["minimal-info"] = {
		type = "flag",
		desc = "Tells lcpio to only store the needed info for file i/o."
	},
	--[[["preserve-xattr"] = {
		type = "flag",
		desc = "Tells lcpio to preserve extended attributes."
	},]]
	["spoof-host"] = {
		type = "option",
		desc = "Spoofs the host tag."
	},
	["override-tags"] = {
		type = "option",
		desc = "Only write the specified tags.",
		default = "cpio,host"
	}
}

local magic = 0x54584361
--[[
	struct txc_header {
		uint32_t size_lo;
		uint32_t tagsize;
		uint16_t mode;
		uint16_t namesize;
		struct txc_tag tags[];
	}
	struct txc_tag {
		char tag[4];
		uint16_t size;
		char data[];
	}
	i once again use PNG chunk naming conventions
]]

local header = "IIHH"
local tag = "c4H"

local function taginfo(name)
	return {
		ancillary = name:byte(1) & 32 > 0,
		private = name:byte(2) & 32 > 0,
		resv = name:byte(3) & 32 > 0,
		safetocopy = name:byte(4) & 32 > 0
	}
end

local tags = {
	["SIZE"] = function(endinan, hdr, data)
		hdr.filesize = hdr.filesize | (string.unpack(endian.."I", data) << 32)
	end,
	["tIME"] = function(endian, hdr, data)
		hdr.mtime, hdr.atime, hdr.ctime, hdr.btime = string.unpack(endian.."llll", data)
	end,
	["oWNr"] = function(endian, hdr, data)
		hdr.uid, hdr.gid = string.unpack(endian.."II", data)
	end,
	["oNAm"] = function(endian, hdr, data)
		hdr.user, hdr.group = data:match("([^;]+);(.+)")
	end,
	["xATr"] = function(endian, hdr, data)
		local k, v = data:match("([^=]+)=(.+)")
		hdr.xattr = hdr.xattr or {}
		hdr.xattr[k] = v
	end,
	["fORk"] = function(endian, hdr, data)
		hdr.fork = true
	end,
	["dEVi"] = function(endian, hdr, data)
		hdr.dev_maj, hdr.dev_min = string.unpack(endian.."II", data)
	end,
	["RDEv"] = function(endian, hdr, data)
		hdr.rdev_maj, hdr.rdev_min = string.unpack(endian.."II", data)
	end,
	["iNOD"] = function(endian, hdr, data)
		hdr.inode = string.unpack(endian.."l", data)
	end,
	["hOSt"] = function(endian, hdr, data)
		hdr.host_os = data
	end,
	--[[
		struct {
			u64 inode;
			u64 mtime;
			u64 atime;
			u64 ctime;
			u64 btime;
			u32 size_hi;
			u32 dev_maj;
			u32 dev_min;
			u32 rdev_maj;
			u32 rdev_min;
		}
	]]
	["lINk"] = function(endian, hdr, data)
		hdr.nlink = string.unpack(endian.."I", data)
	end,
	["CPIO"] = function(endian, hdr, data) -- all together now (for archival purposes)
		local cpio_ent, size_hi, nextb = "lllllIIIII"
		hdr.inode, hdr.mtime, hdr.atime, hdr.ctime, hdr.btime, size_hi,
		hdr.dev_maj, hdr.dev_min, hdr.rdev_maj, hdr.rdev_min, nextb = string.unpack(endian..cpio_ent, data)
		hdr.user, hdr.group = data:match("([^;]+);(.+)", nextb)
	end,
	["EOTs"] = function()
		return true
	end
}

function FORMAT:detect(mgk)
	if not self.tried then
		if string.unpack(">I4", mgk) == magic then
			self.endian = ">"
			return true
		elseif string.unpack("<I4", mgk) == magic then
			self.endian = "<"
			return true
		end
	end
end

local function make_tag(name, data)
	local tag = string.pack("c4H", name, #data)..data
	if #data & 1 > 0 then
		tag = tag .. "\0"
	end
	return tag
end

local known_tags = {
	["time"] = function(hdr)
		return make_tag("tIME", string.pack("llll", hdr.mtime, hdr.atime, 0, 0))
	end,
	["owner"] = function(hdr)
		return make_tag("oWNr", string.pack("II", hdr.uid, hdr.gid))
	end,
	["ownername"] = function(hdr)
		return make_tag("oNAm", pwd.getpwuid(hdr.uid).pw_name..";"..grp.getgrgid(hdr.gid).gr_name)
	end,
	--[[["xattr"] = function(hdr)
		-- good question
	end,]]
	["dev"] = function(hdr)
		return make_tag("dEVi", string.pack("II", hdr.dev >> 8, hdr.dev & 0xFF))
	end,
	["rdev"] = function(hdr)
		return make_tag("RDEv", string.pack("II", hdr.rdev >> 8, hdr.rdev & 0xFF))
	end,
	["nlinks"] = function(hdr)
		return make_tag("lINK", string.pack("I", hdr.nlink))
	end,
	["host"] = function(hdr, f)
		return make_tag("hOSt", f.host or "Linux")
	end,
	["cpio"] = function(hdr)
		return make_tag("CPIO", string.pack("lllllIIIII",
			hdr.inode,
			hdr.mtime,
			hdr.atime,
			0,
			0,
			hdr.size >> 32,
			hdr.dev >> 8,
			hdr.dev & 0xFF,
			hdr.rdev >> 8,
			hdr.dev & 0xFF
		)..pwd.getpwuid(hdr.uid).pw_name..";"..grp.getgrgid(hdr.gid).gr_name)
	end,
	["inode"] = function(hdr)
		return make_tag("iNOD", string.pack("l", hdr.ino))
	end
}

function FORMAT:init()
	local opt_tags = self.args.override_tags
	self.write_tags = {}
	for m in opt_tags:gmatch("[^,]+") do
		if not known_tags[m] then
			lcpio.error("Unknown tag `"..m.."`!")
		end
		table.insert(self.write_tags, known_tags[m])
	end
	if self.args.minimal_info then
		self.write_tags = {}
	end
	if self.args.spoof_host then
		self.host = self.args.spoof_host
	else
		local un = require("posix.sys.utsname").uname()
		self.host = un.sysname .. " " .. un.nodename .. " " .. un.release .. " " .. un.version .." " .. un.machine
	end
end

function read_tag(f, hdr, endian, file)
	local name, size = string.unpack(endian..tag, file:read(tag:packsize()))
	local info = taginfo(name)
	local tagreader = tags[name]
	if not tagreader and not info.ancillary then
		lcpio.error("Unable to decode critical tag `"..name.."`!")
	elseif info.resv then
		lcpio.error("Unable to decode tag with reserved bit set `"..name.."`!")
	elseif not f.priv_warned and info.private then
		lcpio.warning("This archive contains private tags.")
		f.priv_warned = true
	end
	local data = file:read(size)
	-- alrign
	if #data & 1 > 0 then
		file:skip(1)
	end
	return tagreader(endian, hdr, data)
end

function read_tags(f, hdr, endian, file)
	while not read_tag(f, hdr, endian, file) do end -- lmao
end

function FORMAT:read(file)
	if not self.first then
		file:skip(4)
		self.first = true
	end
	local hdr, tagsize, namesize = {}
	hdr.filesize, tagsize, hdr.mode, namesize = string.unpack(self.endian..header, file:read(header:packsize()))
	if tagsize > 0 then
		read_tags(self, hdr, self.endian, file)
	end
	hdr.name = file:read(namesize):gsub("\0$", "")
	if namesize & 1 > 0 then
		file:skip(1)
	end
	if hdr.user then
		local u = pwd.getpwnam(hdr.user)
		if u then
			hdr.uid = u.pw_uid
		end
		local g = grp.getgrnam(hdr.group)
		if g then
			hdr.gid = g.gr_gid
		end
	end
	if hdr.name == "TRAILER!!!" then
		return
	end
	return {
		mode = hdr.mode,
		uid = hdr.uid,
		gid = hdr.gid,
		nlink = hdr.nlink,
		name = hdr.name,
		inode = hdr.inode,
		size = hdr.filesize,
		atime = hdr.atime,
		ctime = hdr.ctime,
		otime = hdr.btime,
		mtime = hdr.mtime
	}
end

function FORMAT:write(file, stat, notag)
	if not self.first then
		file:write(string.pack("I", magic))
		self.first = true
	end
	local tags = ""
	if notag ~= "notag" then
		if stat.size > 0xFFFFFFFF then
			tags = make_tag("SIZE", string.pack(stat.size >> 32))
			stat.size = stat.size & 0xFFFFFFFF
		end
		for i=1, #self.write_tags do
			tags = tags .. self.write_tags[i](stat, self)
		end
		if #tags > 0 then
			tags = tags .. make_tag("EOTs", "")
		end
	end
	file:write(string.pack("IIHH", stat.size, #tags, stat.mode, #stat.name)..tags..stat.name)
	if #stat.name & 1 > 0 then
		file:write("\0")
	end
end

function FORMAT:write_leadout(file)
	self:write(file, {
		size = 0,
		mode = 0,
		name = "TRAILER!!!"
	}, "notag")
end