
local Callback = require("IP.classes.CallbackClass")

--- @class NetAPI
local api = {}

local function getAmountInboundHandles()
  return _G.API.registeredCallbacks.receiving.count
end

local function getAmountOutboundHandles()
  return _G.API.registeredCallbacks.unicast.count +
    _G.API.registeredCallbacks.multicast.count +
    _G.API.registeredCallbacks.broadcast.count
end

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

function api.setup(config)
  if(not _G.API or not _G.API.isInitialized) then
    _G.API = {}
    _G.API.maxInboundHandles = config.API.maxInboundHandles
    _G.API.maxOutboundHandles = config.API.maxOutboundHandles
    _G.API.allowAttachOutbound = config.API.allowAttachOutbound
    do
      _G.API.registeredCallbacks = {
        receiving = {count = 0},
        unicast = {count = 0},
        multicast = {count = 0},
        broadcast = {count = 0}
      }
    end
    _G.API.isInitialized = true
  end
end

return api