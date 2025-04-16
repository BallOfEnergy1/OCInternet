
local hyperpack = require("src.lib.hyperpack")

local instance = hyperpack:new()
print("HyperPack instance created.")
print("Push #1 (false).")
instance:pushValue(false)
print("Push #2 (15).")
instance:pushValue(15)
print("Push #3 (0.5).")
instance:pushValue(0.5)
print("Push #4 (255).")
instance:pushValue(255)
print("Push #5 ({1, 2, 3}).")
instance:pushValue({1, 2, 3})

local serialized = instance:serialize()
print("Instance serialization: " .. tostring(serialized))

print("Instance deserialization.")
local success, reason = instance:deserializeIntoClass(serialized)

print("Unpacking success? " .. tostring(success))
if(not success) then
  print("Reason: " .. tostring(reason))
  return
end

print("Is ReadOnly? " .. tostring(instance.readOnly))

print("Pop #1 (Expected false): " .. tostring(instance:popValue()))
print("Pop #2 (Expected 15): " .. tostring(instance:popValue()))
print("Pop #3 (Expected 0.5): " .. tostring(instance:popValue()))
print("Pop #4 (Expected 255): " .. tostring(instance:popValue()))
print("Pop #5.1 (Expected 1): " .. tostring(instance:popValue()))
print("Pop #5.2 (Expected 2): " .. tostring(instance:popValue()))
print("Pop #5.3 (Expected 3): " .. tostring(instance:popValue()))
print()

success = nil
local result
print("Test unpacking invalid string: ABC123456")
success, result = hyperpack.simpleUnpack("ABC123456")
print("Success? " .. tostring(success))
print("Reason: " .. result)
print()

print("Test unpacking invalid string with NUL byte: ABC123" .. string.char(0x00) .. "456")
success, result = hyperpack.simpleUnpack("ABC123" .. string.char(0x00) .. "456")
print("Success? " .. tostring(success))
print("Reason: " .. result)
print()

print("Test unpacking invalid string with NUL byte and version: " .. string.char(0x03) .. "ABC123" .. string.char(0x00) .. "456")
success, result = hyperpack.simpleUnpack(string.char(0x03) .. "ABC123" .. string.char(0x00) .. "456")
print("Success? " .. tostring(success))
print("Reason: " .. result)
print()

print("Test unpacking invalid string with NUL byte, version, and magic byte: " .. string.char(0x03) .. "HABC123" .. string.char(0x00) .. "456")
success, result = hyperpack.simpleUnpack(string.char(0x03) .. "HABC123" .. string.char(0x00) .. "456")
print("Success? " .. tostring(success))
print("Reason: " .. result)