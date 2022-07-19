--#include "args.lua"

local platform = {}
--#include "liblcpio.lua" "lcpio"
--#include "logging.lua"
--#include "utils.lua"

--#include "platform.lua"

-- Load formats
--#include @[{"loader_"..(svar.get("PLATFORM") or "posix")..".lua"}]
@[[if svar.get("LCPIO_ENABLE_SSH") then]]
--#include "ssh_open.lua"
@[[else]]
function ssh_open()
	lcpio.error("ssh is not supported on this platform (@[{svar.get("PLATFORM") or "unknown"}])")
end
@[[end]]

local file_list, block_size, format

platform.load_formats()
platform.add_args()

args = parser:parse(arg or {...})

-- parse args
if args.list_formats then
	local flist = {}
	for k, v in pairs(lcpio.get_formats()) do
		table.insert(flist, v)
	end
	table.sort(flist, function(a, b) return a.id < b.id end)
	for i=1, #flist do
		io.stdout:write(flist[i].id)
		if args.verbose then
			io.stdout:write("\t",flist[i].name)
		end
		io.stdout:write("\n")
	end
	os.exit(0)
end

format = args.format

if args.append and not args.create then
	lcpio.error("--append specified, but we're not in copy-out mode")
elseif args.append and not args.file then
	lcpio.error("--append spcified, but there's no file to append to")
end

if args["6"] then
	args.format = "cpio64"
elseif args.c then
	args.format = "odc"
end

if args.B then
	block_size = 5120
else
	block_size = tonumber(args.block_size, "10")*512
end

-- utils
local function rtv(...)
	--utils.vprint(...)
	return ...
end

local line_iter
local function next_file()
	if args.null then
		local buf = ""
		while true do
			local c = file_list:read(1)
			if #buf == 0 and (not c or c == "") then return end
			if c == "\0" or not c or c == "" then return buf end
			buf = buf .. c
		end
	else
		if not line_iter then
			line_iter = file_list:lines()
		end
		return rtv(line_iter())
	end
end

-- modes
local function append(file)
	
end

local function create(file)
	local arc = lcpio.open("w", file)
	arc:format(format ~= "auto" and format or "bin", fmt_args)
	--utils.vprint(file)
	local inode_i  = 0
	for path in next_file do
		local fstat, err = platform.stat(path)
		if not fstat then
			lcpio.error(err)
		end
		if not LCPIO_ENABLE_METADATA or args.renumber_inodes then
			stat.dev = 0
			stat.dev_maj = 0
			stat.dev_in = 0
			stat.inode = inode_i
			stat.ino = inode_i
			inode_i = inode_i + 1
		end
		if utils.file_type(fstat.mode) == "file" then
			arc:write_stat(fstat)
			local f = io.open(path, "rb")
			local written = 0
			while true do
				local chunk = f:read(block_size or 512)
				if not chunk or #chunk == 0 then break end
				written = written + #chunk
				arc:write(chunk)
			end
			if written ~= fstat.size then lcpio.error(string.format("%s: unexpected eof (%d ~= %d)", path, written, fstat.size or -1)) end
		elseif utils.file_type(fstat.mode) == "link" then
			local lpath = readlink(path)
			fstat.size = #lpath
			arc:write_stat(fstat)
			arc:write(lpath)
		else
			arc:write_stat(fstat)
		end
		arc:align()
		if (args.verbose) then
			io.stderr:write(path,"\n")
		elseif (args.dot) then
			io.stderr:write(".")
		end
	end
	local amt = arc:close()
	io.stderr:write(string.format("%d blocks\n", math.ceil(amt/block_size)))
end

--#include "tohuman.lua"

local function list(file)
	local arc = lcpio.open("r", file)
	arc:format(format ~= "auto" and format)
	for file in arc:files() do
		if (args.verbose) then
			local grp, usr
			if LCPIO_UID_GID_LOOKUP and not args.numeric_uid_gid then
				grp = file.gid and lookup_gid(file.gid) or "n/a"
				usr = file.uid and lookup_uid(file.uid) or "n/a"
			else
				grp = string.format("%5d", file.gid or 0)
				usr = string.format("%5d", file.uid or 0)
			end
			local size
			if args.human_sizes then
				size = to_human(file.size)
			else
				size = string.format("%8d", file.size)
			end
			grp = pad(grp, 8)
			usr = pad(usr, 8)
			io.stdout:write(string.format(
				"%s %3d %7s %7s "..(args.human_sizes and "%10s" or "%8s").." %11s %s\n",
				utils.get_rwx_string(file.mode),
				file.nlink or 0,
				grp,
				usr,
				size,
				file.mtime and os.date("%b %d %H:%M", file.mtime//1) or "n/a",
				file.name
			))
		else
			print(file.name)
		end
		arc:skip(file.filesize or file.size)
		arc:align()
	end
	local p = arc:close()
	io.stderr:write(string.format("%d blocks\n", math.ceil(p/block_size)))
end

local function extract(file)
	local arc = lcpio.open("r", file)
	arc:format(format ~= "auto" and format)
	for stat in arc:files() do
		stat.name = stat.name:gsub("/$", "")
		local dir = stat.name:match("^(.+)/[^/]+$")
		if (args.make_directories and dir) then
			platform.mkdir_p(dir)
		end
		if utils.file_type(fstat.mode) == "file" then
			local ofile = platform.fopen_w(stat.name)
			local size = stat.size
			while size > 0 do
				local bite = block_size
				if (size < bite) then
					bite = size
				end
				local data = arc:read(bite)
				if (#data ~= bite) then
					os.remove(stat.name)
					lcpio.error(string.format("unexpected eof (%d ~= %d)", #data, bite))
				end
				ofile:write(data)
				size = size - bite
			end
			ofile:close()
		elseif utils.file_type(fstat.mode) == "link" then
			local linkpath = arc:read(stat.size)
			platform.link(stat.name, linkpath:gsub("\0", ""))
		else
			file:skip(stat.size)
		end
		platform.setperms(stat.name, stat)
		arc:align()
		if (args.verbose) then
			io.stderr:write(stat.name,"\n")
		elseif (args.dot) then
			io.stderr:write(".")
		end
	end
end

-- actual runtime

-- setup

-- modes

file_list = io.stdin
if args.create and args.append then

elseif args.create then
	local f = io.stdout
	lcpio.warning(args.file)
	if args.file then
		f, e = platform.openfile(args.file, "r")
		if not f then lcpio.error(e) end
	end
	create(f)
elseif args.list or (args.list and args.extract) then
	local f = io.stdin
	if args.file then
		f, e = platform.openfile(args.file, "r")
		if not f then lcpio.error(e) end
	end
	list(f)
elseif args.extract then

else
	lcpio.error("no action. specify one of -iopt")
end