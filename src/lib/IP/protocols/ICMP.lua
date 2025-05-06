
local multiport = require("IP.multiport")
local api = require("IP.API.netAPI")
local Packet = require("IP.classes.PacketClass")
local hyperPack = require("hyperpack")

local icmpPort = 0
local icmpProtocol = 1

local icmp = {}

local function onICMPMessage(receivedPacket)
  local packer = hyperPack:new()
  local success = packer:deserializeIntoClass(receivedPacket.data)
  if(not success) then
    return
  end
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
  local senderMAC = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  local packet = Packet:new(senderMAC, icmpProtocol, IP, icmpPort, data)
  if(IP == (_G.ROUTE and _G.ROUTE.routeModem.clientIP or _G.IP.primaryModem.clientIP)) then
    local netAPI = require("IP.API.netAPI")
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
    netAPIInternal.receiveInboundUnsafe(packet, senderMAC, 0)
    if(expectResponse) then
      netAPI.unregisterCallback(callback)
    end
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
    _G.ICMP.callback = api.registerReceivingCallback(function(message)
      if(message.header.targetPort == icmpPort and message.header.protocol == icmpProtocol) then
        onICMPMessage(message)
      end
    end, nil, nil, "ICMP Handler")
  end
end

local function makePayload(size)
  local payload = ""
  local counter = 0x61
  for _ = 0, size do
    payload = payload .. string.char(counter)
    counter = counter + 1
    if(counter > 0x7A) then
      counter = 0x61
    end
  end
  return payload
end

function icmp.ping(IP, payload, attempts)
  if(type(payload) == "number") then
    payload = makePayload(payload)
  end
  if(attempts == nil or type(attempts) ~= "number") then
    attempts = 1
  end
  local result
  for _ = 1, attempts do
    result = icmp.send(IP, 0x1A, payload, true)
    if(result) then
      return result
    end
  end
  return result
end

return icmp