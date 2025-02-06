--- @class PackedString
local PackedString = {
  format = "",
  values = {},
  readOnly = nil,
  readIndex = nil
}

function PackedString:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

local function getBytesInNumber(number)
  return math.ceil(math.log(number, 2) / 8)
end

function PackedString:pushValue(value)
  assert(self.readOnly ~= false, "Structure is read-only.")
  assert(value ~= nil, "Packed value cannot be nil.")
  if(type(value) == "table") then
    for _, v in pairs(value) do
      self:pushValue(v)
    end
  end
  if(type(value) == "string") then
    self.format = self.format .. "c" .. #value
  elseif(type(value) == "number") then
    if(value % 1 == 0) then
      self.format = self.format .. "i" .. getBytesInNumber(value)
    else
      self.format = self.format .. "d"
    end
  elseif(type(value) == "boolean") then
    self.format = self.format .. "b"
  end
  self.values[#self.values + 1] = value
end

function PackedString:removeLastEntry(amount) -- understand that i dont like you
  if(amount) then
    for _ = 1, amount do
      self:removeLastEntry()
    end
    return
  end
  self.values[#self.values] = nil
  if(self.readIndex == #self.values) then
    self.readIndex = self.readIndex - 1
  end
  return self
end

function PackedString:serialize()
  return self.format .. string.char(0x00) .. string.pack(self.format, table.unpack(self.values))
end

function PackedString:deserializeIntoClass(packedString)
  local iterator = string.gmatch(packedString, "[^" .. string.char(0x00) .. "]+")
  self.format = iterator()
  local stringToUnpack = iterator()
  for i, v in pairs(string.unpack(self.format, stringToUnpack)) do
    self.values[i] = v
  end
  self.readOnly = true
  self.readIndex = 1
  return self
end

function PackedString:popValue()
  local value = self.values[self.readIndex]
  if(value == nil) then
    error("Stack underflow; attempted to read nil entry.")
  end
  self.values[self.readIndex] = nil
  self.readIndex = self.readIndex + 1
  return value
end

function PackedString:copyFrom(otherClass)
  self.format = otherClass.format
  for i, v in pairs(otherClass.values) do
    self.values[i] = v
  end
  self.readOnly = true
  self.readIndex = 1
  return self
end

return PackedString