--- Do not use this directly unless specifically needed to do so!
--- @class UnsafeNetAPI
local internal = {}

function internal.receiveInboundUnsafe(...)
  for _, handle in pairs(_G.API.registeredCallbacks.receiving) do
    if(type(handle) == "table") then
      handle:call(...)
    end
  end
end

function internal.sendUnicastUnsafe(...)
  for _, handle in pairs(_G.API.registeredCallbacks.unicast) do
    if(type(handle) == "table") then
      handle:call(...)
    end
  end
end

function internal.sendMulticastUnsafe(...)
  for _, handle in pairs(_G.API.registeredCallbacks.multicast) do
    if(type(handle) == "table") then
      handle:call(...)
    end
  end
end

function internal.sendBroadcastUnsafe(...)
  for _, handle in pairs(_G.API.registeredCallbacks.broadcast) do
    if(type(handle) == "table") then
      handle:call(...)
    end
  end
end

return internal