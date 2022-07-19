local supported_compressors = {
	xz = "xzcat",
	lzip = "lzcat",
	lzma = "xzcat",
	gzip = "gzcat",
	bzip2 = "bzcat",
	lrzip = "lrzcat",
	zstd = "zstdcat"
}
local extmap = {
	["cxz"] = "xz",
	["clz"] = "lzip",
	["clzma"] = "lzma",
	["cgz"] = "gzip",
	["cbz"] = "bzip2",
	["clr"] = "lrzip",
	["xz"] = "xz",
	["lzip"] = "lzip",
	["lz"] = "lzip",
	["gz"] = "gzip",
	["bz2"] = "bzip2",
	["lrz"] = "lrzip",
	["zstd"] = "zstd"
}

local function autodetect_method(file)
	local ext = file:match("%.(.+)$")
	
end

function compresion_open()

end