---@class Callback
local Callback = {
  id = "",
  callback = function()  end,
  amountCalled = 0,
  errorHandler = function(error) _G.IP.logger.write(debug.traceback(error)) end
}

function Callback:new(callback, errorHandler)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.callback = callback
  if(errorHandler ~= nil) then
    o.errorHandler = errorHandler
  else
    o.errorHandler = function(error) _G.IP.logger.write(debug.traceback(error)) end
  end
  o.id = require("UUID").next()
  o.amountCalled = 0
  return o
end

function Callback:call(...)
  local success, result = pcall(self.callback, ...)
  if(not success) then
    return self.errorHandler(result)
  end
  self.amountCalled = self.amountCalled + 1
  return result
end

return Callback