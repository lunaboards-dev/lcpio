local ssh_io = require "lcpio.ssh_io"
local wrapped_io = require "lcpio.wrapped_io"
local cpio_io = {}

function cpio_io.open_write(args)
    if (args.file) then
        local f = args.file
        if f:find(":") and not args.force_local then
            return wrapped_io(ssh_io.open(args))
        end
        return wrapped_io(io.open(f, "wb"))
    end
    return wrapped_io(io.stdout)
end

function cpio_io.open_read(args)
    if (args.file) then
        local f = args.file
        if f:find(":") and not args.force_local then
            return wrapped_io(ssh_io.open(args))
        end
        return wrapped_io(io.open(f, "rb"))
    end
    return wrapped_io(io.stdin)
end

function cpio_io.blkcopy(instance, handle, max, verb)
    local outcount = 0
    local tbs = instance.blksize*100
    if verb then
        io.stderr:write(string.format("\r%s: %d%% (%d of %d)", verb.name, 
                        ((verb.written/verb.max)*100)//1,
                        verb.written, verb.max))
    end
    local written = verb and verb.written or 0
    while max > 0 do
        local count = (tbs > max) and max or tbs
        local dat = handle:read(count)
        outcount = outcount + (dat and #dat or 0)
        instance:write_data(dat or "")
        local dl = #(dat or "")
        if verb then
            written = written + dl
            io.stderr:write(string.format("\r%s: %d%% (%d of %d)", verb.name,
                            ((written/verb.max)*100)//1,
                            written, verb.max))
        end
        if not dat or #dat ~= count then handle:close() return outcount end
        max = max - dl
    end
    return outcount
end

function cpio_io.detect(file, format)
    local start = file:count()
    local mbuf
    if format then -- find header
        local msize = format.magicsize
        mbuf = file:read(msize)
        while not format:detect(mbuf) do
            local c = file:read(1)
            if c == "" or not c then
                lcpio.error("unexpected eof")
            end
            mbuf = mbuf:sub(2) .. c
        end
        file:insert(mbuf)
        if file:count()-start > 0 then
            lcpio.warning("skipped %d bytes of junk", file:count()-start)
        end
        return format
    end
    -- find what format we have
    local formats = {}
    local msize = 0
    for i=1, #lcpio.format_list do
        local fmt = lcpio.formats[lcpio.format_list[i]]
        formats[i] = {name = lcpio.format_list[i], fmt = fmt}
        msize = (fmt.magicsize > msize) and fmt.magicsize or msize
    end
    local fl = #formats
    mbuf = file:read(msize)
    while true do
        for i=1, fl do
            if formats[i].fmt:detect(mbuf) then
                file:insert(mbuf)
                if (file:count()-start > 0) then
                    lcpio.warning("skipped %d bytes of junk", file:count()-start)
                end
                return formats[i].fmt
            end
            local c = file:read(1)
            if not c or c == "" then
                lcpio.error("unexpected eof")
            end
            mbuf = mbuf:sub(2) .. c
        end
    end
end

function cpio_io.align(instance)
    if instance.format.align and instance.format.align > 1 and (instance:count() % instance.format.align) > 0 then
        if (instance.write) then
            local pad = string.rep("\0", instance.format.align-(instance:count() % instance.format.align))
            instance:write_data(pad)
            lcpio.debug("wrote %d bytes of pad", #pad)
        else
            instance.handle:skip(instance.format.align-(instance:count() % instance.format.align))
        end
    end
end

function cpio_io.max_filesize(format)
    local v = format.widths.size
    if (v == 64) then
        return 0xFFFFFFFFFFFFFFFF
    else
        return (1 << v)-1
    end
end

local function mask(widths)
    local msk = {}
    for k, v in pairs(widths) do
        if (v == 64) then
            msk[k] = 0xFFFFFFFFFFFFFFFF
        else
            msk[k] = (1 << v)-1
        end
    end
    return msk
end

cpio_io.make_mask = mask

local xd_whitelist = {
    ["uid"] = true,
    ["gid"] = true,
    ["ino"] = true,
    ["mtime"] = true,
    ["atime"] = true
}
local function xdgen(stat, mask, widths)
    local truncated, remainder = {}, {}
    local overflow
    --lcpio.debug("========")
    for k, v in pairs(widths) do
        lcpio.debug("field: %s; stat[k]: %q; mask[k]: %q", k, stat[k], mask[k])
        --if k ~= "size" then
        if true then
            truncated[k] = (stat[k] & mask[k])
            if xd_whitelist[k] then
                remainder[k] = (stat[k] >> widths[k])
                if (remainder[k] > 0) then overflow = true end
            elseif k == "dev" then
                remainder[k] = 0xFE00
            else
                remainder[k] = 0
            end
        else
            truncated[k] = stat[k]
            remainder[k] = 0
        end
    end
    return truncated, remainder, overflow
end

function cpio_io.xd_clean(stat, format)
    for k, v in pairs(format.widths) do
        if not xd_whitelist[k] or k == "dev" then
            stat[k] = 0
        end
    end
end

function cpio_io.gen_stats(inst, stat)
    local format = inst.format
    local clone = {}
    for k, v in pairs(stat) do
        clone[k] = v
    end
    local stats = {}
    local active
    local cs = clone
    local mask = mask(format.widths)
    repeat
        local truncated, remainder, overflow = xdgen(cs, mask, format.widths)
        active = overflow
        table.insert(stats, 1, truncated)
        cs = remainder
    until not active
    return stats
end

return cpio_io