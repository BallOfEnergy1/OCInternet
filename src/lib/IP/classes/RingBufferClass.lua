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
  --self.__index = self
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

function RingBuffer:clear()
  self.data = {}
  self.writeIndex = 0
  self.readIndex = 0
end

return RingBuffer