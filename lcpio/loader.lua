local loader = {}

function loader:init(name, ...)
    self.name = name
    self.paths = table.pack(...)
    self.cache = {}
    return self
end

function loader:load(...)
    if select("#", ...) == 0 then -- load all
        for i=1, #self.paths do
            if lcpio.backend.exists(self.paths[i]) then
                for file in lcpio.backend.dir(self.paths[i]) do
                    if file:sub(1,1) ~= "." then
                        self.cache[file:gsub("%.[^%.]+", "")] = loadfile(self.paths[i]..lcpio.backend.separator..file)()
                    end
                end
            end
        end
        return self.cache
    else
        local retv = {}
        local loadlist = table.pack(...)
        for i=1, loadlist.n do
            local pname = loadlist[i]
            if self.cache[pname] then
                --retv[pname] = self.cache[pname]
                retv[i] = self.cache[pname]
            else
                for j=1, #self.paths do
                    if lcpio.backend.exists(self.paths[j]..lcpio.backend.separator..pname..".lua") then
                        self.cache[pname] = loadfile(self.paths[j]..lcpio.backend.separator..pname..".lua")()
                        --retv[pname] = self.cache[pname]
                        retv[i] = self.cache[pname]
                        goto ok
                    end
                end
                lcpio.error("module not found: %s.%s", self.name, pname)
                ::ok::
            end
        end
        return table.unpack(retv)
    end
end

function loader:search(...)

end

function loader:list()
    
end

function loader:internal(values)
    for k, v in pairs(values) do
        self.cache[k] = v
    end
end

return loader