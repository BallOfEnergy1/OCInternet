--- @class Packet
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

function Packet:new(_, protocol, targetIP, targetPort, data, MAC, noReg)
  if(not noReg) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.protocol = protocol
  local dynPort = math.floor(math.random(49152, 65535)) -- Random dynamic port.
  o.senderPort = dynPort
  o.targetPort = targetPort
  local broadcast = require("IP.IPUtil").fromUserFormat("FFFF:FFFF:FFFF:FFFF")
  if(targetIP == broadcast) then
    o.targetMAC = broadcast
  else
    o.targetMAC = MAC or require("IP.protocols.ARP").resolve(targetIP)
  end
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  o.senderMAC  = _G.IP.modems[addr].MAC
  o.senderIP   = _G.IP.modems[addr].clientIP
  o.targetIP   = targetIP
  o.data       = data
  return o
end

function Packet:build()
  return {
    protocol = self.protocol,
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