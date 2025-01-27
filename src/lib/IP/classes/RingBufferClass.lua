--- @class RingBuffer
local RingBuffer = {
  data = {},
  writeIndex = 0,
  readIndex = 0,
  loopRange = 0
}

function RingBuffer:new(loopRange)
  local o = RingBuffer
  setmetatable(o, self)
  self.__index = self
  o.loopRange = loopRange
  return o
end

function RingBuffer:writeData(data)
  local bufferOverrun = self:checkOverrun()
  if(bufferOverrun) then return nil end
  self.data[self.writeIndex] = data
  self.writeIndex = self.writeIndex + 1
  if(self.writeIndex >= self.loopRange) then
    self.writeIndex = 0
  end
  return true
end

function RingBuffer:readData()
  local hasData = self:checkHasData()
  if(not hasData) then return nil end
  local data = self.data[self.readIndex]
  self.data[self.readIndex] = nil
  self.readIndex = self.readIndex + 1
  if(self.readIndex >= self.loopRange) then
    self.readIndex = 0
  end
  return data
end

function RingBuffer:checkHasData()
  if(self.data[self.readIndex] ~= nil) then
    return true
  end
  return false
end

function RingBuffer:checkOverrun()
  if(self.data[self.writeIndex] ~= nil) then
    return true
  end
  return false
end


--[[ TESTS
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
]]

return RingBuffer