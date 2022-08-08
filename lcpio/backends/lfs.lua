-- LFS fallback backend. Guess I should really just use this for now.

local path_sep
if package.config then
	path_sep = package.config:sub(1,1)
else
	path_sep = "/"
end

local lfs = lcpio.prequire("lfs", lcpio.prequire("computer", true))

local backend = {}

if path_sep == "\\" then
	backend.windows = true
end

backend.separator = path_sep

if backend.windows then
	backend.paths = {
		"C:\\Program Files\\lcpio2",
		os.getenv("AppData").."\\lcpio2"
	}
else
	backend.paths = {
		"/usr/local/share/lcpio2",
		os.getenv("HOME").."/.local/share/lcpio2"
	}
end

function backend.detect()
	if lfs and not backend.windows then
		lcpio.warning("!!! lfs fallback in use! have you installed luaposix?")
	end
	return lfs
end

local ftypes = {
	["named pipe"] = 1,
	["character device"] = 2,
	["directory"] = 4,
	["block device"] = 6,
	["file"] = 8,
	["link"] = 10,
	["socket"] = 12
}

local function buildmode(perm, ftype)
	-- Parse bits
	local rwx_bits = 0
	for i=1, #perm do
		rwx_bits = rwx_bits | (perm:sub(i,i) == "-" and 0 or 1) << (9-i)
	end
	rwx_bits = rwx_bits | ((ftypes[ftype] or 0) << 12)
	return rwx_bits
end

function backend.exists(path)
	return not not lfs.attributes(path, "size")
end

function backend.stat(path)
	--lcpio.debug("stat: %s", path)
	local attr, err = lfs.symlinkattributes(path)
	if not attr then lcpio.error("can't stat %s: %s", path, err) end
	local dma, dmi = lcpio.dev(attr.dev)
	local rma, rmi = lcpio.dev(attr.rdev)
	return {
		ino = attr.ino,
		rdev = attr.rdev or 0, -- ???
		rdev_maj = rma,
		rdev_min = rmi,
		mode = buildmode(attr.permissions, attr.mode),
		size = attr.size,
		atime = attr.access,
		mtime = attr.modification,
		ctime = attr.change,
		dev = attr.dev or 0, -- why are these randomly failing
		dev_maj = dma,
		dev_min = dmi,
		uid = attr.uid,
		gid = attr.gid,
		target = attr.target,
		nlink = attr.nlink or (attr.mode == "directory" and 2 or 1) -- ????????
	}
end

function backend.name_lookup(stat)
	return string.format("%d", stat.uid), string.format("%d", stat.gid)
end

function backend.dir(path)
	return lfs.dir(path)
end

return backend
