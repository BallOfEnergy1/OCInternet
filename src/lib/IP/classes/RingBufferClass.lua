--- @class RingBuffer
--- Ring buffer class for use in protocols like TCP.
local RingBuffer = {
  data = {},
  writeIndex = 0,
  readIndex = 0,
  loopRange = 0
}

--- Creates a new RingBuffer class instance.
---
--- @param loopRange number Maximum size of the buffer before looping around.
--- @return RingBuffer New RingBuffer instance.
function RingBuffer:new(loopRange)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.data = {}
  o.loopRange = loopRange
  o.writeIndex = 0
  o.readIndex = 0
  o.loopRange = 0
  return o
end

--- Writes data to the end of the RingBuffer.
---
--- @param data any Data to add to the RingBuffer.
--- @return boolean|nil Returns `true` if success, `nil` if failed due to overrun.
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

--- Reads data from the top of the RingBuffer.
---
--- @return any Returns the data at the top of the RingBuffer if success, `nil` if no data was found.
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

--- Checks if the RingBuffer has data left to read in the buffer.
---
--- @return boolean Returns `true` if the buffer has data left, `false` otherwise.
function RingBuffer:checkHasData()
  if(self.data[self.readIndex] ~= nil) then
    return true
  end
  return false
end

--- Checks if the RingBuffer will override data if new data is written.
---
--- @return boolean Returns `true` if the buffer is "overrun", `false` otherwise.
function RingBuffer:checkOverrun()
  if(self.data[self.writeIndex] ~= nil) then
    return true
  end
  return false
end

--- Clears the RingBuffer data and indices.
function RingBuffer:clear()
  self.data = {}
  self.writeIndex = 0
  self.readIndex = 0
end

return RingBuffer