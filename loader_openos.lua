local fs = require("filesystem")
local shell = require("shell")
--[[local function load_formats()
	local fs = require("filesystem")
	for ent in fs.list("/usr/lib/lcpio/formats") do
		if ent:sub(1, 7) == "format_" and ent:sub(#ent-3) == ".lua" and not fs.isDirectory("/usr/lib/lcpio/formats/"..ent) then
			local f = io.open("/usr/lib/lcpio/formats/"..ent, "r")
			local data = f:read("*a")
			f:close()
			local g = {}
			for k, v in pairs(_G) do
				if k ~= "_G" then
					g[k] = v
				else
					g[k] = g
				end
			end
			g.FORMAT = {}
			local func = load(data, "="..ent, "t", g)
			func()
			local fmt = g.FORMAT
			formats[g.FORMAT.id] = fmt
			if (fmt.options) then
				local elements = {}
				for k, v in pairs(fmt.options) do
					local elmt
					if v.type == "option" then
						elmt = parser:option("--"..fmt.id.."-"..k)
						if (v.desc) then
							elmt:description(v.desc)
						end
						if (v.options) then
							elmt:choices(v.options)
						end
						if (v.default) then
							elmt:default(v.default)
						end
					elseif (v.type == "flag") then
						elmt = parser:flag("--"..fmt.id.."-"..k)
						if (v.desc) then
							elmt:description(v.desc)
						end
					end
					table.insert(elements, elmt)
				end
				parser:group("Options for "..fmt.name, table.unpack(elements))
			end
		end
	end
end]]

local local function load_formats()
	for _, path in ipairs(load_dirs) do
		if fs.exists(path) then
			for ent in fs.list(path) do
				--local st = stat.stat(path.."/"..ent)
				if ent:sub(1, 7) == "format_" and ent:sub(#ent-3) == ".lua" and not fs.isDirectory("/usr/lib/lcpio/formats/"..ent) then
					local f = io.open(path.."/"..ent, "r")
					local data = f:read("*a")
					f:close()
					local g = {}
					for k, v in pairs(_G) do
						if k ~= "_G" then
							g[k] = v
						else
							g[k] = g
						end
					end
					g.FORMAT = {}
					g.lcpio = lcpio
					local func = assert(load(data, "="..ent, "t", g))
					func()
					local fmt = g.FORMAT
					if formats[g.FORMAT.id] then goto continue end
					formats[g.FORMAT.id] = fmt
					if (fmt.options) then
						local elements = {}
						local t = {}
						for k, v in pairs(fmt.options) do
							table.insert(t, k)
						end
						table.sort(t)
						for _, k in ipairs(t) do
							local v = fmt.options[k]
							local elmt
							if v.type == "option" then
								elmt = parser:option("--"..fmt.id.."-"..k)
								if (v.desc) then
									elmt:description(v.desc)
								end
								if (v.options) then
									elmt:choices(v.options)
								end
								if (v.default) then
									elmt:default(v.default)
								end
							elseif (v.type == "flag") then
								elmt = parser:flag("--"..fmt.id.."-"..k)
								if (v.desc) then
									elmt:description(v.desc)
								end
							end
							table.insert(elements, elmt)
						end
						parser:group("Options for "..fmt.name, table.unpack(elements))
					end
					::continue::
					table.insert(fmt_list, fmt.id)
				end
			end
		end
	end
	format_option:choices(fmt_list)
end

local function get_stat(path)
	local size = fs.size(path)
	local lmod = fs.lastModified(path)/1000
	local dir = fs.isDirectory(path)
	return {
		dev = 0,
		ino = 0,
		nlink = 1,
		mode = (dir and 0x4000 or 0x8000) | ((dir or path:match("%.lua$")) and 0x49 or 0) | 0x1A4,
		uid = 0,
		gid = 0,
		rdev = 0,
		size = size,
		atime = lmod,
		mtime = lmod,
		ctime = lmod,
		blksize = 512,
		blocks = math.ceil(size/512)
	}
end

local function openfile(path)
	return io.open(path, "wb")
end

local function setperms(path, st)
	
end

local function mkdir(path)
	--lcpio.warning(path)
	fs.makeDirectory(shell.getWorkingDirectory().."/"..path)
end

local function mkdir_p(path)
	mkdir(path)
end

local function fopen_w(path)
	return io.open(path, "wb")
end

local function fopen_r(path)
	return io.open(path, "rb")
end

local function chdir(path)
	shell.setWorkingDirectory(path)
end

local function readlink(path)
	return fs.isLink(path)
end