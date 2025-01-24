
local packetUtil  = {}

function packetUtil.construct(protocol, targetIP, targetPort, data)
  local dynPort = math.random(49152, 65535) -- Random dynamic port.
  local newPacket = _G.IP.__packet
  require("IP.protocols.DHCP").registerIfNeeded()
  newPacket.protocol = protocol
  newPacket.senderPort = dynPort
  newPacket.targetPort = targetPort
  newPacket.targetMAC  = require("IP.protocols.ARP").resolve(targetIP)
  newPacket.senderMAC  = _G.IP.MAC
  newPacket.senderIP   = _G.IP.clientIP
  newPacket.targetIP   = targetIP
  newPacket.data       = data
  return newPacket
end

function packetUtil.constructWithKnownMAC(protocol, targetMAC, targetIP, targetPort, data)
  local dynPort = math.random(49152, 65535) -- Random dynamic port.
  local newPacket = _G.IP.__packet
  require("IP.protocols.DHCP").registerIfNeeded()
  newPacket.protocol = protocol
  newPacket.senderPort = dynPort
  newPacket.targetPort = targetPort
  newPacket.targetMAC  = targetMAC
  newPacket.senderMAC  = _G.IP.MAC
  newPacket.senderIP   = _G.IP.clientIP
  newPacket.targetIP   = targetIP
  newPacket.data       = data
  return newPacket
end

return packetUtil