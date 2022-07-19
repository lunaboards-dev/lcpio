-- random utils in another file to make life easier
local utils = {}

local ftype = {
	[0x1000] = "p",
	[0x2000] = "c",
	[0x4000] = "d",
	[0x6000] = "b",
	--[0x8000] = "-",
	[0xA000] = "l",
	[0xC000] = "s"
}

local ftnames = {
	[0x1000] = "pipe",
	[0x2000] = "cdev",
	[0x4000] = "directory",
	[0x6000] = "bdev",
	[0x8000] = "file",
	[0xA000] = "link",
	[0xC000] = "socket"
}

function utils.get_rwx_string(mode)
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

function utils.file_type(mode)
	return ftnames[mode & 0xF000] or "other"
end

function utils.vprint(...)
	local alist = table.pack(...)
	for i=1, #alist do
		alist[i] = tostring(alist[i])
	end
	io.stderr:write(table.concat(alist, "\t").."\n")
end