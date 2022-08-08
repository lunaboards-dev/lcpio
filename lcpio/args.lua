local parser = require("argparse")("lcpio", "lcpio is an extendable cpio utility, written in Lua.")

parser:help_max_width(80)
parser:usage("Usage: lcpio [OPTIONS...] [directories and files...]")

local format_option = parser:option("-H --format", "Use given archive FORMAT")
format_option:default("auto")

do
	local a, b, c, d, e, f = parser:flag("-o --create --copy-out", "Creates an archive. (Run in copy-out mode)"),
		parser:flag("-i --extract --copy-in", "Extract files from an archive (Run in copy-in mode)"),
		parser:flag("-t --list", "Print a table of contents of the input."),
		parser:flag("-p --pass-through", "Run in copy-pass mode."),
		parser:flag("--version", "Prints the version and exits."),
		parser:flag("--list-formats", "Lists the formats and exits.")
	parser:mutex(
		a, b, c, d, e, f
	)
	parser:group("Main operations", a, b, c, d, e, f)
end

local blk = 512

parser:group("Operations valid in any mode",
	parser:flag("-6", "Use the new cpio64 archive format"), -- check
	parser:option("--block-size", "Set the I/O block size to BLOCK-SIZE * 512 bytes."):default("1"), -- check
	parser:flag("-B", "Set the I/O block size to 5120 bytes."), -- check
	parser:flag("-c", "Use the old portable (ASCII) archive format."), -- check
	parser:option("-C --io-size", "Set the I/O block size to the given number of bytes."), --check
	parser:option("-D --directory", "Change directory to DIR"), -- check
	parser:flag("--force-local", "Archive file is local, even if it's name contains colons."), --TODO
	format_option, -- check
	parser:flag("-v --verbose", "Verbosely list the files processed"):count("0-2"), -- check
	parser:flag("-V --dot", "Print a \".\" for each file processed"), -- check
	parser:option("-W --warning", "Control warning display. Currently, FLAG is one of 'none', 'truncate', 'all'. Multiple options accumulate."):count("*"), -- TODO
	parser:flag("-g --debug", "Debug prints (prints as warning)") -- check
)

local comp = parser:option("-Z --compression", "Specify compression method"):args("?"):default("gzip"):defmode("a")

local compargs = {comp}

local function compressor(name, short)
	local o = parser:flag((short and "-"..short.." " or "").."--"..name:lower(), "Use "..name.." compression"):action(function(res)
		res.compression = name:lower()
	end)
	table.insert(compargs, o)
	return o
end

parser:group("Operation modifiers valid in copy-in and copy-out modes",
	parser:option("--ssh-command --rsh-command", "Use COMMAND instead of ssh"), -- check
	parser:option("-F --file", "Use this file name instead of standard input or output. Optional user and host specify the user and host names in case of a remote archive."), -- check
	parser:option("-M --message", "Print a message when the end of a volume of the backup media is reached."), -- TODO
	comp,
	compressor("GZip"),
	compressor("LZMA"),
	compressor("BZip2"),
	compressor("XZ"),
	compressor("LRZip"),
	compressor("Zstd")
)

parser:mutex(table.unpack(compargs))

parser:group("Operation modifiers valid only in copy-in mode",
	parser:flag("-f --nonmatching", "Only copy files that do not match any of the given patterns."), -- TODO
	parser:flag("-n --numeric-uid-gid", "In the verbose table of contents listing, show numeric UID and GID."), -- check
	parser:flag("-S --human-sizes", "In the verbose table of contents listing, show sizes in a human-readable form."), -- check
	parser:flag("-J --full-date", "In the verbose table of contents listing, show the full date instead of the short date."), -- TODO
	parser:flag("-r --rename", "Interactively rename files."), -- TODO
	parser:flag("--to-stdout", "Extract files to stdout."), -- TODO
	parser:option("-E --patern-file", "Read additional patterns specifying filenames to extract or list from FILE"), -- TODO
	parser:flag("--only-verify-crc", "When reading an archive with a checksum, only verify the checksums of each file in the archive, don't actually extract the files.") -- TODO
)

parser:group("Operation modifiers valid only in copy-out mode",
	parser:flag("-A --append", "Append to an existing archive."), -- check
	parser:flag("--device-independent --reproducible", "Create device independent (reproducible) archives."), -- check
	parser:flag("--ignore-devno", "Don't store device numbers."), -- check
	parser:flag("--renumber-inodes", "Renumber inodes.") -- check
)

parser:group("Operation modifiers valid only in copy-pass mode",
	parser:flag("-l --link", "Link files instead of copying them, when possible.") -- todo
)

do
	-- fuck
	local a, b, c, d = parser:flag("--absolute-file-names", "Do not strip file system prefix components from the file names."), -- todo
	parser:flag("--no-absolute-filenames", "Create all files relative to the current directory."), -- todo
	parser:flag("--strip-leading-slash", "Strips leading slashes from file names."), -- todo, make default
	parser:flag("--keep-leading-slash", "Keeps leading slash in file names.") -- Cool and good.
	parser:group("Operation modifiers in copy-in and copy-out modes",
		a, b, c, d,
		parser:flag("--disable-extended-data", "Disables reading or writing of extended data. May lead to overflow errors."),
		parser:flag("--xmd-as-file", "Create XMD entries as files instead of null entries.")
	)
	parser:mutex(a, b, c)
end


parser:group("Operation modifiers valid in copy-out and copy-pass modes",
	parser:flag("-0 --null", "Filenames in the list are delimited by null characters instead of newlines."), -- done
	parser:flag("-a --reset-access-time", "Resets the access times of files after reading them."), -- todo
	parser:flag("-L --dereference", "Dereference symbolic links (copy the files that they point to instead of copying the links)") -- todo
)

parser:group("Operation modifiers valid in copy-in and copy-pass modes",
	parser:flag("-d --make-directories", "Create leading directories where needed."), -- todo
	parser:flag("-m --preserve-modification-time", "Retain previous file modification times when creating files."), -- todo
	parser:flag("--no-preserve-owner", "Do not change the ownership of the files."), -- todo
	parser:flag("--sparse", "Write files with large blocks of zeroes as sparse files."), -- todo
	parser:flag("-u --unconditional", "Replace all files unconditionally.") -- todo
)

return {parser, format_option}
