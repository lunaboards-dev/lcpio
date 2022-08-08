-- include all formats
local formats = {
	bin = lcpio.prequire("lcpio.formats.bin"),
	odc = lcpio.prequire("lcpio.formats.odc"),
	newc = lcpio.prequire("lcpio.formats.newc"),
	cpio64 = lcpio.prequire("lcpio.formats.cpio64")
	--crc = lcpio.prequire("lcpio.formats.crc"),
}

return formats
