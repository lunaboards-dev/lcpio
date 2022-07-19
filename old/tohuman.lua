local units = {"", "Ki", "Mi", "Gi", "Ti", "Pi", "Ei", "Zi", "Yi"}

local function to_human(bytes)
	local u = 1
	while bytes >= 1024 do
		bytes = bytes / 1024
		u = u + 1
	end
	if u == 1 then
		return string.format("%d B", bytes)
	end
	return string.format("%.1f %sB", bytes, units[u])
end

local function pad(s, size)
	if #s ~= size then
		s = s .. string.rep(" ", size-#s)
	end
	return s
end