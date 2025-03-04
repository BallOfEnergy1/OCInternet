
local multiport = require("IP.multiport")
local serialization = require("IP.serializationUnsafe")
local api = require("IP.netAPI")
local Packet = require("IP.classes.PacketClass")
local hyperPack = require("hyperpack")

local icmpPort = 0
local icmpProtocol = 1

local icmp = {}

local function onICMPMessage(receivedPacket)
  local packer = hyperPack:new():deserializeIntoClass(receivedPacket.data)
  local type = packer:popValue()
  if(type == 0x1A) then -- ICMP echo request.
    local payload = packer:popValue()
    icmp.send(receivedPacket.header.senderIP, 0x00, payload, false) -- ICMP echo reply.
  end
end

function icmp.send(IP, type, payload, expectResponse)
  local packer = hyperPack:new()
  packer:pushValue(type)
  packer:pushValue(payload)
  local data = packer:serialize()
  local packet = Packet:new(icmpProtocol, IP, icmpPort, data)
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
      end, nil, nil, "ICMP Loopback Handler")
    end
    netAPIInternal.receiveInboundUnsafe(packet, 0)
    return result
  end
  if(expectResponse) then
    local message = multiport.requestMessageWithTimeout(packet, false, 5, 1, function(message) return message.header.targetPort == icmpPort and message.header.protocol == icmpProtocol end)
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
    end, nil, nil, "ICMP Handler")
  end
end

return icmp