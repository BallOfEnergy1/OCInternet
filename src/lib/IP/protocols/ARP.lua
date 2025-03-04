
local multiport = require("IP.multiport")
local event = require("event")
local api = require("IP.netAPI")
local Packet = require("IP.classes.PacketClass")
local hyperPack = require("hyperpack")

local arpPort = 3389
local arpProtocol = 2

local arp = {}

local timeout = 300

local function onARPMessage(receivedPacket)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  local packer = hyperPack:new():deserializeIntoClass(receivedPacket.data)
  if(packer:popValue() == 1 --[[ ARP Request ]] and packer:popValue() == _G.IP.modems[addr].clientIP) then
    packer = hyperPack:new()
    packer:pushValue(2) -- ARP Reply
    packer:pushValue(_G.IP.modems[addr].MAC)
    local data = packer:serialize()
    multiport.send(Packet:new(arpProtocol, receivedPacket.header.senderIP, arpPort, data, receivedPacket.header.senderMAC))
  end
end

local function getTimeout(time)
  return time + require("computer").uptime()
end

function arp.resolve(IP)
  for MAC, IPtable in pairs(_G.ARP.cachedMappings) do
    if(IPtable.IP == IP and IPtable.timeout > require("computer").uptime()) then
      return MAC
    elseif IPtable.timeout < require("computer").uptime() then
      arp.trimCache()
    end
  end
  local packer = hyperPack:new()
  packer:pushValue(1) -- ARP Request
  packer:pushValue(IP)
  local data = packer:serialize()
  local packet = Packet:new(arpProtocol, _G.IP.constants.broadcastIP, arpPort, data)
  local message = multiport.requestMessageWithTimeout(packet, true, 3, 1,
    function(message)
      if(message.header.targetPort == arpPort and message.header.protocol == arpProtocol) then
        packer = hyperPack:new():deserializeIntoClass(message.data)
        if(packer:popValue() == 2) then -- ARP Reply
          return packer:popValue()
        end
      end
    end)
  if(message == nil) then
    return nil
  end
  return message.data
end

function arp.trimCache()
  for MAC, IPtable in pairs(_G.ARP.cachedMappings) do
    if(IPtable.timeout > require("computer").uptime()) then
      _G.ARP.cachedMappings[MAC] = nil
    end
  end
end

function arp.updateCache(packet)
  if(packet.header.senderIP == _G.IP.constants.broadcastIP) then
    return
  end
  if(packet.header.senderIP == _G.IP.constants.internalIP or packet.header.targetIP == _G.IP.constants.internalIP) then
    return
  end
  for MAC, IPtable in pairs(_G.ARP.cachedMappings) do
    if(IPtable.IP == packet.header.senderIP and MAC == packet.header.senderMAC) then
      IPtable.timeout = getTimeout(timeout)
    end
  end
  -- IP not found on network.
  _G.ARP.cachedMappings[packet.header.senderMAC] = {IP = packet.header.senderIP, timeout = getTimeout(timeout)} -- 5 minutes (normally would be 240 but bro what this is OC).
  return
end

function arp.setup()
  if(not _G.ARP or not _G.ARP.isInitialized) then
    _G.ARP = {}
    do
      _G.ARP.cachedMappings = {
        -- "mac" = IP, timeout
      }
    end
    _G.ARP.isInitialized = true
    
    _G.ARP.callback = api.registerReceivingCallback(function(message)
      arp.updateCache(message)
      if(message.header.targetPort == arpPort and message.header.protocol == arpProtocol) then
        onARPMessage(message)
      end
    end, nil, nil, "ARP Handler")
    event.timer(timeout * 1.5, arp.trimCache, math.huge)
  end
end

return arp