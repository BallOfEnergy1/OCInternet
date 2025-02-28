local component = require("component")

local event = require("event")

local hyperPack = require("hyperpack")
local Stack = require("IP.classes.StackClass")
local Packet = require("IP.classes.PacketClass")

local fragmentation = {}

local MTU = _G.FRAG and _G.FRAG.staticMTU or 8192

local maxMTU
if(component.modem.maxPacketSize == nil) then
  maxMTU = tonumber(require("computer").getDeviceInfo()[component.modem.address].capacity)
else
  maxMTU = component.modem.maxPacketSize()
end

if(MTU > maxMTU or MTU == -1) then
  MTU = maxMTU
end

MTU = MTU - 2 -- Packet overhead

local function fragmentPacket(modem, port, packet, MAC)
  ---@type Packet
  local packetToSend = packet
  for _, v in pairs(packetToSend:serializeAndFragment(MTU)) do
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

function fragmentation.setup(config)
  if(not _G.FRAG or not _G.FRAG.isInitialized) then
    _G.FRAG = {}
    do
      for i, v in pairs(_G.IP.modems) do
        _G.FRAG[v.MAC] = {}
        _G.FRAG[v.MAC].packetStacks = {}
      end
    end
    _G.FRAG.staticMTU = config.FRAG.staticMTU
    _G.FRAG.fragmentLimit = config.FRAG.fragmentLimit
    _G.FRAG.isInitialized = true
  end
  event.listen("modem_message", fragmentation.receive)
end

function fragmentation.receive(_, receiverMAC, _, targetPort, dist, message)
  -- This is just... terrible.....
  local instance = hyperPack:new()
  instance:deserializeIntoClass(message)
  local temporaryPacket = Packet:new()
  temporaryPacket:buildFromHyperPack(instance)
  if(_G.FRAG[receiverMAC][temporaryPacket.header.targetIP] == nil) then
    _G.FRAG[receiverMAC][temporaryPacket.header.targetIP] = {}
  end
  if(_G.FRAG[receiverMAC][temporaryPacket.header.targetIP][temporaryPacket.header.targetPort] == nil) then
    _G.FRAG[receiverMAC][temporaryPacket.header.targetIP][temporaryPacket.header.targetPort] = Stack:new(_G.FRAG.fragmentLimit)
  end
  -- because i cant stand seeing any more of this bs
  ---@type Stack
  local stack = _G.FRAG[receiverMAC][temporaryPacket.header.targetIP][temporaryPacket.header.targetPort]
  stack:push(temporaryPacket.data)
  if(temporaryPacket.header.seqEnd) then
    local data = ""
    while not stack:isEmpty() do
      data = (stack:pop() or "") .. data
    end
    local temporaryPacket2 = Packet:new()
    temporaryPacket2.header = temporaryPacket.header
    temporaryPacket2.data = data
    require("IP.subnet").receive(receiverMAC, targetPort, dist, temporaryPacket2)
    _G.FRAG[receiverMAC][temporaryPacket.header.targetIP][temporaryPacket.header.targetPort] = nil
  end
end

return fragmentation