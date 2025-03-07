--- @class RR
local RR = {
  name = nil,
  type = nil,
  ttl = nil,
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
  local record = packer:serialize()
  return record
end

function RR:deserialize(record)
  local packer = hyperPack:new():deserializeIntoClass(record)
  self.name = packer:popValue()
  self.type = packer:popValue()
  self.ttl = packer:popValue()
  self.data = packer:popValue()
  return self
end

return RR