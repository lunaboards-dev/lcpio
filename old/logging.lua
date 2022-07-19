function lcpio.warning(msg)
	local src = "unknown"
	if (debug.getinfo) then
		local di = debug.getinfo(2)
		local f = di.source
		if f:sub(1,1) == "@" or f:sub(1,1) == "=" then
			local m = f:match("([^/=@]+)%.lua$")
			if m then
				src = m
			elseif (f:match "@.*/lcpio") then
				src = "lcpio"
			end
		end
		msg = (di.name or "[function]") .. "(): " .. msg
	end
	io.stderr:write(string.format("\27[90;1m(%s)\27[0m \27[93m\27[1mwarning:\27[22m %s\27[0m\n", src, msg))
end

function lcpio.debug(msg)
	if not true then return end
	local src = "unknown"
	if (debug.getinfo) then
		local di = debug.getinfo(2)
		local f = di.source
		if f:sub(1,1) == "@" or f:sub(1,1) == "=" then
			local m = f:match("([^/=@]+)%.lua$")
			if m then
				src = m
			elseif (f:match "@.*/lcpio") then
				src = "lcpio"
			end
		end
		msg = (di.name or "[function]") .. "(): " .. msg
	end
	io.stderr:write(string.format("\27[90;1m(%s)\27[0m \27[93m\27[1mdebug:\27[22m %s\27[0m\n", src, msg))
end

function lcpio.error(msg, code)
	code = code or 1
	local src = "unknown"
	if (debug.getinfo) then
		local di = debug.getinfo(2)
		local f = di.source
		if f:sub(1,1) == "@" or f:sub(1,1) == "=" then
			local m = f:match("([^/=@]+)%.lua$")
			if m then
				src = m
			elseif (f:match "@.*/lcpio") then
				src = "lcpio"
			end
		end
		msg = (di.name or "[function]") .. "(): " .. msg
	end
	io.stderr:write(string.format("\27[90m(%s)\27[0m \27[31m\27[1merror:\27[22m %s\27[0m\n", src, msg))
	os.exit(code)
end
