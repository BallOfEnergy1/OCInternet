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
  o.format = ""
  o.values = {}
  o.readOnly = nil
  o.readIndex = nil
  return o
end

-- f\left(x\right)=\operatorname{ceil}\left(\frac{\log_{\ 2}\left(x\ +\ 1\right)}{8}\right)
-- Desmos
local function getBytesInNumber(number)
  if(number == 0) then
    return 1
  end
  return math.ceil(math.log(number + 1, 2) / 8)
end

-- g\left(x\right)=\operatorname{ceil}\left(\frac{\log_{2}\left(-2x+1\right)}{8}\right)
-- Desmos
local function getBytesInNegativeNumber(number)
  return math.ceil(math.log(-2 * number + 1, 2) / 8)
end

function PackedString:pushValue(value)
  assert(self.readOnly ~= false, debug.traceback("Structure is read-only."))
  assert(value ~= nil, debug.traceback("Packed value cannot be nil."))
  if(type(value) == "table") then
    for _, v in pairs(value) do
      self:pushValue(v)
    end
  end
  if(type(value) == "string") then
    self.format = self.format .. "c" .. #value
  elseif(type(value) == "number") then
    if(value % 1 == 0) then
      if(value >= 0) then
        self.format = self.format .. "I" .. getBytesInNumber(value)
      else
        self.format = self.format .. "i" .. getBytesInNegativeNumber(value)
      end
    else
      self.format = self.format .. "d"
    end
  elseif(type(value) == "boolean") then
    self.format = self.format .. "b"
    if(value) then
      self.values[#self.values + 1] = 1
    else
      self.values[#self.values + 1] = 0
    end
  end
  if(type(value) ~= "table" and type(value) ~= "boolean") then
    self.values[#self.values + 1] = value
  end
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
  local success, result = pcall(function() return self.format .. string.char(0x00) .. string.pack(self.format, table.unpack(self.values)) end)
  if(not success) then
    local errorString = "Hyperpack failed with the following format string: '" .. self.format .. "'.\nHyperpack table contents:\n"
    for index, value in pairs(self.values) do
      errorString = errorString .. tostring(index) .. ": " .. tostring(value) .. "\n"
    end
    errorString = errorString .. "Reason: " .. result .. "\n"
    error(errorString)
  end
  return result
end

function PackedString:deserializeIntoClass(packedString)
  local iterator = string.gmatch(packedString, "[^" .. string.char(0x00) .. "]+")
  self.format = iterator()
  local stringToUnpack = packedString:sub(#self.format + 2)
  local success, result = pcall(function() return table.pack(string.unpack(self.format, stringToUnpack)) end)
  if(not success) then
    local errorString = "Hyperpack failed with the following format string: '" .. self.format .. "'.\nHyperpack target string:\n"
    errorString = errorString .. tostring(stringToUnpack) .. "\n"
    errorString = errorString .. "Reason: " .. result .. "\n"
    error(errorString)
  end
  for i, v in pairs(result) do
    if(i ~= "n") then
      if(self.format:sub(i, i) == "b") then
        if(v == 1) then
          self.values[i] = true
        else
          self.values[i] = false
        end
      else
        self.values[i] = v
      end
    end
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