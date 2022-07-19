local function pass(...)
	print(...)
	return ...
end
local res = require("statx")("statx.so")
local res2 = require("statx")("statx2.so")
local res3 = require("statx")("statx2.so", true)
local pprint = require "pprint"

pprint(res)
pprint(res2)
pprint(res3)