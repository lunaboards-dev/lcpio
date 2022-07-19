@[[if not svar.get("PLATFORM") then svar.set("PLATFORM", "posix") end]]
@[[function config(tbl)
	for k, v in pairs(tbl) do
		svar.set(k, v)
]]
local @[{k}] = @[{tostring(v)}]
@[[
	end
end
loadfile("config.lua", "t", _G)()]]

local function platform_nyi(method)
	platform[method] = function(...)
		local arglist = table.pack(...)
		for i=1, arglist.n do
			arglist[i] = type(arglist[i])
		end
		lcpio.error(string.format("%s(%s): not yet implemented for this platform", method, table.concat(arglist, ", ")))
	end
end

setmetatable(platform, {__index=function(_, idx)
	platform_nyi(idx)
	return platform[idx]
end})

platform_nyi("list_dir")
platform_nyi("stat")
platform_nyi("readlink")
platform_nyi("openfile")
platform_nyi("mkdir")
platform_nyi("mkdir_p")
platform_nyi("fopen_w")
platform_nyi("fopen_rw")
platform_nyi("fopen_r")
platform_nyi("chdir")
platform_nyi("lookup_gid")
platform_nyi("lookup_uid")
platform_nyi("lookup_user")
platform_nyi("lookup_group")

local load_dirs = {}

function platform.add_load_directories(...)
	local t = table.pack(...)
	for i=1, t.n do
		table.insert(load_dirs, t[i])
	end
end

function platform.load_formats()
	local formats = lcpio.get_formats()
	for i=1, #load_dirs do
		local path = load_dirs[i]
		local plugstat = platform.stat(path)
		if not plugstat or utils.file_type(plugstat.mode) ~= "directory" then
			goto continue
		end
		local files = platform.list_dir(path)
		for j=1, #files do
			local fpath = path.."/"..files[j]
			if utils.file_type(platform.stat(fpath).mode) == "file" then
				local f = platform.openfile(fpath)
				local code = f:read("*a")
				local form = {}
				local global = {}
				for k, v in pairs(_G) do
					global[k] = v
				end
				global._G = global
				global.lcpio = lcpio
				global.FORMAT = {
					path = fpath
				}
				--global.platform = platform
				local func = assert(load(code, "="..fpath, "t", global))
				xpcall(function()
					func()
				end, function(err)
					lcpio.error("Failed to load module: "..fpath.."!\n"..err.."\n"..debug.traceback())
				end)
				if formats[global.FORMAT.id] then
					lcpio.warning("lcpio module "..fpath.." overrides module "..formats[global.FORMAT.id]..".")
				end
				formats[global.FORMAT.id] = global.FORMAT
			end
		end
		::continue::
	end
end

function platform.add_args()
	local formats = {}
	for k, v in pairs(lcpio.get_formats()) do
		table.insert(formats, v)
	end
	table.sort(formats, function(a, b) return a.id < b.id end)
	for i=1, #formats do
		local fmt = formats[i]
		if (fmt.options) then
			local elements = {}
			local t = {}
			for k, v in pairs(fmt.options) do
				table.insert(t, k)
			end
			table.sort(t)
			for _, k in ipairs(t) do
				local v = fmt.options[k]
				local elmt
				if v.type == "option" then
					elmt = parser:option("--"..fmt.id.."-"..k)
					if (v.desc) then
						elmt:description(v.desc)
					end
					if (v.options) then
						elmt:choices(v.options)
					end
					if (v.default) then
						elmt:default(v.default)
					end
				elseif (v.type == "flag") then
					elmt = parser:flag("--"..fmt.id.."-"..k)
					if (v.desc) then
						elmt:description(v.desc)
					end
				end
				table.insert(elements, elmt)
			end
			parser:group("Options for "..fmt.name, table.unpack(elements))
		end
	end
end