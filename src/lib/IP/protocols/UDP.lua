
local multiport = require("IP.multiport")
local serialization = require("IP.serializationUnsafe")
local api    = require("IP.API.netAPI")
local Packet = require("IP.classes.PacketClass")
local hyperPack = require("hyperpack")

local udpProtocol = 4

local udp = {}

function udp.UDPListen(port, callback)
  local func = function(message)
    if(message.header.targetPort == port and message.header.protocol == udpProtocol) then
      local packer = hyperPack:new()
      local success, reason = packer:deserializeIntoClass(message.data)
      if(not success) then
        _G.IP.logger.write("Failed to unpack UDP data: " .. reason)
        return
      end
      local tempPacket = Packet:new():copyFrom(message)
      tempPacket.udpProto = packer:popValue()
      tempPacket.udpLength = packer:popValue()
      tempPacket.data = packer:popValue()
      callback(tempPacket)
    end
  end
  local callbackObject = api.registerReceivingCallback(func, nil, nil, "UDP Callback Listener (Port " .. port .. ")")
  return callbackObject
end

function udp.UDPIgnore(callbackObject)
  api.unregisterCallback(callbackObject)
end

function udp.pullUDP(port, timeout, callback)
  local packet = multiport.pullMessageWithTimeout(timeout or math.huge, function(message)
    return message.header.targetPort == port and message.header.protocol == udpProtocol
  end)
  if(packet) then
    local packer = hyperPack:new()
    local success, reason = packer:deserializeIntoClass(packet.data)
    if(not success) then
      _G.IP.logger.write("Failed to unpack UDP data: " .. reason)
    end
    local tempPacket = Packet:new():copyFrom(packet)
    tempPacket.udpProto = packer:popValue()
    tempPacket.udpLength = packer:popValue()
    tempPacket.data = packer:popValue()
    if(not callback) then
      return tempPacket
    end
    return callback(tempPacket)
  end
end

function udp.send(IP, port, payload, protocol, MAC)
  local packer = hyperPack:new()
  packer:pushValue(protocol or 0) -- If 0, just assume some user-defined program has taken the reigns and go with it; separate by ports.
  packer:pushValue(#serialization.serialize(payload)) -- TODO: Change to hyperpack for length det.
  packer:pushValue(type(payload) == "table")
  packer:pushValue(payload)
  local data = packer:serialize()
  local packet = Packet:new(udpProtocol, IP, port, data, MAC)
  multiport.send(packet)
end

function udp.broadcast(port, payload, protocol)
  local packer = hyperPack:new()
  packer:pushValue(protocol or 0) -- If 0, just assume some user-defined program has taken the reigns and go with it; separate by ports.
  packer:pushValue(#serialization.serialize(payload)) -- TODO: Change to hyperpack for length det.
  packer:pushValue(payload or "")
  local data = packer:serialize()
  local packet = Packet:new(udpProtocol, _G.IP.constants.broadcastIP, port, data)
  multiport.broadcast(packet)
end

return udp