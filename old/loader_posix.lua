local dirent = require("posix.dirent")
local stat = require("posix.sys.stat")
local unistd = require("posix.unistd")
local utime = require("posix.utime")
local fcntl = require("posix.fcntl")
local stdio = require("posix.stdio")
local pwd = require("posix.pwd")
local grp = require("posix.grp")

platform.add_load_directories("./formats", "/usr/share/lcpio/formats")

function platform.list_dir(path)
	local e = dirent.dir(path)
	table.sort(e)
	return e
end

function platform.stat(path)
	local st, e = stat.lstat(path)
	if not st then return nil, e end
	local s = {
		dev = st.st_dev,
		ino = st.st_ino,
		inode = st.st_ino,
		nlink = st.st_nlink,
		mode = st.st_mode,
		uid = st.st_uid,
		gid = st.st_gid,
		rdev = st.st_rdev,
		size = st.st_size,
		atime = st.st_atime,
		mtime = st.st_mtime,
		ctime = st.st_ctime,
		blksize = st.st_blksize,
		blocks = st.st_blocks,
		name = path
	}
	local t = s.mode & 0xF000
	if t ~= 0x8000 and t ~= 0xA000 then
		s.size = 0
	end
	return s
end

local function load_formats()
	for _, path in ipairs(load_dirs) do
		if stat.stat(path) then
			local ents = dirent.dir(path)
			table.sort(ents)
			for _, ent in ipairs(ents) do
				local st = stat.stat(path.."/"..ent)
				if stat.S_ISREG(st.st_mode) > 0 then
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
	local st = stat.lstat(path)
	local s = {
		dev = st.st_dev,
		ino = st.st_ino,
		inode = st.st_ino,
		nlink = st.st_nlink,
		mode = st.st_mode,
		uid = st.st_uid,
		gid = st.st_gid,
		rdev = st.st_rdev,
		size = st.st_size,
		atime = st.st_atime,
		mtime = st.st_mtime,
		ctime = st.st_ctime,
		blksize = st.st_blksize,
		blocks = st.st_blocks,
		name = path
	}
	local t = s.mode & 0xF000
	if t ~= 0x8000 and t ~= 0xA000 then
		s.size = 0
	end
	return s
end

function platform.openfile(path, mode)
	return io.open(path, mode or "r")
end

local function setperms(path, st)
	stat.chmod(path, st.mode & 0xFFF)
	if st.uid and st.gid then unistd.chown(path, st.uid, st.gid) end
	if st.mtime then utime.utime(path, st.mtime//1, st.atime and st.atime//1 or st.mtime//1) end
end

local function mkdir(path)
	local ok, err = pcall(stat.mkdir, path)
	if not ok then
		lcpio.error(err)
	end
end

local function mkdir_p(path)
	path = "/"..path
	local parts = {}
	for part in path:gmatch("/([^/]+)") do
		--lcpio.warning(part)
		if (part ~= "" and part ~= "." and part ~= "..") then
			table.insert(parts, part)
		elseif (part == "..") then
			table.remove(parts)
		end
	end
	--local path = "/"
	local path = ""
	for i=1, #parts do
		path = path .. "/" .. parts[i]
		if path:sub(1,1) == "/" then
			path = path:sub(2)
		end
		--lcpio.warning(path)
		--lcpio.warning(parts[i])]
		--local ok, rv = stat.stat(path)
		--lcpio.warning(tostring(ok)..tostring(rv))
		if not stat.stat(path) then
			--lcpio.warning("making directory for "..path)
			local ok, err = pcall(stat.mkdir, path)
			if not ok then
				lcpio.error(err)
			end
		end
	end
end

local function fopen_w(path)
	local fd, err, code = fcntl.open(path, fcntl.O_WRONLY | fcntl.O_CREAT)
	if not fd then
		lcpio.error(err, code)
	end
	return stdio.fdopen(fd, "w")
end

local function fopen_rw(path)
	local fd, err, code = fcntl.open(path, fcntl.O_RDWR)
	if not fd then
		lcpio.error(err, code)
	end
	return stdio.fdopen(fd, "r+")
end

local function fopen_r(path)
	local fd, err, code = fcntl.open(path, fcntl.O_RDONLY)
	if not fd then
		lcpio.error(err, code)
	end
	return stdio.fdopen(fd, "r")
end

local function chdir(path)
	unistd.chdir(path)
end

local function readlink(path)
	unistd.readlink(path)
end

local function lookup_gid(gid)
	return grp.getgrgid(gid).gr_name
end

local function lookup_uid(uid)
	return pwd.getpwuid(uid).pw_name
end