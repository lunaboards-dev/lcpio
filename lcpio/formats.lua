-- include all formats
local formats = {
    bin = lcpio.prequire("lcpio.formats.bin"),
    odc = lcpio.prequire("lcpio.formats.odc"),
    newc = lcpio.prequire("lcpio.formats.newc"),
    crc = lcpio.prequire("lcpio.formats.crc"),
}

return formats