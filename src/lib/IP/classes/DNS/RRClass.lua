--- @class RR
local RR = {
  name = nil,
  type = nil,
  TTL = nil,
  data = nil
}

local hyperPack = require("hyperpack")

function RR:new(name, type, ttl, data)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.name = name
  o.type = type
  o.ttl = ttl
  o.data = data
  return o
end

function RR:serialize()
  assert(type(self.data) ~= "table", "RR data expected string, got " .. type(self.data) .. ".")
  local packer = hyperPack:new()
  packer:pushValue(self.name)
  packer:pushValue(self.type)
  packer:pushValue(self.ttl)
  packer:pushValue(self.data)
  local fullPacket = packer:serialize()
  return fullPacket
end
return RR