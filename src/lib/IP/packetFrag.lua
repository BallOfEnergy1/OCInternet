local component = require("component")

local serialization = require("serialization")
local event = require("event")

local hyperPack = require("hyperpack")
local Packet = require("IP.classes.PacketClass")

local fragmentation = {}

local MTU = 8192

local maxMTU
if(component.modem.maxPacketSize == nil) then
  maxMTU = tonumber(require("computer").getDeviceInfo()[component.modem.address].capacity)
else
  maxMTU = component.modem.maxPacketSize()
end

if(MTU > maxMTU) then
  MTU = maxMTU
end

MTU = MTU - 2 -- Packet overhead

local function fragmentPacket(modem, port, packet, MAC)
  for _, v in pairs(packet:serializeAndFragment(MTU)) do
    if(MAC) then
      modem.send(MAC, port, v)
    else
      modem.broadcast(port, v)
    end
  end
end

function fragmentation.send(MAC, port, packet)
  local modem = _G.ROUTE and _G.ROUTE.routeModem.modem or _G.IP.primaryModem.modem
  fragmentPacket(modem, port, packet, MAC)
end

function fragmentation.broadcast(port, packet)
  local modem = _G.ROUTE and _G.ROUTE.routeModem.modem or _G.IP.primaryModem.modem
  fragmentPacket(modem, port, packet)
end

function fragmentation.setup()
  if(not _G.FRAG or not _G.FRAG.isInitialized) then
    _G.FRAG = {}
    do
      for i in pairs(_G.IP.modems) do
        _G.FRAG[i] = {}
        _G.FRAG[i].packetCache = {}
      end
    end
    _G.FRAG.isInitialized = true
  end
  event.listen("modem_message", fragmentation.receive)
end

function fragmentation.receive(_, receiverMAC, c, targetPort, d, message)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  
  local packedString = hyperPack:new()
  local code, result = pcall(packedString:deserializeIntoClass(message))
  if(code == false) then
    return -- Drop.
  end
  local packetCopy = hyperPack:new():copyFrom(packedString)
  
  local protocol = result:popValue()
  local senderPortPacket = packedString:popValue()
  local targetPortPacket = packedString:popValue()
  local targetMAC = packedString:popValue()
  local senderMAC = packedString:popValue()
  local senderIP = packedString:popValue()
  local targetIP = packedString:popValue()
  local seq = packedString:popValue()
  local endSeq = packedString:popValue()
  local packetData = packedString:popValue()
  
  if(receiverMAC ~= addr or (receiverMAC ~= targetMAC and targetMAC ~= "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")) then
    _G.FRAG[addr].packetCache[senderMAC] = nil
    return
  end
  
  if(seq == 0xFFFFFFFF) then
    require("IP.subnet").receive(_, receiverMAC, c, targetPort, d, packetCopy)
    return
  end
  if(not _G.FRAG[addr].packetCache[senderMAC]) then
    _G.FRAG[addr].packetCache[senderMAC] = {}
  end
  if(not _G.FRAG[addr].packetCache[senderMAC][targetPortPacket]) then
    _G.FRAG[addr].packetCache[senderMAC][targetPortPacket] = {}
  end
  local data = _G.FRAG[addr].packetCache[senderMAC][targetPortPacket].data or ""
  _G.FRAG[addr].packetCache[senderMAC][targetPortPacket].data = data .. (packetData or "")
  if(packet.endSeq) then
    -- OOH RAH
    -- Last packet in sequence.
    local unserialized = serialization.unserialize(_G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].data)
    if(unserialized == nil) then
      -- Likely corrupted.
      _G.IP.logger.write("Invalid deserialization on packet.")
      _G.IP.logger.write("Data: " .. _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].data)
      _G.IP.logger.write("Erasing SEQ queue...")
      _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort] = nil
      if(#_G.FRAG[addr].packetCache[packet.senderMAC] == 0) then
        _G.FRAG[addr].packetCache[packet.senderMAC] = nil
      end
      return
    end
    local newPacket = packet
    newPacket.data = unserialized
    require("IP.subnet").receive(_, receiverMAC, c, targetPort, d, serialization.serialize(newPacket))
    _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort] = nil
    if(#_G.FRAG[addr].packetCache[packet.senderMAC] == 0) then
      _G.FRAG[addr].packetCache[packet.senderMAC] = nil
    end
    return -- get out!
  end
  if(_G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].lastSeq == nil) then
    _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].lastSeq = packet.seq
  elseif(packet.seq - 1 ~= _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].lastSeq) then
    _G.IP.logger.write("Out of sequence packet. Expected SEQ: " .. _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].lastSeq + 1 .. ", got " .. packet.seq .. ".")
  end
  _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].lastSeq = packet.seq
end

return fragmentation