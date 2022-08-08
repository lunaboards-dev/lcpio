--[[
	{
		w_amt = number,
		handle = stream,
		buffer = string
	}
]]
local wio = {}

function wio:read(amt)
	local bz = #self.buffer
	if bz > 0 then
		if amt > bz then
			self.w_amt = self.w_amt + bz
			local bcon = self.buffer
			self.buffer = ""
			return bcon .. self:read(amt-bz)
		else
			self.w_amt = self.w_amt + amt
			local bcon = self.buffer:sub(1, amt)
			self.buffer = self.buffer:sub(amt+1)
			return bcon
		end
	end
	local dat = self.handle:read(amt)
	self.w_amt = self.w_amt + #dat
	return dat
end

function wio:write(d)
	self.w_amt = self.w_amt + #d
	self.handle:write(d)
end

function wio:count()
	return self.w_amt
end

function wio:skip(amt)
	if self.handle == io.stdin then
		self.handle:read(amt)
	else
		self.handle:seek("cur", amt)
	end
	self.w_amt = self.w_amt + amt
end

-- Inserts data into the read buffer and rewind the count.
function wio:insert(dat)
	self.buffer = self.buffer .. dat
	self.w_amt = self.w_amt - #dat
	if self.w_amt < 0 then
		lcpio.warning("stream read count too low (wrong data inserted into buffer? %i < 0)", self.w_amt)
		self.w_amt = 0
	end
end

setmetatable(wio, {__index=function(_, k)
	return function(self, ...)
		self.handle[k](self.handle, ...)
	end
end})

return function(stream)
	return setmetatable({
		handle = stream,
		w_amt = 0,
		buffer = ""
	}, {__index=wio})
end
