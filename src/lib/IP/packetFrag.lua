local component = require("component")

local event = require("event")

local hyperPack = require("hyperpack")
local Stack = require("IP.classes.StackClass")
local Packet = require("IP.classes.PacketClass")
local tableUtil = require("tableutil")

--- Packet fragmentation library, normally developers will not need to interact with this.
local fragmentation = {}

local MTU = _G.FRAG and _G.FRAG.staticMTU or 8192

local maxMTU
if(component.modem.maxPacketSize == nil) then
  -- This hurts me...
  maxMTU = tonumber(require("computer").getDeviceInfo()[component.modem.address].capacity)
else
  maxMTU = component.modem.maxPacketSize()
end

if(MTU > maxMTU or MTU == -1) then
  MTU = maxMTU
end

MTU = MTU - 2 -- Packet overhead

-- Fragments and sends a packet.
--- @param modem table Modem proxy table.
--- @param port number Target port.
--- @param packet Packet Packet to send.
--- @param MAC string MAC address of target.
local function fragmentPacket(modem, port, packet, MAC)
  ---@type Packet
  local packetToSend = packet
  for _, v in pairs(packetToSend:serializeAndFragment(MTU)) do
    if(#v > MTU) then
      error("Packet fragmented incorrectly, size " .. #v .. " > " .. MTU)
    end
    if(MAC) then
      modem.send(MAC, port, v)
    else
      modem.broadcast(port, v)
    end
  end
end

--- Low-level sending of a packet, requires a MAC, port, and a packet.
--- @param MAC string MAC address of target.
--- @param port number Target port.
--- @param packet Packet Packet to send.
function fragmentation.send(MAC, port, packet)
  local modem = _G.ROUTE and _G.ROUTE.routeModem.modem or _G.IP.primaryModem.modem
  fragmentPacket(modem, port, packet, MAC)
end

--- Low-level broadcasting of a packet, requires a port and a packet.
--- @param port number Target port.
--- @param packet Packet Packet to send.
function fragmentation.broadcast(port, packet)
  local modem = _G.ROUTE and _G.ROUTE.routeModem.modem or _G.IP.primaryModem.modem
  fragmentPacket(modem, port, packet)
end

--- Standard setup function, for use during initialization.
--- @private
function fragmentation.setup(config)
  if(not _G.FRAG or not _G.FRAG.isInitialized) then
    --- Global fragmentation library table.
    _G.FRAG = {}
    do
      for _, v in pairs(_G.IP.modems) do
        --- Tables used for packet stacks when defragmenting.
        _G.FRAG[v.MAC] = {
          packetStacks = {}
        }
      end
    end
    --- Static MTU to force (config).
    _G.FRAG.staticMTU = config.FRAG.staticMTU
    --- Fragmentation count limit (config).
    _G.FRAG.fragmentLimit = config.FRAG.fragmentLimit
    --- Initialization token.
    _G.FRAG.isInitialized = true
  end
  event.listen("modem_message", fragmentation.receive)
end

--- Internal packet fragmentation receiver function.
--- @param receiverMAC string Recipient MAC address.
--- @param targetPort number Hardware target port.
--- @param dist number Distance the packet was sent from.
--- @param message Packet Packet received.
function fragmentation.receive(_, receiverMAC, _, targetPort, dist, message)
  -- This is just... terrible.....
  local instance = hyperPack:new()
  instance:deserializeIntoClass(message)
  local temporaryPacket = Packet:new()
  temporaryPacket:buildFromHyperPack(instance)
  if(temporaryPacket.header.targetMAC ~= receiverMAC and temporaryPacket.header.targetMAC ~= _G.IP.constants.broadcastMAC) then
    temporaryPacket = nil
    return
  end
  if(temporaryPacket.header.targetIP ~= _G.IP.modems[receiverMAC].clientIP and tableUtil.tableContainsItem({_G.IP.constants.internalIP, _G.IP.constants.internalIP}, temporaryPacket.header.targetIP)) then
    temporaryPacket = nil
    return
  end
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