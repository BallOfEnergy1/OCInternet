--- @class Packet
local Packet = {
  header = {
    protocol = nil,
    senderPort = nil,
    targetPort = nil,
    targetMAC = nil,
    senderMAC = nil,
    senderIP = nil,
    targetIP = nil,
    seq = 1,
    seqEnd = true
  },
  data = nil
}

local hyperPack = require("hyperpack")

function Packet:new(protocol, targetIP, targetPort, data, MAC)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  if(protocol == nil) then
    -- Assume overload
    o.header = {
      protocol = 0,
      senderPort = 0,
      targetPort = 0,
      targetMAC = "",
      senderMAC = "",
      senderIP = 0,
      targetIP = 0,
      seq = 1,
      seqEnd = true
    }
    o.data = ""
    return o
  end
  if(not _G.DHCP.skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  o.header.protocol = protocol
  local dynPort = math.floor(math.random(49152, 65535)) -- Random dynamic port.
  o.header.senderPort = dynPort
  o.header.targetPort = targetPort
  if(targetIP == _G.IP.constants.broadcastIP) then
    o.header.targetMAC = _G.IP.constants.broadcastMAC
  else
    o.header.targetMAC = MAC or require("IP.protocols.ARP").resolve(targetIP)
  end
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  o.header.senderMAC  = _G.IP.modems[addr].MAC
  o.header.senderIP   = _G.IP.modems[addr].clientIP
  o.header.targetIP   = targetIP
  o.data              = data
  o.seq = 1
  o.seqEnd = true
  return o
end

function Packet:serialize()
  assert(type(self.data) ~= "table", "Packet data expected string, got " .. type(self.data) .. ".")
  local packer = hyperPack:new()
  packer:pushValue({self.header, self.data})
  local fullPacket = packer:serialize()
  return fullPacket
end

function Packet:serializeAndFragment(MTU)
  
  assert(type(self.data) ~= "table", "Packet data expected string, got " .. type(self.data) .. ".")
  
  local packer = hyperPack:new()
  packer:pushValue(self.header.protocol)
  packer:pushValue(self.header.senderPort)
  packer:pushValue(self.header.targetPort)
  packer:pushValue(self.header.targetMAC)
  packer:pushValue(self.header.senderMAC)
  packer:pushValue(self.header.senderIP)
  packer:pushValue(self.header.targetIP)
  packer:pushValue(self.header.seq)
  packer:pushValue(self.header.seqEnd)
  packer:pushValue("c" .. #(self.data or ""))
  local header = packer:serialize()
  packer:removeLastEntry()
  packer:pushValue(self.data or "")
  local fullPacket = packer:serialize()
  
  if(#fullPacket > MTU) then
    local packetsToSend = {}
    
    local fragLimit = _G.FRAG.fragmentLimit
    
    if(#fullPacket + (#header * (fragLimit - 1)) > fragLimit * MTU) then
      error("Sent packet would exceed fragmentation limit (" .. fragLimit .. "*" .. MTU .. ").") -- Well shit...
    end
    
    local seq = 1
    local data = self.data
    while seq < fragLimit - 1 and #data > 1 do
      local toSend = data:sub(0, MTU - #header)
      packer:removeLastEntry(3)
      packer:pushValue(seq)
      packer:pushValue(#data:sub(MTU - #header) == 0)
      packer:pushValue(toSend)
      packetsToSend[#packetsToSend + 1] = packer:serialize()
      data = data:sub(MTU - #header)
      seq = seq + 1
    end
    return packetsToSend
  end
  return {fullPacket}
end

function Packet:buildFromHyperPack(hyperPackClass)
  self.header.protocol = hyperPackClass:popValue()
  self.header.senderPort = hyperPackClass:popValue()
  self.header.targetPort = hyperPackClass:popValue()
  self.header.targetMAC = hyperPackClass:popValue()
  self.header.senderMAC = hyperPackClass:popValue()
  self.header.senderIP = hyperPackClass:popValue()
  self.header.targetIP = hyperPackClass:popValue()
  self.header.seq = hyperPackClass:popValue()
  self.header.seqEnd = hyperPackClass:popValue()
  self.data = hyperPackClass:popValue()
  return self
end

function Packet:copyFrom(otherPacket)
  self.header.protocol = otherPacket.header.protocol
  self.header.senderPort = otherPacket.header.senderPort
  self.header.targetPort = otherPacket.header.targetPort
  self.header.targetMAC = otherPacket.header.targetMAC
  self.header.senderMAC = otherPacket.header.senderMAC
  self.header.senderIP = otherPacket.header.senderIP
  self.header.targetIP = otherPacket.header.targetIP
  self.header.seq = otherPacket.header.seq
  self.header.seqEnd = otherPacket.header.seqEnd
  self.data = otherPacket.data -- please be a string
  return self
end

return Packet