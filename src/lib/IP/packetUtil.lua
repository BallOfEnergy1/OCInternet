
local packetUtil  = {}

function packetUtil.construct(targetIP, targetPort, data)
  local dynPort = math.random(49152, 65535) -- Random dynamic port.
  local newPacket = _G.IP.__packet
  require("IP/protocols/DHCP").registerIfNeeded()
  newPacket.senderPort = dynPort
  newPacket.targetPort = targetPort
  newPacket.targetMAC  = require("IP/protocols/DGARP").resolve(targetIP)
  newPacket.senderMAC  = require("IP/multiport").multiport.getModem().address
  newPacket.senderIP   = _G.IP.clientIP
  newPacket.targetIP   = targetIP
  newPacket.data       = data
  return newPacket
end

function packetUtil.constructWithKnownMAC(targetMAC, targetIP, targetPort, data)
  local dynPort = math.random(49152, 65535) -- Random dynamic port.
  local newPacket = _G.IP.__packet
  require("IP/protocols/DHCP").registerIfNeeded()
  newPacket.senderPort = dynPort
  newPacket.targetPort = targetPort
  newPacket.targetMAC  = targetMAC
  newPacket.senderMAC  = require("IP/multiport").multiport.getModem().address
  newPacket.senderIP   = _G.IP.clientIP
  newPacket.targetIP   = targetIP
  newPacket.data       = data
  return newPacket
end

return packetUtil