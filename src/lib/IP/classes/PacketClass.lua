--- @class Packet
local Packet = {
  header = {
    protocol = nil,
    senderPort = nil,
    targetPort = nil,
    targetMAC = nil,
    senderMAC = nil,
    senderIP = nil,
    targetIP = nil
  },
  data = nil
}

local hyperPack = require("hyperpack")

function Packet:new(_, protocol, targetIP, targetPort, data, MAC, noReg)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  if(protocol == nil) then
    -- Assume overload
    return o
  end
  if(not noReg) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  o.header.protocol = protocol
  local dynPort = math.floor(math.random(49152, 65535)) -- Random dynamic port.
  o.header.senderPort = dynPort
  o.header.targetPort = targetPort
  local broadcast = require("IP.IPUtil").fromUserFormat("FFFF:FFFF:FFFF:FFFF")
  if(targetIP == broadcast) then
    o.header.targetMAC = broadcast
  else
    o.header.targetMAC = MAC or require("IP.protocols.ARP").resolve(targetIP)
  end
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  o.header.senderMAC  = _G.IP.modems[addr].MAC
  o.header.senderIP   = _G.IP.modems[addr].clientIP
  o.header.targetIP   = targetIP
  o.data              = data
  return o
end

local fragLimit = 255 -- Limit packets to fragmenting 10 times.

function Packet:serializeAndFragment(MTU)
  
  assert(type(self.data) == "string", "Packet data expected string, got " .. type(self.data) .. ".")
  
  local packer = hyperPack:new()
  packer:pushValue(self.header)
  packer:pushValue(-1) -- seq
  packer:pushValue(false) -- seqEnd
  local header = packer:serialize()
  packer:pushValue(self.data)
  local fullPacket = packer:serialize()
  
  if(#fullPacket > MTU) then
    local packetsToSend = {}
    
    if(#fullPacket + (#header * fragLimit) > fragLimit * MTU) then
      error("Sent packet would exceed fragmentation limit (" .. fragLimit .. "*" .. MTU .. ").") -- Well shit...
    end
    
    local seq = 0
    local data = self.data
    while seq < fragLimit - 1 and #data > 1 do
      local toSend = data:sub(0, MTU - #header)
      packer:removeLastEntry(3)
      packer:pushValue({seq, #data:sub(MTU - #header) == 0, toSend})
      packetsToSend[#packetsToSend + 1] = packer:serialize()
      data = data:sub(MTU - #header)
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
  self.data = hyperPackClass:popValue()
  return self
end

function Packet:buildFromPacketTable(tableOfPackets)
  
  assert(type(tableOfPackets) == "table", "Packet table expected, got " .. type(self.data) .. ".")
  
  for i, v in pairs(tableOfPackets) do
    local packedString = hyperPack:new()
    packedString:deserializeIntoClass(v)
    local vPacket = Packet:new()
    vPacket:buildFromHyperPack(packedString)
    packedString = nil -- Destroy object since it is no longer of use.
    self.data = self.data .. vPacket.data
  end
  
end

return Packet