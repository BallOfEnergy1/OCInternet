--- Do not use this directly unless specifically needed to do so!
--- @class UnsafeNetAPI
local internal = {}

local Packet = require("IP.classes.PacketClass")

--- Internally sends a packet to all listening callbacks on the `RECEIVING` side.
--- @param message Packet Packet that was "received".
--- @param MAC string MAC of the modem that initially received the packet.
--- @param dist number Distance the packet was sent from.
--- @return void
--- @protected
function internal.receiveInboundUnsafe(message, MAC, dist)
  local time = require("computer").uptime()
  for _, priorityLevel in pairs(_G.API.registeredCallbacks.receiving) do
    if(type(priorityLevel) == "table") then
      for _, handle in pairs(priorityLevel) do
        if(type(handle) == "table") then
          handle:call(Packet:new():copyFrom(message), time, MAC, dist)
        end
      end
    end
  end
end

--- Internally sends a packet to all listening callbacks on the `UNI_SENDING` side.
--- @param message Packet Packet that was "sent".
--- @param MAC string MAC of the modem that initially sent the packet.
--- @return void
--- @protected
function internal.sendUnicastUnsafe(message, MAC)
  local time = require("computer").uptime()
  for _, priorityLevel in pairs(_G.API.registeredCallbacks.unicast) do
    if(type(priorityLevel) == "table") then
      for _, handle in pairs(priorityLevel) do
        if(type(handle) == "table") then
          handle:call(Packet:new():copyFrom(message), time, MAC)
        end
      end
    end
  end
end

--- Internally sends a packet to all listening callbacks on the `MULTI_SENDING` side.
--- @param message Packet Packet that was "sent".
--- @param MAC string MAC of the modem that initially sent the packet.
--- @return void
--- @protected
function internal.sendMulticastUnsafe(message, MAC)
  local time = require("computer").uptime()
  for _, priorityLevel in pairs(_G.API.registeredCallbacks.multicast) do
    if(type(priorityLevel) == "table") then
      for _, handle in pairs(priorityLevel) do
        if(type(handle) == "table") then
          handle:call(Packet:new():copyFrom(message), time, MAC)
        end
      end
    end
  end
end

--- Internally sends a packet to all listening callbacks on the `BROAD_SENDING` side.
--- @param message Packet Packet that was "sent".
--- @param MAC string MAC of the modem that initially sent the packet.
--- @return void
--- @protected
function internal.sendBroadcastUnsafe(message, MAC)
  local time = require("computer").uptime()
  for _, priorityLevel in pairs(_G.API.registeredCallbacks.broadcast) do
    if(type(priorityLevel) == "table") then
      for _, handle in pairs(priorityLevel) do
        if(type(handle) == "table") then
          handle:call(Packet:new():copyFrom(message), time, MAC)
        end
      end
    end
  end
end

return internal