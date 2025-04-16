
local Callback = require("IP.classes.CallbackClass")

--- @class NetAPI
--- This library handles everything relating to callbacks in the network stack.
local api = {}

local function getAmountInboundHandles()
  return _G.API.registeredCallbacks.receiving.count
end

local function getAmountOutboundHandles()
  return _G.API.registeredCallbacks.unicast.count +
    _G.API.registeredCallbacks.multicast.count +
    _G.API.registeredCallbacks.broadcast.count
end

--- Registers a callback on the receiving side of the network handler.
---
--- @param callback function Function to call when the callback is triggered.
--- @param timeout number Amount of time to wait before the callback expires and is unregistered. Used for temporary callbacks (optional).
--- @param errorHandler function Error handler to be called when the callback fails internally. This is defined automatically, though can be overridden (optional).
--- @param name string Name of the callback (optional).
--- @overload fun(callback:function):Callback
--- @return Callback Callback object created by the netAPI.
function api.registerReceivingCallback(callback, timeout, errorHandler, name)
  if(getAmountInboundHandles() >= _G.API.maxInboundHandles) then
    (errorHandler or function(error) _G.IP.logger.write(debug.traceback(error)) end)("Too many open callbacks when registering on side 'RECEIVING'.")
  end
  local callbackObject = Callback:new(callback, errorHandler, name)
  if(timeout ~= nil) then
    require("event").timer(timeout, function() callbackObject.errorHandler("Timed out."); api.unregisterCallback(callbackObject) end)
  end
  _G.API.registeredCallbacks.receiving[callbackObject.id] = callbackObject
  local num = _G.API.registeredCallbacks.receiving.count
  _G.API.registeredCallbacks.receiving.count = num + 1
  return callbackObject
end

--- Registers a callback on the unicast (sending) side of the network handler.
---
--- @param callback function Function to call when the callback is triggered.
--- @param timeout number Amount of time to wait before the callback expires and is unregistered. Used for temporary callbacks (optional).
--- @param errorHandler function Error handler to be called when the callback fails internally. This is defined automatically, though can be overridden (optional).
--- @param name string Name of the callback (optional).
--- @overload fun(callback:function):Callback
--- @return Callback Callback object created by the netAPI.
function api.registerUnicastSendingCallback(callback, timeout, errorHandler, name)
  if(getAmountOutboundHandles() >= _G.API.maxOutboundHandles) then
    (errorHandler or function(error) _G.IP.logger.write(debug.traceback(error)) end)("Too many open callbacks when registering on side 'UNI_SENDING'.")
  end
  local callbackObject = Callback:new(callback, errorHandler, name)
  if(timeout ~= nil) then
    require("event").timer(timeout, function() callbackObject.errorHandler("Timed out."); api.unregisterCallback(callbackObject) end)
  end
  _G.API.registeredCallbacks.unicast[callbackObject.id] = callbackObject
  local num = _G.API.registeredCallbacks.unicast.count
  _G.API.registeredCallbacks.unicast.count = num + 1
  return callbackObject
end

--- Registers a callback on the multicast (sending) side of the network handler.
---
--- This callback system is not implemented yet.
--- @param callback function Function to call when the callback is triggered.
--- @param timeout number Amount of time to wait before the callback expires and is unregistered. Used for temporary callbacks (optional).
--- @param errorHandler function Error handler to be called when the callback fails internally. This is defined automatically, though can be overridden (optional).
--- @param name string Name of the callback (optional).
--- @overload fun(callback:function):Callback
--- @return Callback Callback object created by the netAPI.
function api.registerMulticastSendingCallback(callback, timeout, errorHandler, name)
  if(getAmountOutboundHandles() >= _G.API.maxOutboundHandles) then
    (errorHandler or function(error) _G.IP.logger.write(debug.traceback(error)) end)("Too many open callbacks when registering on side 'MULTI_SENDING'.")
  end
  local callbackObject = Callback:new(callback, errorHandler, name)
  if(timeout ~= nil) then
    require("event").timer(timeout, function() callbackObject.errorHandler("Timed out."); api.unregisterCallback(callbackObject) end)
  end
  _G.API.registeredCallbacks.multicast[callbackObject.id] = callbackObject
  local num = _G.API.registeredCallbacks.multicast.count
  _G.API.registeredCallbacks.multicast.count = num + 1
  return callbackObject
end

--- Registers a callback on the broadcast (sending) side of the network handler.
---
--- @param callback function Function to call when the callback is triggered.
--- @param timeout number Amount of time to wait before the callback expires and is unregistered. Used for temporary callbacks (optional).
--- @param errorHandler function Error handler to be called when the callback fails internally. This is defined automatically, though can be overridden (optional).
--- @param name string Name of the callback (optional).
--- @overload fun(callback:function):Callback
--- @return Callback Callback object created by the netAPI.
function api.registerBroadcastSendingCallback(callback, timeout, errorHandler, name)
  if(getAmountOutboundHandles() >= _G.API.maxOutboundHandles) then
    (errorHandler or function(error) _G.IP.logger.write(debug.traceback(error)) end)("Too many open callbacks when registering on side 'BROAD_SENDING'.")
  end
  local callbackObject = Callback:new(callback, errorHandler, name)
  if(timeout ~= nil) then
    require("event").timer(timeout, function() callbackObject.errorHandler("Timed out."); api.unregisterCallback(callbackObject) end)
  end
  _G.API.registeredCallbacks.broadcast[callbackObject.id] = callbackObject
  local num = _G.API.registeredCallbacks.broadcast.count
  _G.API.registeredCallbacks.broadcast.count = num + 1
  return callbackObject
end

--- Unregisters a callback with the network handler.
---
--- This callback system is not implemented yet.
--- @param callback Callback Callback object to unregister (returned when creating a callback).
--- @return nil
function api.unregisterCallback(callback) -- IDs are universally unique so we can do this without incident.
  if(_G.API.registeredCallbacks.receiving[callback.id] ~= nil) then
    _G.API.registeredCallbacks.receiving[callback.id] = nil
    _G.API.registeredCallbacks.receiving.count = _G.API.registeredCallbacks.receiving.count - 1
  elseif(_G.API.registeredCallbacks.unicast[callback.id] ~= nil) then
    _G.API.registeredCallbacks.unicast[callback.id] = nil
    _G.API.registeredCallbacks.unicast.count = _G.API.registeredCallbacks.unicast.count - 1
  elseif(_G.API.registeredCallbacks.multicast[callback.id] ~= nil) then
    _G.API.registeredCallbacks.multicast[callback.id] = nil
    _G.API.registeredCallbacks.multicast.count = _G.API.registeredCallbacks.multicast.count - 1
  elseif(_G.API.registeredCallbacks.broadcast[callback.id] ~= nil) then
    _G.API.registeredCallbacks.broadcast[callback.id] = nil
    _G.API.registeredCallbacks.broadcast.count = _G.API.registeredCallbacks.broadcast.count - 1
  end
end

--- Standard setup function, for use during initialization.
--- @private
function api.setup(config)
  if(not _G.API or not _G.API.isInitialized) then
    _G.API = {}
    --- Maximum number of inbound handles that can be created (config).
    _G.API.maxInboundHandles = config.API.maxInboundHandles
    --- Maximum number of outbound handles that can be created (config).
    _G.API.maxOutboundHandles = config.API.maxOutboundHandles
    --- Whether or not attaching to the outbound callbacks is allowed (config).
    _G.API.allowAttachOutbound = config.API.allowAttachOutbound
    do
      --- Table of all callbacks registered to the API.
      _G.API.registeredCallbacks = {
        receiving = {count = 0},
        unicast = {count = 0},
        multicast = {count = 0},
        broadcast = {count = 0}
      }
    end
    --- Initialization token.
    _G.API.isInitialized = true
  end
end

return api