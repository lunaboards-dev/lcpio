local buffered_file = {}
function buffered_file:read(amt)
	self.bytes = self.bytes + amt
	if (#self.buffer >= amt) then
		local ret = self.buffer:sub(1, amt)
		self.buffer = self.buffer:sub(amt+1)
		return ret
	else
		local ret = self.buffer
		self.buffer = ""
		local fret, err = self.file:read(amt-#ret)
		--self.bytes = self.bytes + amt-#ret
		if not fret then lcpio.error("unexpected eof") end
		return ret..fret
	end
end

function buffered_file:write(data)
	self.bytes = self.bytes + #data
	self.file:write(data)
end

function buffered_file:skip(amt)
	self.bytes = self.bytes + amt
	if (#self.buffer >= amt) then
		self.buffer = self.buffer:sub(amt+1)
	else
		if (self.file == io.stdin) then
			local ramt = amt-#self.buffer
			while ramt > 0 do
				local bite = 4096
				if (bite > ramt) then
					bite = ramt
				end
				self.file:read(bite)
				ramt = ramt - bite
			end
		else
			self.file:seek("cur", amt-#self.buffer)
		end
		self.buffer = ""
	end
end

setmetatable(buffered_file, {__index=function(_, k)
	return function(self, ...)
		return self[k](self, ...)
	end
end})

local function create_bf(file, buffer)
	return setmetatable({file=file, buffer=buffer, bytes = 0}, {__index=buffered_file})
end
