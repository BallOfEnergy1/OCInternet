
local multiport = require("IP.multiport")
local serialization = require("IP.serializationUnsafe")
local api = require("IP.netAPI")
local Packet = require("IP.classes.PacketClass")

local icmpPort = 0
local icmpProtocol = 1

local icmp = {}

local function onICMPMessage(receivedPacket)
  local data = receivedPacket.data
  if(data.type == 0x1A) then -- ICMP echo request.
    icmp.send(receivedPacket.header.senderIP, 0x00, serialization.unserialize(data.payload) or data.payload, false) -- ICMP echo reply.
  end
end

function icmp.send(IP, type, payload, expectResponse)
  local packet = Packet:new(icmpProtocol, IP, icmpPort, {type = type, payload = payload})
  if(IP == (_G.ROUTE and _G.ROUTE.routeModem.clientIP or _G.IP.primaryModem.clientIP)) then
    local netAPI = require("IP.netAPI")
    local netAPIInternal = require("IP.netAPIInternal")
    local result, callback
    local eventCondition = function(message) return message.header.targetPort == icmpPort and message.header.protocol == icmpProtocol end
    if(expectResponse) then
      callback = netAPI.registerReceivingCallback(function(receivingPacket)
        if(eventCondition(receivingPacket)) then
          result = receivingPacket
        end
      end)
    end
    netAPIInternal.receiveInboundUnsafe(packet)
    return result
  end
  if(expectResponse) then
    local message = multiport.requestMessageWithTimeout(packet
    , false, false, 5, 1, function(message) return message.header.targetPort == icmpPort and message.header.protocol == icmpProtocol end)
    return message
  else
    multiport.send(packet)
  end
end

function icmp.setup()
  if(not _G.ICMP or not _G.ICMP.isInitialized) then
    _G.ICMP = {}
    _G.ICMP.isInitialized = true
    api.registerReceivingCallback(function(message)
      if(message.header.targetPort == icmpPort and message.header.protocol == icmpProtocol) then
        onICMPMessage(message)
      end
    end)
  end
end

return icmp