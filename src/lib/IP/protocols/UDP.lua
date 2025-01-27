
local multiport = require("IP.multiport")
local serialization = require("serialization")
local event  = require("event")
local Packet = require("IP.classes.PacketClass")
local util   = require("IP.IPUtil")

local udpProtocol = 4

local udp = {}

function udp.setup()
  if(not _G.UDP or not _G.UDP.isInitialized) then
    _G.UDP = {}
    _G.UDP.listeners = {}
    _G.UDP.isInitialized = true
  end
end

function udp.UDPListen(port, callback)
  udp.setup()
  local func = function(_, _, _, targetPort, _, message)
    if(targetPort == port and serialization.unserialize(message).protocol == udpProtocol) then
      callback(serialization.unserialize(message))
    end
  end
  _G.UDP.listeners[port] = func
  event.listen("multiport_message", func)
end

function udp.UDPIgnore(port)
  udp.setup()
  local success = event.ignore("multiport_message", _G.UDP.listeners[port])
  _G.UDP.listeners[port] = nil
  return success
end

function udp.pullUDP(port, timeout, callback)
  local _, _, _, targetPort, _, message = event.pull(timeout or math.huge, "multiport_message")
  if(targetPort == port and serialization.unserialize(message).protocol == udpProtocol) then
    if(not callback) then
      return serialization.unserialize(message)
    end
    return callback(serialization.unserialize(message))
  end
end

function udp.send(IP, port, payload, protocol, skipRegistration)
  local packet = Packet:new(nil, udpProtocol, IP, port, payload, nil, skipRegistration):build()
  packet.udpProto = protocol
  multiport.send(packet, skipRegistration)
end

function udp.broadcast(port, payload, protocol, skipRegistration)
  local packet = Packet:new(nil, udpProtocol, util.fromUserFormat("FFFF:FFFF:FFFF:FFFF"), port, payload, nil, skipRegistration):build()
  packet.udpProto = protocol
  multiport.broadcast(packet, skipRegistration)
end

return udp