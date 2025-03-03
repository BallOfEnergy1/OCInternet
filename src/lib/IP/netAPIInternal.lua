--- Do not use this directly unless specifically needed to do so!
--- @class UnsafeNetAPI
local internal = {}

local Packet = require("IP.classes.PacketClass")

function internal.receiveInboundUnsafe(message, dist)
  for _, handle in pairs(_G.API.registeredCallbacks.receiving) do
    if(type(handle) == "table") then
      handle:call(Packet:new():copyFrom(message), dist)
    end
  end
end

function internal.sendUnicastUnsafe(message)
  for _, handle in pairs(_G.API.registeredCallbacks.unicast) do
    if(type(handle) == "table") then
      handle:call(Packet:new():copyFrom(message))
    end
  end
end

function internal.sendMulticastUnsafe(message)
  for _, handle in pairs(_G.API.registeredCallbacks.multicast) do
    if(type(handle) == "table") then
      handle:call(Packet:new():copyFrom(message))
    end
  end
end

function internal.sendBroadcastUnsafe(message)
  for _, handle in pairs(_G.API.registeredCallbacks.broadcast) do
    if(type(handle) == "table") then
      handle:call(Packet:new():copyFrom(message))
    end
  end
end

return internal