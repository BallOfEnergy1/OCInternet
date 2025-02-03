
local multiport = require("IP.multiport")
local serialization = require("serialization")
local event = require("event")
local Packet = require("IP.classes.PacketClass")
local util = require("IP.IPUtil")

local arpPort = 3389
local arpProtocol = 2

local arp = {}

local timeout = 300

local function onARPMessage(receivedPacket)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  if(receivedPacket.data == _G.IP.modems[addr].clientIP) then
    multiport.send(Packet:new(nil, arpProtocol, receivedPacket.senderIP, arpPort, _G.IP.modems[addr].MAC, receivedPacket.senderMAC):build())
  end
end

local function getTimeout(time)
  return time + require("computer").uptime()
end

function arp.resolve(IP, skipRegistration)
  for MAC, IPtable in pairs(_G.ARP.cachedMappings) do
    if(IPtable.IP == IP and IPtable.timeout > require("computer").uptime()) then
      return MAC
    elseif IPtable.timeout < require("computer").uptime() then
      arp.trimCache()
    end
  end
  local packet = Packet:new(nil, arpProtocol, util.fromUserFormat("FFFF:FFFF:FFFF:FFFF"), arpPort, IP, nil, skipRegistration):build()
  local raw, code = multiport.requestMessageWithTimeout(packet, true, true, 3, 1,
    function(_, _, _, targetPort, _, message) return targetPort == arpPort and serialization.unserialize(message).protocol == arpProtocol end)
  if(raw == nil) then
    if(code == -1) then
      return nil, code
    end
    return raw
  end
  return serialization.unserialize(raw).data
end

function arp.trimCache()
  for MAC, IPtable in pairs(_G.ARP.cachedMappings) do
    if(IPtable.timeout > require("computer").uptime()) then
      _G.ARP.cachedMappings[MAC] = nil
    end
  end
end

function arp.updateCache(packet)
  for MAC, IPtable in pairs(_G.ARP.cachedMappings) do
    if(IPtable.IP == packet.senderIP and MAC == packet.senderMAC) then
      IPtable.timeout = getTimeout(timeout)
    end
  end
  -- IP not found on network.
  _G.ARP.cachedMappings[packet.senderMAC] = {IP = packet.senderIP, timeout = getTimeout(timeout)} -- 5 minutes (normally would be 240 but bro what this is OC).
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
    event.listen("multiport_message", function(_, _, _, targetPort, _, message)
      arp.updateCache(serialization.unserialize(message))
      if(targetPort == arpPort and serialization.unserialize(message).protocol == arpProtocol) then
        onARPMessage(serialization.unserialize(message))
      end
    end)
    event.timer(timeout * 1.5, arp.trimCache, math.huge)
  end
end

return arp