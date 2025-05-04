--- @class Callback
--- Callback class, used for callback registration in the NetAPI class.
local Callback = {
  id = "",
  name = "",
  callback = function()  end,
  amountCalled = 0,
  errorHandler = function(error) _G.IP.logger.write(debug.traceback(error)) end,
  priority = 0
}

--- Creates a new Callback class instance.
---
--- `errorHandler` and `name` are optional fields.
--- @param callback function Function to call when callback is called.
--- @param errorHandler function Error handler to use when callback fails/errors.
--- @param name string Internal name to give callback.
--- @param priority number Optional callback priority.
--- @return Callback New Callback instance.
--- @overload fun(callback:function):Callback
function Callback:new(callback, errorHandler, name, priority)
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
  o.name = name or "Unnamed (" .. o.id:sub(1, 8) .. ")"
  o.amountCalled = 0
  o.priority = priority or 0
  return o
end

--- Calls the callback function with error-catching.
---
--- @param ... any Parameters to call callback with.
--- @return any Value returned from callback or error handler function.
function Callback:call(...)
  local success, result = pcall(self.callback, ...)
  if(not success) then
    return self.errorHandler(result)
  end
  self.amountCalled = self.amountCalled + 1
  return result
end

return Callback