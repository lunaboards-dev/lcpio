local fmt = {}
fmt.align = 1
fmt.noxd = true
fmt.long_name = "minitel tar"

fmt.widths = {
	size = 16
}

FORMAT.options = {
	["mixed-versions"] = {
		type="option",
		options={"allowed","permissive","strict"},
		default="permissive",
		desc="Tells lcpio if it should allow mixed format versions or even create archives with mixed versions. Note that setting to `allowed` is not recommended and will be incompatible with strict implementations."
	},
	--[[["endian"] = {
		type="option",
		options = {"big", "little", "system"},
		default = "big",
		desc = "Force archive endian. This may be required for some archives as mtar has no native endian detection field."
	},
	["endian-check"] = {
		type="flag",
		desc="On write, this inserts a zero-byte filed called `.lcpio-endian-check` at the beginning for use as an endian check. On read, it uses it to check the endianess of a file. This file is tossed out regardless if the flag is enabled or not."
	},]]
	["version"] = {
		type="option",
		options = {"0", "1"},
		desc = "Specifies version to use for creating an archive.",
		default = "1"
	}
}

function fmt:detect(magic)
	return magic:sub(1,3) == "\xFF\xFF\1"
end

function fmt:init()
	--self.endian = endians[self.args.endian]
	self.endian = ">"
	--print(self.args.endian)
	if (self.args.mixed_versions == "allowed") then
		lcpio.warning("mixed versions are incompatible with strict implementations (--mtar-mixed-versions=allowed)")
	end
end

function fmt:read(file)
	lcpio.debug("a bytes: "..file.bytes)
	local d = file:read(2)
	local namesize_raw = d
	local name
	if (d == "\xff\xff") then
		lcpio.debug("found magic!")
		local v = file:read(1):byte()
		lcpio.debug("version: "..v)
		lcpio.debug("b bytes: "..file.bytes)
		if (v == 0 and self.args.mixed_versions == "strict") then lcpio.error("entry specifies version 0! (--mtar-mixed-versions=strict)") end
		if (self.file_version == v) then goto read_version end -- fuck it, just skip everything
		if (self.file_version and self.file_version ~= v and self.args.mixed_versions == "strict") then
			lcpio.error("mixed versions are forbidden (--mtar-mixed-versions=strict)")
		elseif self.file_version and self.file_version ~= v and not self.warned then
			lcpio.warning("mixed versions are incompatible with strict implementations")
			self.warned = true
		end
		self.file_version = v
		if self.file_version > 1 then
			lcpio.error(string.format("unknown version %d (we only support 0 and 1)", self.version))
		end
		::read_version::
		namesize_raw = file:read(2)
		lcpio.debug("c bytes: "..file.bytes)
		lcpio.debug(string.format("dump: %.2x%.2x", namesize_raw:byte(1, 2)))
	elseif (d == "\0\0") then
		return
	elseif (self.file_version == 1) then
		if self.args.mixed_versions == "strict" then
			lcpio.error("mixed versions are forbidden (--mtar-mixed-versions=strict)")
		elseif not self.warned then
			lcpio.warning("mixed versions are incompatible with strict implementations")
			self.warned = true
		end
	elseif not self.file_version then
		self.file_version = 0
	end
	--[[if (self.args.endian_check and not self.checked) then
		lcpio.debug("checking endian.")
		self.checked = true
		if namesize_raw == "\0\19" or namesize_raw == "\19\0" then
			local tname = file:read(19)
			if (tname == ".lcpio-endian-check") then
				if namesize_raw == "\0\19" then
					self.endian = ">"
				else
					self.endian = "<"
				end
			else
				-- While I doubt there'd ever be a file name 4864 characters long, there might be
				local namesize = string.unpack(self.endian.."H", namesize_raw)
				if namesize ~= 19 then
					name = name .. file:read(4845) -- lmao
				end
				goto not_endian_check
			end
		end
		local skip = 0
		if (self.file_version == 1) then
			skip = string.unpack(self.endian.."l", file:read(8))
		else
			skip = string.unpack(self.endian.."H", file:read(2))
		end
		file:skip(skip)
		return self:read(file)
	end]]
	::not_endian_check::
	local namesize = string.unpack(self.endian.."H", namesize_raw)
	lcpio.debug("namesize: "..namesize)
	lcpio.debug("d bytes: "..file.bytes)
	--io.stderr:write(self.file_version,"\t",namesize,"\n")
	local name = file:read(namesize)
	--print(name)
	local fsize
	if self.file_version == 1 then
		fsize = string.unpack(self.endian.."l", file:read(8))
	else
		fsize = string.unpack(self.endian.."H", file:read(2))
	end
	return {
		mode = 0x81a4,
		size = fsize,
		name = name
	}
end

function fmt:write(file, stat)
	if (self.args.mixed_versions == "allowed") then -- pain
		if (stat.size <= 0xFFFE) then
			file:write(string.pack(self.endian .. "H", #stat.name)..stat.name..string.pack(self.endian.."H", stat.size))
		else
			file:write("\xFF\xFF\1"..string.pack(self.endian .. "H", #stat.name)..stat.name..string.pack(self.endian .. "l", stat.size))
		end
	elseif (self.args.version == "1") then
		file:write("\xFF\xFF\1"..string.pack(self.endian .. "H", #stat.name)..stat.name..string.pack(self.endian .. "l", stat.size))
	else
		file:write(string.pack(self.endian .. "H", #stat.name)..stat.name..string.pack(self.endian.."H", stat.size))
	end
end

function fmt:write_leadout(file)
	--[[if (self.args.version == 1) then
		file:write("\xFF\xFF\1\0\0\0\0\0\0\0\0\0\0")
	else]]
		file:write("\0\0\0\0")
	--end
end
