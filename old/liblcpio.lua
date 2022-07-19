-- Soon(tm)

local lcpio = {}

--#include "buffered_file.lua"

local formats = {}

local arc_write = {}
local arc_read = {}

local function getargs(fmt, alist)
	local args = {}
	for k, v in pairs(alist) do
		if k:sub(1, #fmt+1) == fmt.."_" then
			args[k:sub(#fmt+2)] = v
		end
	end
	return args
end

function arc_write:format(format, args)
	if not format then format = "bin" end
	if not formats[format] then lpcio.error("format "..format.." not found") end
	self.fmt = setmetatable({args=args and getargs(fmt, args) or {}}, {__index=formats[format]})
	if self.fmt.init then self.fmt:init() end
end

function arc_write:write_stat(file_stat, ...)
	if not self.fmt then lcpio.error("format not set") end
	self.fmt:write(self.file, file_stat, ...)
end

function arc_write:write(data)
	if not self.fmt then lcpio.error("format not set") end
	self.file:write(data)
end

function arc_write:align()
	if not self.fmt then lcpio.error("format not set") end
	local pos = self.file:tell()
	local skip = self.fmt.align - (pos % self.fmt.align)
	if skip > 0 and skip ~= self.fmt.align then
		self.file:write(string.rep("\0", skip))
	end
end

function arc_write:close()
	if not self.fmt then lcpio.error("format not set") end
	self.fmt:write_leadout(self.file)
	local p = self.file:tell()
	self.file:close()
	return p
end

local function file_autodetect(bf)
	if (args.format ~= "auto") then return formats[args.format] end
	local max_size = 0
	for k, v in pairs(formats) do
		if v.magicsize > max_size then
			max_size = v.magicsize
		end
	end
	local buffer = file:read(max_size)
	read_bytes = max_size
	while true do
		for k, v in pairs(formats) do
			if v:detect(buffer) then
				file.buffer = buffer
				return v
			end
		end
		read_bytes = read_bytes + 1
		local next_c = file:read(1)
		if not next_c or next_c == "" then lcpio.error("archive not recognized.") end
		buffer = buffer:sub(2)..next_c
	end
end

function arc_read:format(format, args)
	lcpio.debug("format(): entry")
	if not format then
		local max_size = 0
		for k, v in pairs(formats) do
			if v.detectable then
				if v.magicsize > max_size then
					max_size = v.magicsize
				end
			end
		end
		--lcpio.warning(max_size)
		local buf = self.file:read(max_size)
		local skipped_amt = 0
		while true do
			for k, v in pairs(formats) do
				if v.detectable and v.detect then
					if v:detect(buf) then
						self.file.buffer = buf
						self.file.bytes = skipped_amt
						self.fmt = setmetatable({}, {__index=v})
						--lcpio.warning("format set to "..k)
						goto detected
					end
				end
			end
			skipped_amt = skipped_amt + 1
			local next_c = self.file:read(1)
			if not next_c or next_c == "" then lcpio.error("archive not recognized") end
			buf = buf:sub(2)..next_c
		end
		::detected::
	else
		local fmt = formats[format]
		if not fmt then
			lcpio.error("unknown format "..format)
		end
		self.fmt = setmetatable({}, {__index=fmt})
	end
	if not self.fmt then lcpio.error("format detected but not loaded! (internal VM error?)") end
	self.loaded = true
	self.fmt.args = args and getargs(fmt, args) or {}
	if self.fmt.init then self.fmt:init() end
	lcpio.debug(string.format("format(): exit %s %s", tostring(self.fmt), tostring(self.loaded)))
end

function arc_read:read_stat()
	if not self.fmt and self.loaded then lcpio.error("loaded without format! (internal lua vm error?)") end
	if not self.fmt then lcpio.error("format not set") end
	return self.fmt:read(self.file)
end

function arc_read:read(amt)
	if not self.fmt and self.loaded then lcpio.error("loaded without format! (internal lua vm error?)") end
	if not self.fmt then lcpio.error("format not set") end
	return self.file:read(amt)
end

function arc_read:skip(amt)
	if not self.fmt and self.loaded then lcpio.error("loaded without format! (internal lua vm error?)") end
	if not self.fmt then lcpio.error("format not set") end
	self.file:skip(amt)
end

function arc_read:files()
	if not self.fmt and self.loaded then lcpio.error("loaded without format! (internal lua vm error?)") end
	if not self.fmt then lcpio.error("format not set") end
	return function()
		return self:read_stat()
	end
end

function arc_read:close()
	if not self.fmt and self.loaded then lcpio.error("loaded without format! (internal lua vm error?)") end
	if not self.fmt then lcpio.error("format not set") end
	local p = self.file:tell()
	self.file:close()
	return p
end

function arc_read:align()
	if not self.fmt and self.loaded then lcpio.error("loaded without format! (internal lua vm error?)") end
	if not self.fmt then lcpio.error("format not set") end
	local pos = self.file:tell()
	local skip = self.fmt.align - (pos % self.fmt.align)
	if skip > 0 and skip ~= self.fmt.align then
		self.file:skip(skip)
	end
end

function lcpio.open(mode, path)
	local file
	if mode ~= "r" and mode ~= "w" then lcpio.error("bad mode "..mode) end
	if type(path) == "string" then
		file = io.open(path, mode.."b")
	elseif type(path) == "userdata" and tostring(path):sub(1, 6) == "file (" then
		file = path
	else
		if mode == "r" then
			file = io.stdin
		else
			file = io.stdout
		end
	end

	local atype = ({r=arc_read, w=arc_write})[mode]
	
	return setmetatable({file=create_bf(file, "", not path)}, {__index=atype})
end

function lcpio.add_format(format)
	formats[format.id] = format
end

function lcpio.get_formats()
	return formats
end

function lcpio.error(err)
	error(err)
end

function lcpio.warning(msg)
	io.stderr:write("warning: "..msg.."\n")
	io.stderr:write(debug.traceback(2).."\n")
end

function lcpio.debug(msg)
	if lcpio.debug_mode then
		io.stderr:write("debug: "..msg.."\n")
		io.stderr:write(debug.traceback(2).."\n")
	end
end

return lcpio