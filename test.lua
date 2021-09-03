local parser = require("argparse")("lcpio", "lcpio is an extendable cpio utility, written in Lua.")

parser:help_max_width(80)
parser:usage("Usage: lcpio [OPTIONS...] [directories and files...]")



local formats = {}
local fmt_list = {"auto"}

local debug_mode = false

local format_option = parser:option("-H --format", "Use given archive FORMAT"):default("auto")

local lcpio = {}

function lcpio.warning(msg)
	local src = "unknown"
	if (debug.getinfo) then
		local f = debug.getinfo(2).source
		if f:sub(1,1) == "@" or f:sub(1,1) == "=" then
			local m = f:match("([^/=@]+)%.lua$")
			if m then
				src = m
			elseif (f:match "@.*/lcpio") then
				src = "lcpio"
			end
		end
	end
	io.stderr:write(string.format("\27[90;1m(%s)\27[0m \27[93m\27[1mwarning:\27[22m %s\27[0m\n", src, msg))
end

function lcpio.debug(msg)
	if not debug_mode then return end
	local src = "unknown"
	if (debug.getinfo) then
		local f = debug.getinfo(2).source
		if f:sub(1,1) == "@" or f:sub(1,1) == "=" then
			local m = f:match("([^/=@]+)%.lua$")
			if m then
				src = m
			elseif (f:match "@.*/lcpio") then
				src = "lcpio"
			end
		end
	end
	io.stderr:write(string.format("\27[90;1m(%s)\27[0m \27[93m\27[1mdebug:\27[22m %s\27[0m\n", src, msg))
end

function lcpio.error(msg, code)
	code = code or 1
	local src = "unknown"
	if (debug.getinfo) then
		local f = debug.getinfo(2).source
		if f:sub(1,1) == "@" or f:sub(1,1) == "=" then
			local m = f:match("([^/=@]+)%.lua$")
			if m then
				src = m
			elseif (f:match "@.*/lcpio") then
				src = "lcpio"
			end
		end
	end
	io.stderr:write(string.format("\27[90m(%s)\27[0m \27[31m\27[1merror:\27[22m %s\27[0m\n", src, msg))
	os.exit(code)
end

local alpha = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"
function lcpio.toint(n, base, size)
	local str = ""
	while n > 0 do
		local pos = n % base
		str = alpha:sub(pos+1, pos+1) .. str
		n = n // base
	end
	if (size) then
		str = string.rep("0", size-#str) .. str
	end
	return str
end



-- Load formats
local load_dirs = {
	"./formats",
	"/usr/share/lcpio/formats"
}

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

local function load_formats()
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

function get_stat(path)
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

function openfile(path)
	return io.open(path, "wb")
end

function setperms(path, st)
	
end

function mkdir(path)
	--lcpio.warning(path)
	fs.makeDirectory(shell.getWorkingDirectory().."/"..path)
end

function mkdir_p(path)
	mkdir(path)
end

function fopen_w(path)
	return io.open(path, "wb")
end

function fopen_r(path)
	return io.open(path, "rb")
end

function chdir(path)
	shell.setWorkingDirectory(path)
end

function readlink(path)
	return fs.isLink(path)
end
local buffered_file = {}
function buffered_file:read(amt)
	self.bytes = self.bytes + amt
	if (#self.buffer >= amt) then
		local ret = self.buffer:sub(1, amt)
		self.buffer = self.buffer:sub(amt+1)
		return ret
	else
		local ret = self.buffer
		self.buffer = ""
		local fret, err = self.file:read(amt-#ret)
		--self.bytes = self.bytes + amt-#ret
		if not fret then lcpio.error("unexpected eof") end
		return ret..fret
	end
end

function buffered_file:write(data)
	self.bytes = self.bytes + #data
	self.file:write(data)
end

function buffered_file:skip(amt)
	self.bytes = self.bytes + amt
	if (#self.buffer >= amt) then
		self.buffer = self.buffer:sub(amt+1)
	else
		if (self.file == io.stdin) then
			local ramt = amt-#self.buffer
			while ramt > 0 do
				local bite = 4096
				if (bite > ramt) then
					bite = ramt
				end
				self.file:read(bite)
				ramt = ramt - bite
			end
		else
			self.file:seek("cur", amt-#self.buffer)
		end
		self.buffer = ""
	end
end

setmetatable(buffered_file, {__index=function(_, k)
	return function(self, ...)
		return self[k](self, ...)
	end
end})

local function create_bf(file, buffer)
	return setmetatable({file=file, buffer=buffer, bytes = 0}, {__index=buffered_file})
end


function ssh_open()
	lcpio.error("ssh is not supported on this platform (openos)")
end


do
	local a, b, c, d, e, f = parser:flag("-o --create", "Creates an archive. (Run in copy-out mode)"),
		parser:flag("-i --extract", "Extract files from an archive (Run in copy-in mode)"),
		parser:flag("-t --list", "Print a table of contents of the input."),
		parser:flag("-p --pass-through", "Run in copy-pass mode."),
		parser:flag("-v --version", "Prints the version and exits."),
		parser:flag("--list-formats", "Lists the formats and exits.")
	parser:mutex(
		a, b, c, d, e, f
	)
	parser:group("Main operations", a, b, c, d, e, f)
end

local blk = 512

parser:group("Operations valid in any mode",
	parser:flag("-6", "Use the new cpio64 archive format"),
	parser:option("--block-size", "Set the I/O block size to BLOCK-SIZE * 512 bytes."),
	parser:flag("-B", "Set the I/O block size to 5120 bytes."),
	parser:flag("-c", "Use the old portable (ASCII) archive format."),
	parser:option("-C --io-size", "Set the I/O block size to the given number of bytes."),
	parser:option("-D --directory", "Change directory to DIR"),
	parser:flag("--force-local", "Archive file is local, even if it's name contains colons."),
	format_option,
	parser:flag("-v --verbose", "Verbosely list the files processed"),
	parser:flag("-V --dot", "Print a \".\" for each file processed"),
	parser:option("-W --warning", "Control warning display. Currently, FLAG is one of 'none', 'truncate', 'all'. Multiple options accumulate."):count("*"),
	parser:flag("-g --debug", "Debug prints (prints as warning)")
)

parser:group("Operation modifiers valid in copy-in and copy-out modes",
	
	parser:option("-F --file", "Use this file name instead of standard input or output."),
	parser:option("-M --message", "Print a message when the end of a volume of the backup media is reached.")
)

parser:group("Operation modifiers valid oly in copy-in mode",
	parser:flag("-f --nonmatching", "Only copy files that do not match any of the given patterns."),
	parser:flag("-n --numeric-uid-gid", "In the verbose table of contents listing, show numeric UID and GID."),
	parser:flag("-r --rename", "Interactively rename files."),
	parser:flag("--to-stdout", "Extract files to stdout."),
	parser:option("-E --patern-file", "Read additional patterns specifying filenames to extract or list from FILE"),
	parser:flag("--only-verify-crc", "When reading an archive with a checksum, only verify the checksums of each file in the archive, don't actually extract the files.")
)

parser:group("Operation modifiers valid only in copy-out mode",
	parser:flag("-A --append", "Append to an existing archive."),
	parser:flag("--device-independent --reproducible", "Create device independent (reproducible) archives."),
	parser:flag("--ignore-devno", "Don't store device numbers.")
)

parser:group("Operation modifiers valid only in copy-pass mode",
	parser:flag("-l --link", "Link files instead of copying them, when possible.")
)

do
	-- fuck
	local a, b, c = parser:flag("--absolute-file-names", "Do not strip file system prefix components from the file names."),
	parser:flag("--no-absolute-filenames", "Create al files relative to the current directory."),
	parser:flag("--strip-leading-slash", "Strips leading slashes from file names.")
	parser:group("Operation modifiers in copy-in and copy-out modes",
		a, b, c
	)
	parser:mutex(a, b, c)
end


parser:group("Operation modifiers valid in copy-out and copy-pass modes",
	parser:flag("-0 --null", "Filenames in the list are delimited by null characters instead of newlines."),
	
	parser:flag("-L --dereference", "Dereference symbolic links (copy the files that they point to instead of copying the links)")
)

parser:group("Operation modifiers valid in copy-in and copy-pass modes",
	parser:flag("-d --make-directories", "Create leading directories where needed."),
	
	parser:flag("--sparse", "Write files with large blocks of zeroes as sparse files."),
	parser:flag("-u --unconditional", "Replace all files unconditionally.")
)

load_formats()

args = parser:parse(arg or {...})

table.sort(fmt_list)

if args.list_formats then
	for i=1, #fmt_list do
		if fmt_list[i] ~= "auto" then
			if (args.verbose) then
				print(fmt_list[i], formats[fmt_list[i]].name)
			else
				print(fmt_list[i])
			end
		end
	end
	os.exit(0)
end

if args.debug then debug_mode = true end

local read_bytes = 0
local file
local function open_file()
	if (args.create) then
		if args.file and args.file:match("[^:]+:.+") then
			file = ssh_open(args, "w")
		end
		file = create_bf(args.file and fopen_w(args.file) or io.stdout, "")
	elseif args.list or args.extract then
		if args.file and args.file:match("[^:]+:.+") then
			file = create_bf(ssh_open(args, "r"), "")
		end
		file = args.file and create_bf(fopen_r(args.file), "") or create_bf(io.stdin, "")
	end
end

local function load_args(format, at)
	for k, v in pairs(args) do
		if (k:sub(1, #format+1) == format.."_") then
			at[k:sub(#format+2)] = v
		end
	end
end

local function file_autodetect()
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

local ftype = {
	[0x1000] = "p",
	[0x2000] = "c",
	[0x4000] = "d",
	[0x6000] = "b",
	--[0x8000] = "-",
	[0xA000] = "l",
	[0xC000] = "s"
}

local function get_rwx_string(mode)
	local perms = mode & 0xFFF
	local t = ftype[mode & 0xF000] or "-"
	local pbits = "xwrxwrxwr"
	local pstring = ""
	for i=1, 9 do
		if (perms & (1 << (i-1))) > 0 then
			pstring = pbits:sub(i,i) .. pstring
		else
			pstring = "-" .. pstring
		end
	end
	return t..pstring
end

if (args.list) then
	open_file()
	local format = file_autodetect()
	if not format then lcpio.error("unknown format "..args.format) end
	lcpio.debug("Format is "..format.name.."("..format.id..")")
	format.args = {}
	load_args(format.id, format.args)
	if format.init then format:init() end
	while true do
		local stat = format:read(file)
		if not stat then break end
		if (args.verbose) then
			io.stdout:write(string.format(
				"%s %2d %5d %5d %10d  %11s  %s\n",
				get_rwx_string(stat.mode),
				stat.nlink or 0,
				stat.uid or 0,
				stat.gid or 0,
				stat.size,
				stat.mtime and os.date("%b %d %Y", stat.mtime//1) or "n/a",
				stat.name
			))
		else
			print(stat.name)
		end
		file:skip(stat.size)
		if format.align then
			local skip = format.align - (stat.size % format.align)
			--lcpio.warning(string.format("skip: %d size: %d align %d", skip, stat.size, format.align))
			if skip > 0 and skip ~= format.align then
				--lcpio.warning("skipped "..skip.." bytes")
				file:skip(skip)
			end
		end
	end
elseif (args.create) then -- we don't yet support appending, sadly.
	local lines = {}
	if args.null then
		local buf = ""
		while true do
			local c = io.stdin:read(1)
			if not c or c == "" then
				table.insert(lines, buf)
				break
			elseif c == "\0" then
				table.insert(lines, buf)
				buf = ""
			else
				buf = buf .. c
			end
		end
	else
		for line in io.stdin:lines() do
			table.insert(lines, line)
		end
	end
	open_file()
	local format = formats[args.format] or formats.bin
	if not format then lcpio.error("unknown format "..args.format) end
	lcpio.debug("Format is "..format.name.."("..format.id..")")
	format.args = {}
	load_args(format.id, format.args)
	if format.init then format:init() end
	local inode_i = 0
	for i=1, #lines do
		local path = lines[i]
		-- actually create the archive
		if (args.verbose) then
			io.stderr:write(path,"\n")
		elseif (args.dot) then
			io.stderr:write(".")
		end
		local stat = get_stat(path)
		stat.name = path
		stat.name = stat.name:gsub("^/", "")
		if not LCPIO_ENABLE_METADATA or args.renumber_inodes then
			stat.dev = 0
			stat.inode = inode_i
			stat.ino = inode_i
			inode_i = inode_i + 1
		end
		format:write(file, stat)
		local size_override
		if (stat.mode & 0xF000 == 0x8000) then
			local h = fopen_r(path)
			local size = stat.size
			while size > 0 do
				local bite = 1024*1024
				if (size < bite) then
					bite = size
				end
				local data = h:read(bite)
				lcpio.debug("writing "..bite.." bytes")
				if (#data ~= bite) then
					--os.remove(stat.name)
					lcpio.error(string.format("i/o error (%d ~= %d)", #data, bite))
				end
				file:write(data)
				size = size - bite
			end
			h:close()
		elseif (stat.mode & 0xF000 == 0xA000) then
			local lpath = readlink(path)
			file:write(lpath)
		elseif (stat.mode & 0xF000 == 0x2000 or stat.mode & 0xF000 == 0x6000) and format.write_special then
			size_override = format:write_special(file, stat)
		end
		if format.align then
			local size = size_override or stat.size
			local skip = format.align - (size % format.align)
			--lcpio.warning(string.format("skip: %d size: %d align %d", skip, stat.size, format.align))
			if skip > 0 and skip ~= format.align then
				--lcpio.warning("skipped "..skip.." bytes")
				--file:skip(skip)
				file:write(string.rep("\0", skip))
			end
		end
	end
	format:write_leadout(file)
elseif (args.extract) then
	open_file()
	local format = file_autodetect()
	if (args.directory) then
		chdir(args.directory)
	end
	if not format then lcpio.error("unknown format "..args.format) end
	lcpio.debug("Format is "..format.name.."("..format.id..")")
	format.args = {}
	load_args(format.id, format.args)
	if format.init then format:init() end
	while true do
		local stat = format:read(file)
		if not stat then break end
		if (args.verbose) then
			io.stderr:write(stat.name.."\n")
		elseif (args.dot) then
			io.stderr:write(".")
			--print(stat.name)
		end
		--file:skip(stat.size)
		--lcpio.warning(stat.name:match("^(.+)/[^/]+$"))
		stat.name = stat.name:gsub("/$", "")
		local dir = stat.name:match("^(.+)/[^/]+$")
		--lcpio.warning("dir: "..(dir or "n/a"))
		if (args.make_directories and dir) then
			mkdir_p(dir)
		end
		if (stat.mode & 0xF000 == 0x8000) then
			local ofile = fopen_w(stat.name)
			local size = stat.size
			while size > 0 do
				local bite = 1024*1024
				if (size < bite) then
					bite = size
				end
				local data = file:read(bite)
				if (#data ~= bite) then
					os.remove(stat.name)
					lcpio.error(string.format("unexpected eof (%d ~= %d)", #data, bite))
				end
				ofile:write(data)
				size = size - bite
			end
			ofile:close()
		else
			file:skip(stat.size)
		end
		setperms(stat.name, stat)
		if format.align then
			local skip = format.align - (stat.size % format.align)
			--lcpio.warning(string.format("skip: %d size: %d align %d", skip, stat.size, format.align))
			if skip > 0 and skip ~= format.align then
				--lcpio.warning("skipped "..skip.." bytes")
				file:skip(skip)
			end
		end
	end
else
	lcpio.error("must specify one of oipt")
end
io.stderr:write(math.ceil(file.bytes/blk).." blocks\n")