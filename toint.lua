local alpha = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"
function lcpio.toint(n, base, size)
	local str = ""
	while n > 0 do
		local pos = n % base
		str = alpha:sub(pos+1, pos+1) .. str
		n = n // base
	end
	if (size) then
		str = string.rep("0", size-#str) .. str
	end
	return str
end
