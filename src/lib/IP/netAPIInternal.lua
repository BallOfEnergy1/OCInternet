--- Do not use this directly unless specifically needed to do so!
--- @class UnsafeNetAPI
local internal = {}

local Packet = require("IP.classes.PacketClass")

--- Internally sends a packet to all listening callbacks on the `RECEIVING` side.
--- @param message Packet Packet that was "received".
--- @param dist number Distance the packet was sent from.
--- @return nil
--- @protected
function internal.receiveInboundUnsafe(message, dist)
  for _, handle in pairs(_G.API.registeredCallbacks.receiving) do
    if(type(handle) == "table") then
      handle:call(Packet:new():copyFrom(message), dist)
    end
  end
end

--- Internally sends a packet to all listening callbacks on the `UNI_SENDING` side.
--- @param message Packet Packet that was "sent".
--- @return nil
--- @protected
function internal.sendUnicastUnsafe(message)
  for _, handle in pairs(_G.API.registeredCallbacks.unicast) do
    if(type(handle) == "table") then
      handle:call(Packet:new():copyFrom(message))
    end
  end
end

--- Internally sends a packet to all listening callbacks on the `MULTI_SENDING` side.
--- @param message Packet Packet that was "sent".
--- @return nil
--- @protected
function internal.sendMulticastUnsafe(message)
  for _, handle in pairs(_G.API.registeredCallbacks.multicast) do
    if(type(handle) == "table") then
      handle:call(Packet:new():copyFrom(message))
    end
  end
end

--- Internally sends a packet to all listening callbacks on the `BROAD_SENDING` side.
--- @param message Packet Packet that was "sent".
--- @return nil
--- @protected
function internal.sendBroadcastUnsafe(message)
  for _, handle in pairs(_G.API.registeredCallbacks.broadcast) do
    if(type(handle) == "table") then
      handle:call(Packet:new():copyFrom(message))
    end
  end
end

return internal