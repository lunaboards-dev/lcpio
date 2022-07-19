local posix = lcpio.prequire("posix", true)
local statx = lcpio.prequire("statx", true)
local stat = lcpio.prequire("posix.sys.stat", true)
local unistd = lcpio.prequire("posix.unistd", true)
local dirent = lcpio.prequire("posix.dirent", true)
local grp = lcpio.prequire("posix.grp", true)
local pwd = lcpio.prequire("posix.pwd", true)

local backend = {}

backend.paths = {
	"/usr/local/share/lcpio2",
	os.getenv("HOME").."/.local/share/lcpio2"
}

backend.separator = "/"

function backend.detect()
	return posix
end

function backend.stat(path)
	if statx then
		local sb, err = statx(path, true)
		if not sb then
			lcpio.error(string.format("%s: %s", path, err))
		end
		local linkname
		if sb.stx_mode & 0xF000 == 0xA000 then
			linkname = unistd.readlink(path)
		end
		-- statx provides the most info by far
		return {
			ino = sb.stx_ino,
			rdev_maj = sb.stx_rdev_major,
			rdev_min = sb.stx_rdev_minor,
			rdev = lcpio.mkdev(sb.stx_rdev_major, sb.stx_rdev_minor),
			dev_maj = sb.stx_dev_major,
			dev_min = sb.stx_dev_minor,
			dev = lcpio.mkdev(sb.stx_dev_major, sb.stx_dev_minor),
			atime = sb.stx_atime.tv_sec,
			atime_nsec = sb.stx_atime,
			mtime = sb.stx_mtime.tv_sec,
			mtime_nsec = sb.stx_mtime,
			ctime = sb.stx_ctime.tv_sec,
			ctime_nsec = sb.stx_ctime,
			btime = sb.stx_btime.tv_sec,
			btime_nsec = sb.stx_btime,
			uid = sb.stx_uid,
			gid = sb.stx_gid,
			size = sb.stx_size,
			nlink = sb.stx_nlink,
			target = linkname
		}
	end
	lcpio.warn_once("statx library not installed! limited to 32-bit times (beware Y2038!)")
	local sb = stat.lstat(path)
	local linkname
	if sb.stx_mode & 0xF000 == 0xA000 then
		linkname = unistd.readlink(path)
	end
	local dma, dmi = lcpio.dev(sb.st_dev)
	local rma, rmi = lcpio.dev(sb.st_rdev)
	return {
		dev = sb.st_dev,
		dev_maj = dma,
		dev_min = dmi,
		ino = sb.st_ino,
		mode = sb.st_mode,
		uid = sb.st_uid,
		gid = sb.st_gid,
		rdev = sb.st_rdev,
		rdev_maj = rma,
		rdev_min = rmi,
		size = sb.st_size,
		atime = sb.st_atime,
		mtime = sb.st_mtime,
		ctime = sb.st_ctime,
		target = linkname
	}
end

function backend.exists(path)
	return stat.lstat(path)
end

function backend.name_lookup(stat)
	local user = pwd.getpwuid(stat.uid)
	local group = grp.getgrgid(stat.gid)
    return user and user.pw_name or "unknown", group and group.gr_name or "unknown"
end

function backend.dir(path)
	return dirent.files(path)
end

return backend