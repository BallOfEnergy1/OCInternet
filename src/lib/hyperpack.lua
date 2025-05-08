--- @class Hyperpack
--- Hyperpack library, used for byte-packing multiple data values (or a table) into a string.
local Hyperpack = {
  format = "",
  values = {},
  readOnly = nil,
  readIndex = nil
}

local version = 3

--- Creates a new hyperpack class instance.
--- @return Hyperpack Instance.
function Hyperpack:new()
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

--- Function for validating a Hyperpack string.
--- @param serialized string String to validate.
--- @return boolean, string, table True, format string, and the data table if the string is a valid HyperPack string, false otherwise.
local function validateAndUnpack(serialized)
  -- Steps for validation:
  -- Step 1: Check for NUL byte separating all HyperPack strings.
  -- The above step does not account for if the packet just randomly has a NUL byte.
  local hasNUL = serialized:find(string.char(0x00), 1, true)
  if(not hasNUL) then
    return false, "HyperPack string does not contain NUL separator; invalid string."
  end
  
  -- Step 2: Check the dual validation bytes at the beginning of the string.
  -- These contain the version and the `H` character, meaning they can easily be forged.
  local validationBytes = serialized:sub(1, 2)
  if(validationBytes:byte(1, 1) ~= version) then
    return false, "HyperPack string version does not match local; invalid string."
  end
  if(validationBytes:sub(2, 2) ~= "H") then
    return false, "HyperPack string does not contain magic byte; invalid string."
  end
  
  -- Step 3: Test unpacking the string through the HyperPack algorithm.
  -- This is a slow step, but the results are returned so they can be used inside the original function.
  -- This step fully confirms that the string is valid, however it does not confirm if the data *inside* the string is genuine.
  serialized = serialized:sub(3) -- Remove first two characters; validation.
  local iterator = string.gmatch(serialized, "[^" .. string.char(0x00) .. "]+")
  local format = iterator()
  local stringToUnpack = serialized:sub(#format + 2)
  local success, result = pcall(function() return table.pack(string.unpack(format, stringToUnpack)) end)
  if(not success) then
    return false, "Unknown failure, Format string: " .. format .. "; Reason: " .. result
  end
  result["n"] = nil
  table.remove(result)
  -- And finally...
  return true, format, result
end

--- Pushes a value to the hyperpack stack. Automatically creates format string.
---
--- Function will error if a nil value if given or if the target structure is read-only.
--- @param value any Value to pack.
--- @return nil
function Hyperpack:pushValue(value)
  assert(self.readOnly == false, debug.traceback("Structure is read-only."))
  assert(value ~= nil, debug.traceback("Packed value cannot be nil."))
  if(type(value) == "table") then
    for _, v in pairs(value) do
      self:pushValue(v)
    end
    return
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

--- Removes `amount` of entries from the top of the hyperpack stack.
---
--- If `amount` is `nil`, this function will remove the top item from the stack.
--- @param amount number Amount to remove.
--- @return Hyperpack Self instance.
--- @overload fun():Hyperpack
function Hyperpack:removeLastEntry(amount) -- understand that i dont like you
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

--- Serializes Hyperpack class into a string.
---
--- Function can error if serialization fails.
--- @return string Packed Hyperpack class.
function Hyperpack:serialize()
  local success, result = pcall(function() return self.format .. string.char(0x00) .. string.pack(self.format, table.unpack(self.values)) end)
  if(not success) then
    local errorString = "Hyperpack failed with the following format string: '" .. self.format .. "'.\nHyperpack table contents:\n"
    for index, value in pairs(self.values) do
      errorString = errorString .. tostring(index) .. ": " .. tostring(value) .. "\n"
    end
    errorString = errorString .. "Reason: " .. result
    error(errorString)
  end
  local validationString = string.char(version) .. "H"
  return validationString .. result
end

--- Deserializes a string into a Hyperpack instance. No validation is done during this step.
---
--- Function can error if deserialization fails.
--- @param packedString string Packed Hyperpack string.
--- @return boolean, string Returns true if the string was successfully deserialized, false and a string (reason) otherwise.
function Hyperpack:deserializeIntoClass(packedString)
  local isValid, format, result = validateAndUnpack(packedString)
  if(not isValid) then
    return false, "HyperPack string cannot be parsed for the following reason: " .. format
  end
  self.format = format
  local formatIndex = 1
  for i, v in pairs(result) do
    if(self.format:sub(formatIndex, formatIndex) == "b") then
      if(v == 1) then
        self.values[i] = true
      else
        self.values[i] = false
      end
    else
      self.values[i] = v
    end
    formatIndex = formatIndex + #getFormatString(v)
  end
  self.readOnly = true
  self.readIndex = 1
  return true
end

--- Pops a value off the top of the Hyperpack stack.
---
--- Can error in the case of a stack underflow.
--- @return any
function Hyperpack:popValue()
  local value = self.values[self.readIndex]
  if(value == nil) then
    error("Stack underflow; attempted to read nil entry.")
  end
  self.values[self.readIndex] = nil
  self.readIndex = self.readIndex + 1
  return value
end


--- Pops the remaining values off the Hyperpack stack into a table.
---
--- @return table
function Hyperpack:popRemaining()
  local value = self.values[self.readIndex]
  local values = {}
  while value ~= nil do
    self.values[self.readIndex] = nil
    self.readIndex = self.readIndex + 1
    table.insert(values, value)
    value = self.values[self.readIndex]
  end
  return values
end


--- Copies a given Hyperpack class to this instance.
---
--- @param otherClass Hyperpack Hyperpack class to copy from.
--- @return Hyperpack Self instance with values from `otherClass`.
function Hyperpack:copyFrom(otherClass)
  self.format = otherClass.format
  for i, v in pairs(otherClass.values) do
    self.values[i] = v
  end
  self.readOnly = true
  self.readIndex = 1
  return self
end

--- Simple function for packing a table of data. Should not be ran on a HyperPack instance.
---
--- @param someData any Data to pack into a string.
--- @return string Packed HyperPack string.
function Hyperpack.simplePack(someData)
  -- Create instance.
  local instance = Hyperpack:new()
  -- Push some data to the HyperPack instance; functions as if it were a stack.
  instance:pushValue(someData)
  -- Serialize the instance into a string and return the string.
  return instance:serialize()
end

--- Simple function for unpacking a serialized string into a table. Should not be ran on a HyperPack instance.
---
--- @param serialized string Packed HyperPack string to deserialize.
--- @return any,string Data from the serialized string. Can be a single variable or a table of data. Returns false and a reason if the string could not be unpacked.
function Hyperpack.simpleUnpack(serialized)
  -- Create instance.
  local instance = Hyperpack:new()
  -- Deserializes the data from the string into the instance and makes the instance read-only.
  local success, reason = instance:deserializeIntoClass(serialized)
  if(not success) then
    return false, reason
  end
  -- Return the *full data table*.
  if(#instance.values == 1) then
    return true, instance.values[1]
  end
  return true, instance.values
end

return Hyperpack