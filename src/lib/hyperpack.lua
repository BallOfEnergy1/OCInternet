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
  o.readOnly = false
  o.readIndex = 0
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

local function getFormatString(value)
  if(type(value) == "string") then
    return "c" .. #value
  elseif(type(value) == "number") then
    if(value % 1 == 0) then
      if(value >= 0) then
        return "I" .. getBytesInNumber(value)
      else
        return "i" .. getBytesInNegativeNumber(value)
      end
    else
      return "d"
    end
  elseif(type(value) == "boolean") then
    return "b"
  end
end

function PackedString:pushValue(value)
  assert(self.readOnly == false, debug.traceback("Structure is read-only."))
  assert(value ~= nil, debug.traceback("Packed value cannot be nil."))
  if(type(value) == "table") then
    for _, v in pairs(value) do
      self:pushValue(v)
    end
  end
  local formatString = getFormatString(value)
  self.format = self.format .. formatString
  if(formatString == "b") then
    if(value) then
      self.values[#self.values + 1] = 1
    else
      self.values[#self.values + 1] = 0
    end
  elseif(type(value) ~= "table") then
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
  if(self.readIndex == #self.values) then
    self.readIndex = self.readIndex - 1
  end
  local format
  if(self.format:sub(#self.format) == "b") then
    format = "b"
  else
    format = getFormatString(self.values[#self.values])
  end
  self.format = self.format:sub(1, (-#format) - 1)
  self.values[#self.values] = nil
  return self
  end

function PackedString:serialize()
  local success, result = pcall(function() return self.format .. string.char(0x00) .. string.pack(self.format, table.unpack(self.values)) end)
  if(not success) then
    local errorString = "Hyperpack failed with the following format string: '" .. self.format .. "'.\nHyperpack table contents:\n"
    for index, value in pairs(self.values) do
      errorString = errorString .. tostring(index) .. ": " .. tostring(value) .. "\n"
    end
    errorString = errorString .. "Reason: " .. result
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
  local formatIndex = 1
  for i, v in pairs(result) do
    if(i ~= "n") then
      if(self.format:sub(formatIndex, formatIndex) == "b") then
        if(v == 1) then
          self.values[i] = true
        else
          self.values[i] = false
        end
      else
        self.values[i] = v
      end
    end
    formatIndex = formatIndex + #getFormatString(v)
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