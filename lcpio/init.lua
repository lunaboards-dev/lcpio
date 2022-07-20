local cpio_io = require "lcpio.cpio_io"
lcpio = {}
lcpio.version = "2.0.0-alpha0"
lcpio.enable_debug = os.getenv("LCPIO_DBG") == "y"
--#region Core setup
function lcpio.error(err, ...)
    local loc = debug.getinfo(2, "S").source:match("([^/]+).lua$")
    io.stderr:write(string.format("\27[31m(\27[1m%s\27[22m) "..err.."\27[0m\n", loc, ...))
    os.exit(1)
end

function lcpio.warning(warn, ...)
    local loc = debug.getinfo(2, "S").source:match("([^/]+).lua$")
    io.stderr:write(string.format("\27[33m(\27[1m%s\27[22m) "..warn.."\27[0m\n", loc, ...))
end

local warned = {}
function lcpio.warn_once(warn, ...)
    local info = debug.getinfo(2, "Sl")
    local loc = info.source:match("([^/]+).lua$")
    local id = string.format("%s:%d", info.source, info.currentline)
    if warned[id] then return end
    io.stderr:write(string.format("\27[33m(\27[1m%s\27[22m) "..warn.."\27[0m\n", loc, ...))
    warned[id] = true
end

function lcpio.debug(warn, ...)
    if not lcpio.enable_debug then return end
    --if true then return end
    local loc = debug.getinfo(2, "S").source:match("([^/]+).lua$")
    io.stderr:write(string.format("\27[90m(\27[37m%s\27[90m) "..warn.."\27[0m\n", loc, ...))
end

function lcpio.prequire(package, quiet)
    local ok, pkg = pcall(require, package)
    if ok then return pkg end
    if not quiet then lcpio.warning("failed to load package \"%s\"", package) end
end

--#region mkdev
lcpio.minorbits = 20
lcpio.minormask = (1 << lcpio.minorbits) - 1
lcpio.majorbits = 12
lcpio.majormask = (1 << lcpio.majorbits) - 1
function lcpio.mkdev(ma, mi)
	return ((ma & lcpio.majormask) << lcpio.minorbits) | (lcpio.minormask & mi)
end

function lcpio.dev(devno)
    return devno >> lcpio.minorbits, devno & lcpio.minormask
end
--#endregion mkdev

--#region toint
do
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
end
--#endregion toint

--#region tohuman
do
    local units = {"", "K", "M", "G", "T", "P", "E", "Z", "Y"}

    function lcpio.to_human(bytes)
        local u = 1
        while bytes >= 1024 do
            bytes = bytes / 1024
            u = u + 1
        end
        if u == 1 then
            return string.format("%d B", bytes)
        end
        return string.format("%.1f %sB", bytes, units[u])
    end
end
--#endregion tohuman

--#endregion Core setup

--#region Backend setup
local backends = {
    "posix", -- Uses luaposix.
    --"win32", -- Soon, maybe
    "lfs", -- Also soon, maybe
    "openos" -- Soon, for sure.
}
local backend do
    for i=1, #backends do
        local be = require("lcpio.backends."..backends[i])
        if be.detect() then
            backend = be
            break
        end
    end
    if not backend then lcpio.error("No applicable backend found (did you install your system's support library or lfs?)") end
end
lcpio.backend = setmetatable(backend, {__index=function(k) return function(...) lcpio.error(string.format("undefined backend function %s with %d args", k, select("#", ...))) end end})
--#endregion Backend setup
local loader = require("lcpio.loader")

--#region Loader setup
local function subdir(paths, path)
    local new = {}
    for i=1, #paths do
        new[i] = paths[i] .. lcpio.backend.separator .. path
    end
    return table.unpack(paths)
end

lcpio.format_loader = setmetatable({}, {__index=loader}):init("formats", subdir(lcpio.backend.paths, "formats"))
lcpio.tagging_loader = setmetatable({}, {__index=loader}):init("tagging", subdir(lcpio.backend.paths, "tagging"))

lcpio.format_loader:internal(require("lcpio.formats"))

lcpio.tagging_loader:internal {
    json = require("lcpio.tagging.json"),
    kvp = require("lcpio.tagging.kvp")
}
--#endregion Loader setup

local parser, format_option = table.unpack(require("lcpio.args"))

lcpio.formats = lcpio.format_loader:load()
lcpio.tagging = lcpio.tagging_loader:load()
local fl = {"auto"}
do
    lcpio.format_list = {}
    for k, v in pairs(lcpio.formats) do
        v.name = k
        table.insert(lcpio.format_list, k)
        table.insert(fl, k)
    end
    table.sort(lcpio.format_list)
    table.sort(fl)
end

format_option:choices(fl)

local args
if arg then
    args = parser:parse()
else
    args = parser:parse(...)
end
local instance = require("lcpio.instance")
lcpio.enable_debug = lcpio.enable_debug or args.debug

local warnings = {}

local function check_format()
    if args.format == "auto" then args.format = "bin" end
    if not lcpio.formats[args.format] then
        lcpio.error("unknown format %s (use --list-formats to list available formats)", args.format)
    end
end
local infile, outfile
if args.create then
    outfile = cpio_io.open_write(args)
    infile = io.stdin
elseif args.extract or args.list then
    outfile = io.stdout
    infile = cpio_io.open_read(args)
end

--#region Check formats
do
    for k, v in pairs(lcpio.formats) do
        if not v.long_name then lcpio.warning("format %s does not have long name", k) end
        if not v.detect and not v.no_autodetect then lcpio.warning("format %s has no detection function, but isn't marked as undetectable", k) v.no_autodetect = true end
        if not v.read then lcpio.warning("format %s has no read function!!!", k) end
        if not v.write and v.readonly then lcpio.warning("format %s has no write function but is not marked as readonly", k) v.readonly = true end
        if not v.leadout and (not v.readonly) then lcpio.warning("format %s has no leadout function!", k) v.readonly = true end
        if not v.magicsize and not v.no_autodetect then lcpio.warning("format %s has no magic size! defaulting to 0!") v.magicsize = 0 end
    end
end
--#endregion Check formats

--#region Print and exit modes
--#region List formats
if args.list_formats then
    for i=1, #lcpio.format_list do
        if args.verbose > 1 then
            print(string.format("%s - %s", lcpio.format_list[i], lcpio.formats[lcpio.format_list[i]].long_name))
        else
            print(lcpio.format_list[i])
        end
    end
    os.exit(0)
--#endregion List formats
elseif args.version then
    print(lcpio.version)
    os.exit(0)
--#endregion Print and exit modes.
--#region Main operation modes
elseif (args.create) then
    local function next_file()
        if args.null then
            local buffer = ""
            while true do
                local lc = infile:read(1)
                if lc == "\0" or lc == "" or not lc then
                    if buffer == "" then return end
                    return buffer
                end
                buffer = buffer .. lc
            end
        else
            return infile:read("*l")
        end
    end
    check_format()
    local inst = instance.copy_out(outfile, {
        noxd = args.disable_extended_data,
        format = lcpio.formats[args.format],
    })
    --print(inst.format.widths.size)
    local fmax = cpio_io.max_filesize(inst.format)
    local fmask = cpio_io.make_mask(inst.format.widths)
    local idx = {}
    local inode_map = {}
    local function inode_key(dev, inode) return string.format("%.8x-%.16x", dev, inode) end
    for file in next_file do
        local rname = file:gsub("\\", "/") -- i hate windows
        local st = lcpio.backend.stat(file)

        if st.mode & 0xF000 ~= 0x8000 then
            st.size = 0
        end

        if st.mode & 0xF000 == 0xA000 then
            st.size = #st.target+1
        end

        --[[for k, v in pairs(st) do
            lcpio.debug("%s\t%s", k, v)
        end]]

        if st.size > fmax and inst.noxd then
            lcpio.error("file to large for format! (%x > %x)")
        elseif st.size > fmax then -- for easy lookup
            local tags = lcpio.tagging.kvp.encode {
                size = st.size
            }
            inst:add_file {
                size = #tags,
                name = "!!/XTD0/"..rname..".KVP",
                dev = 0xFE00,
                ino = inst.total_shards,
                uid = st.uid,
                gid = st.gid,
                mode = st.mode & 0xFFF,
                nlink = 1,
                rdev = 0,
                atime = 0,
                mtime = 0,
                ctime = 0
            }
            inst:write_data(tags)
            cpio_io.align(inst)
            inst.total_shards = inst.total_shards + 1
        end
        local ind = st.ino
        local dn = st.dev
        local tik = inode_key(dn, ind)
        if (args.ignore_devno) then
            st.dev = 0
            st.t_dev = dn
        end
        if (args.renumber_inode) then
            if (inode_map[tik]) then
                st.ino = inode_map[tik]
                goto ino_done
            end
            idx[st.dev] = (idx[st.dev] or 0)+1
            local nino = idx[st.dev]
            inode_map[tik] = nino
            st.ino = nino
            ::ino_done::
        end
        local stats = cpio_io.gen_stats(inst, st)
        --lcpio.debug("size debug: %d", stats[#stats].size)
        if (instance.noxd and #stats > 1 and (warnings.truncate or warnings.all)) then
            lcpio.warning("fields truncated for %s", file)
        end
        local start = 1
        if (inst.noxd) then
            start = #stats
        else
            if (st.size > fmax) then
                stats[#stats].size = fmax
            end
        end
        for i=start, #stats do
            if i == #stats then
                stats[i].name = file
            else
                cpio_io.xd_clean(stats[i], inst.format)
                stats[i].name = "!!/XMD0/"..rname..".xmd"..(i-1)
            end
            inst:add_file(stats[i])
            cpio_io.align(inst)
        end

        --[[for k, v in pairs(st) do
            lcpio.debug("%s\t%s", k, v)
        end]]

        if st.mode & 0xF000 == 0x8000 then
            local xfd
            local fs = st.size
            local h = io.open(file, "rb")
            local shard_count = 0
            local written = 0
            while fs > 0 do
                local amt = cpio_io.blkcopy(inst, h, fmax, (args.verbose > 1) and {
                    name = file,
                    max = st.size,
                    written = written
                })
                written = written + amt
                cpio_io.align(inst)
                --lcpio.warning("%d of %d", amt, fs)
                fs = fs - amt
                if fs > 0 then
                    local synth_ino = (inst.total_shards+shard_count)
                    --lcpio.warning("Extension at 0x%x", inst:count())
                    inst:add_file({
                        mode = 0x8000 | (st.mode & 0xFFF),
                        ino = synth_ino & fmask.ino,
                        dev = 0xFF00 | ((synth_ino >> inst.format.widths.ino) & 0xFF),
                        rdev = 0,
                        gid = st.gid,
                        uid = st.uid,
                        atime = st.atime,
                        mtime = st.mtime,
                        ctime = st.ctime,
                        nlink = 1,
                        size = (fs > fmax) and fmax or fs,
                        name = "!!/XFD0/"..rname..".part"..shard_count
                    })
                    shard_count = shard_count + 1
                end
            end
            if (args.verbose == 1) then
                io.stderr:write(file.."\n")
            elseif (args.verbose > 1) then
                io.stderr:write("\n")
            elseif args.dot then
                io.stderr:write(".")
            end
            inst.total_shards = inst.total_shards+shard_count
        elseif st.mode & 0xF000 == 0xA000 then
            inst:write_data(st.target.."\0")
            cpio_io.align(inst)
        end
    end
    inst:leadout()
    --cpio_io.align(inst)
    io.stderr:write(string.format("%d blocks.\n", math.ceil(inst:count()/inst.blksize)))
elseif args.list then
    local fmt
    if (args.format ~= "auto") then
        fmt = lcpio.formats[args.format]
    end
    fmt = cpio_io.detect(infile, fmt)
    --lcpio.warning("detected format %s", fmt.name)
    local inst = instance.copy_in(infile, {
        noxd = args.disable_extended_data,
        format = fmt
    })
    local function next_file()
        return inst:next_file()
    end
    local rwx_types = {
        [0x1000] = "p",
        [0x2000] = "c",
        [0x4000] = "d",
        [0x6000] = "b",
        [0x8000] = "-",
        [0xA000] = "l",
        [0xC000] = "s"
    }
    local function date(t)
        local td = os.difftime(os.time(), t)
        if td > 365*24*60*60 or td < 0 then
            return os.date("%b %d  %Y", t)
        end
        return os.date("%b %d %H:%M", t)
    end
    local rwx = "rwx"
    for file in next_file do
        if not file.xfd then
            if (args.verbose > 0) then
                local rwx_string = rwx_types[file.mode & 0xF000] or "?"
                for i=9, 1, -1 do
                    local pos = (i % 3)+1
                    local bit = file.mode & (1 << (i-1))
                    rwx_string = rwx_string .. ((bit > 0) and rwx:sub(pos, pos) or "-")
                end
                local user, group = lcpio.backend.name_lookup(file)
                local mdate = date(file.mtime)
                local puser = user..string.rep(" ", 8-#user)
                local pgroup = group..string.rep(" ", 8-#group)
                io.stderr:write(string.format("%s %3d %s %s %8d %s %s\n", rwx_string, file.nlink, puser, pgroup, file.true_size or file.size, mdate, file.name))
            else
                io.stderr:write(file.name, "\n")
            end
        end
        inst.handle:skip(file.size)
        cpio_io.align(inst) -- doesn't always align for some reason??? (because i'm an idiot)
        cpio_io.detect(inst.handle, inst.format)
    end
elseif (args.extract) then
    lcpio.error("TODO")
--#endregion Main operation modes
else
    lcpio.error("must specify one of -iopt")
end