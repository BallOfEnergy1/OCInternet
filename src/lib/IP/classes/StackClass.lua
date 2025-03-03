--- @class Stack
local Stack = {
  data = {},
  maxSize = 0,
  size = 0
}

function Stack:new(maxSize)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.maxSize = maxSize
  o.data = {}
  o.size = 0
  return o
end

function Stack:push(data)
  if(type(data) == "table") then
    for _, v in pairs(data) do
      self:push(v)
    end
  end
  if(self:isFull()) then
    error("Stack Overflow, size: " .. self.size)
  end
  self.size = self.size + 1
  self.data[self.size] = data
  return true
end

function Stack:pop()
  local data = self:peek()
  self.data[self.size] = nil;
  self.size = self.size - 1
  return data
end

function Stack:peek()
  if(self:isEmpty()) then
    error("Stack Underflow, size: " .. self.size)
  end
  return self.data[self.size]
end

function Stack:isEmpty()
  return self.size <= 0
end

function Stack:isFull()
  return self.size >= self.maxSize
end

function Stack:clear()
  self.data = {}
  self.size = 0
end

return Stack