local function ssh_open(addr, path, mode)
	if mode == "r" then
		local f = io.popen(string.format("%q %q %q", sshcommand, addr, string.format("cat %q", path)), "r")
		return f
	elseif mode == "w" then
		local f = io.popen(string.format("%q %q %q", sshcommand, addr, string.format("cat - > %q", path)), "w")
		lcpio.warning(string.format("%q", string.format("%q %q %q", sshcommand, addr, string.format("cat - > %q", path))))
		return f
	end
	error("invalid mode")
end