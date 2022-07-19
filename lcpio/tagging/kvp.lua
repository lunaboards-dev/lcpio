local tag = {}

local allowed = {
    ["number"] = true,
    ["string"] = true,
    ["boolean"] = true
}

function tag.encode(t)
    local kvp = {}
    for k, v in pairs(t) do
        local vt = type(v)
        if type(k) ~= "string" or not allowed[vt] then lcpio.error("invalid kvp entry") end
        if vt == "number" then
            table.insert(kvp, string.format("%s=#%x", k, v))
        elseif vt == "boolean" then
            table.insert(kvp, string.format("%s=!%s", k, v and "y" or "n"))
        else
            table.insert(kvp, string.format("%s=\\%s", k, v))
        end
    end
    return table.concat(kvp, "\n")
end

function tag.decode(str)
    local r = {}
    for line in str:gmatch("([^\n]+)") do
        line = line:gsub("%s*;.+", "")
        if line == "" then
            goto continue
        end
        local k, v = line:match("([^=]+)=(.+)")
        if v:sub(1,1) == "#" then
            v = tonumber(v:sub(2), 16)
        elseif v:sub(1,1) == "!" then
            v = v == "!y"
        else
            v = v:gsub("^\\", "")
        end
        r[k] = v
        ::continue::
    end
    return r
end

return tag