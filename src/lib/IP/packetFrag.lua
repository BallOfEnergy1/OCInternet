local component = require("component")

local serialization = require("serialization")
local event = require("event")

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

local function fragmentPacket(modem, port, packet, MAC)
  packet.seq = math.random(0xFFFFFFFF)
  packet.endSeq = false
  local serialized = serialization.serialize(packet)
  if(#serialized > MTU) then
    local packetSize = #serialized
    local dataToSend = serialization.serialize(packet.data)
    local headerSize = packetSize - #dataToSend + 2 -- Packet overhead.
    local adjustedMTU = MTU
    if(MTU < headerSize) then
      adjustedMTU = MTU + (headerSize - MTU) + 100 -- Plus 100 bytes for extra data.
      if(adjustedMTU > maxMTU) then -- tf
        _G.IP.logger.write("Invalid MTU: " .. adjustedMTU)
        return
      end
    end
    local seq = 0
    local packetCopy = packet
    while #dataToSend >= 1 do
      packetCopy.data = dataToSend:sub(0, adjustedMTU - headerSize)
      packetCopy.seq = seq -- Since no matter what number is put in, the data size shouldn't change, we can do this without worry.
      if(MAC) then
        modem.send(MAC, port, serialization.serialize(packetCopy))
      else
        modem.broadcast(port, serialization.serialize(packetCopy))
      end
      dataToSend = dataToSend:sub(adjustedMTU - headerSize)
      if(#dataToSend < adjustedMTU) then
        packetCopy.endSeq = true -- loop over to last packet.
      end
      seq = seq + 1
    end
    return
  end
  packet.seq = nil
  packet.endSeq = nil
  if(MAC) then
    modem.send(MAC, port, serialization.serialize(packet))
  else
    modem.broadcast(port, serialization.serialize(packet))
  end
end

function fragmentation.send(MAC, port, packet)
  local modem = _G.ROUTE and _G.ROUTE.routeModem.modem or _G.IP.primaryModem.modem
  fragmentPacket(modem, port, packet, MAC)
  event.push("modem_sent", MAC, port, serialization.serialize(packet))
end

function fragmentation.broadcast(port, packet)
  local modem = _G.ROUTE and _G.ROUTE.routeModem.modem or _G.IP.primaryModem.modem
  fragmentPacket(modem, port, packet)
  event.push("modem_broadcast", port, serialization.serialize(packet))
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
  local packet = serialization.unserialize(message)
  if(packet == nil) then
    return -- Drop.
  end
  if(receiverMAC ~= addr or (receiverMAC ~= packet.targetMAC and packet.targetMAC ~= "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")) then
    _G.FRAG[addr].packetCache[packet.senderMAC] = nil
    return
  end
  
  if(not packet.seq) then
    require("IP.subnet").receive(_, receiverMAC, c, targetPort, d, message)
    return
  end
  if(not _G.FRAG[addr].packetCache[packet.senderMAC]) then
    _G.FRAG[addr].packetCache[packet.senderMAC] = {}
  end
  if(not _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort]) then
    _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort] = {}
  end
  local data = _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].data or ""
  _G.FRAG[addr].packetCache[packet.senderMAC][packet.targetPort].data = data .. (packet.data or "")
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