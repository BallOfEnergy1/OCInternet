local component = require("component")
local modem = component.modem

local serialization = require("serialization")
local event = require("event")

local fragmentation = {}

local MTU = 60

local maxMTU
if(modem.maxPacketSize == nil) then
  maxMTU = tonumber(require("computer").getDeviceInfo()[modem.address].capacity)
else
  maxMTU = modem.maxPacketSize()
end

if(MTU > maxMTU) then
  MTU = maxMTU
end

local function fragmentPacket(MAC, port, packet)
  if(#serialization.serialize(packet) > MTU) then
    packet.seq = math.random(0xFFFFFFFF)
    local packetSize = #serialization.serialize(packet)
    local dataToSend = serialization.serialize(packet.data)
    local headerSize = packetSize - #dataToSend + 2 -- Packet overhead.
    local adjustedMTU
    if(MTU < headerSize) then
      adjustedMTU = MTU + (headerSize - MTU) + 100 -- Plus 100 bytes for extra data.
      if(adjustedMTU > maxMTU) then -- tf
        _G.IP.logger.write("Invalid MTU: " .. adjustedMTU)
        return
      end
    end
    local seq = 1
    local packetCopy = packet
    while #dataToSend >= 1 do
      if(packet) then
        packetCopy.data = dataToSend:sub(0, seq * adjustedMTU - headerSize)
        packetCopy.seq = seq -- Since no matter what number is put in, the data size shouldn't change, we can do this without worry.
        modem.send(MAC, port, serialization.serialize(packetCopy))
      else
        port.data = dataToSend:sub(0, seq * adjustedMTU - headerSize)
        port.seq = seq -- Here too.
        modem.broadcast(MAC, serialization.serialize(port)) -- MAC is now port and port is now packet.
      end
      dataToSend = dataToSend:sub((seq) * adjustedMTU - headerSize)
      seq = seq + 1
    end
    if(packet) then
      packetCopy.data = nil
      packetCopy.seq = seq
      modem.send(MAC, port, serialization.serialize(packetCopy))
    else
      port.data = nil
      port.seq = seq
      modem.broadcast(MAC, serialization.serialize(port)) -- MAC is now port and port is now packet.
    end
  end
  if(packet) then
    modem.send(MAC, port, serialization.serialize(packet))
  else
    modem.broadcast(MAC, serialization.serialize(port)) -- MAC is now port and port is now packet.
  end
end

function fragmentation.send(MAC, port, packet)
  fragmentPacket(MAC, port, packet)
end

function fragmentation.broadcast(port, packet)
  fragmentPacket(port, packet)
end

local function setup()
  if(not _G.FRAG or not _G.FRAG.isInitialized) then
    _G.FRAG = {}
    do
      _G.FRAG.packetCache = {}
    end
    event.listen("modem_message", fragmentation.receive)
    _G.FRAG.isInitialized = true
  end
end

function fragmentation.receive(_, b, c, targetPort, d, message)
  local packet = serialization.unserialize(message)
  if(not packet.seq) then
    require("IP.multiport").process(_, b, c, targetPort, d, message)
  else
    if(not _G.FRAG.packetCache[packet.senderMAC]) then
      _G.FRAG.packetCache[packet.senderMAC] = {}
    end
    if(not _G.FRAG.packetCache[packet.senderMAC][packet.targetPort]) then
      _G.FRAG.packetCache[packet.senderMAC][packet.targetPort] = {}
    end
    if(_G.FRAG.packetCache[packet.senderMAC][packet.targetPort].lastSeq == packet.seq) then
      -- OOH RAH
      -- Last packet in sequence.
      if(serialization.unserialize(_G.FRAG.packetCache[packet.senderMAC][packet.targetPort].data) == nil) then
        -- Likely corrupted.
        _G.IP.logger.write("Invalid deserialization on packet.")
        _G.IP.logger.write("Data: " .. _G.FRAG.packetCache[packet.senderMAC][packet.targetPort].data)
        return
      end
      local newPacket = packet
      newPacket.data = serialization.unserialize(_G.FRAG.packetCache[packet.senderMAC][packet.targetPort].data)
      require("IP.multiport").process(_, b, c, targetPort, d, serialization.serialize(newPacket))
      _G.FRAG.packetCache[packet.senderMAC][packet.targetPort] = nil
      if(#_G.FRAG.packetCache[packet.senderMAC] == 0) then
        _G.FRAG.packetCache[packet.senderMAC] = nil
      end
      return -- get out!
    end
    local data = _G.FRAG.packetCache[packet.senderMAC][packet.targetPort].data or ""
    _G.FRAG.packetCache[packet.senderMAC][packet.targetPort].data = data .. (packet.data or "")
    if(_G.FRAG.packetCache[packet.senderMAC][packet.targetPort].lastSeq == nil) then
      _G.FRAG.packetCache[packet.senderMAC][packet.targetPort].lastSeq = packet.seq
    elseif(packet.seq - 1 ~= _G.FRAG.packetCache[packet.senderMAC][packet.targetPort].lastSeq) then
      _G.IP.logger.write("Out of sequence packet. Expected SEQ: " .. _G.FRAG.packetCache[packet.senderMAC][packet.targetPort].lastSeq + 1 .. ", got " .. packet.seq .. ".")
    end
    _G.FRAG.packetCache[packet.senderMAC][packet.targetPort].lastSeq = packet.seq
  end
end

return {fragmentation = fragmentation, setup = setup}