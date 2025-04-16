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
  local instance = hyperPack:new()
  local success, reason = instance:deserializeIntoClass(record)
  self.name = instance:popValue()
  self.type = instance:popValue()
  self.ttl = instance:popValue()
  self.data = instance:popValue()
  return success, reason or self
end

return RR