
local hyperpack = require("hyperpack")

--- This file is an example of how to use the HyperPack library for sending tables and multiple data "slices" at once.

--- This function packs data from a table into a Hyperpack instance.
--- @param table table Table of data to serialize.
--- @return string Serialized data.
local function pack(table)
    local instance = hyperpack:new()
    instance:pushValue(table)
    return instance:serialize()
end

--- This function unpacks data from a string into a table.
--- @param serialized string Serialized data to deserialize.
--- @return table Table of deserialized data.
local function unpack(serialized)
    local instance = hyperpack:new():deserializeIntoClass(serialized)
    return instance.data
end

return {pack = pack, unpack = unpack}