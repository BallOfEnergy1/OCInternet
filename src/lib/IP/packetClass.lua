
local Packet = {
  protocol = nil,
  senderPort = nil,
  targetPort = nil,
  targetMAC = nil,
  senderMAC = nil,
  senderIP = nil,
  targetIP = nil,
  data = nil
}

function Packet:new(o, protocol, targetIP, targetPort, data, MAC)
  require("IP.protocols.DHCP").registerIfNeeded()
  o = o or {}
  setmetatable(o, self)
  self.protocol = protocol
  local dynPort = math.random(49152, 65535) -- Random dynamic port.
  self.senderPort = dynPort
  self.targetPort = targetPort
  self.targetMAC  = MAC or require("IP.protocols.ARP").resolve(targetIP)
  self.senderMAC  = _G.IP.MAC
  self.senderIP   = _G.IP.clientIP
  self.targetIP   = targetIP
  self.data       = data and require("serialization").serialize(data) or data
  return o
end

function Packet:build()
  return {
    senderPort = self.senderPort,
    targetPort = self.targetPort,
    targetMAC = self.targetMAC,
    senderMAC = self.senderMAC,
    senderIP = self.senderIP,
    targetIP = self.targetIP,
    data = self.data
  }
end

return Packet