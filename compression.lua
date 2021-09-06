local extmap = {
	["cxz"] = "xz",
	["clz"] = "lzip",
	["clzma"] = "lzma",
	["cgz"] = "gzip",
	["cbz"] = "bzip2",
	["clr"] = "lrzip",
	["xz"] = "xz",
	["lzip"] = "lzip",
	["lz"] = "lz",
	["gz"] = "gzip",
	["bz2"] = "bzip2",
	["lrz"] = "lrzip"
}

local function autodetect_method(file)
	local ext = file:match("%.(.+)$")
	
end