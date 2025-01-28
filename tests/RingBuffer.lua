
local RingBuffer = require("src.lib.IP.classes.RingBufferClass")

local buffer = RingBuffer:new(5)
print("Buffer created with size 5.")
print("Write #1 (15): " .. tostring(buffer:writeData(15)))
print("Write #2 (20): " .. tostring(buffer:writeData(20)))
print("Write #3 (25): " .. tostring(buffer:writeData(25)))
print("Write #4 (30): " .. tostring(buffer:writeData(30)))
print("Write #5 (35): " .. tostring(buffer:writeData(35)))

print("Overrun #1 (Expected nil): " .. tostring(buffer:writeData(40)))

print("Read #1 (Expected 15): " .. tostring(buffer:readData()))
print("Read #2 (Expected 20): " .. tostring(buffer:readData()))
print("Read #3 (Expected 25): " .. tostring(buffer:readData()))
print("Read #4 (Expected 30): " .. tostring(buffer:readData()))
print("Read #5 (Expected 35): " .. tostring(buffer:readData()))

print("Underflow #1 (Expected nil): " .. tostring(buffer:readData()))