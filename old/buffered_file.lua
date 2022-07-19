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
		--lcpio.warning(amt-#ret)
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
		--lcpio.warning(self)
		if self.can_rw then
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

function buffered_file:seek(whence, amt)
	if not self.can_rw then lcpio.error("i/o error: stream does not support rewinding") end
	return self.file:seek(whence, amt)
end

function buffered_file:tell()
	return self.bytes
end

function buffered_file:close()
	if self.file ~= io.stdin and self.file ~= io.stdout and self.file ~= io.stderr then
		self.file:close()
	end
end

setmetatable(buffered_file, {__index=function(_, k)
	return function(self, ...)
		return self[k](self, ...)
	end
end})

local function create_bf(file, buffer, can_rw)
	return setmetatable({file=file, buffer=buffer, bytes = 0, can_rw = can_rw}, {__index=buffered_file})
end
