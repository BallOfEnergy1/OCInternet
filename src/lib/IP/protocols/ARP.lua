
local multiport = require("IP.multiport").multiport
local serialization = require("serialization")
local event = require("event")
local Packet = require("IP.packetClass")

local arpPort = 3389
local arpProtocol = 2

local arp = {}

local timeout = 300

local function onARPMessage(receivedPacket)
  if(receivedPacket.data == _G.IP.clientIP) then
    multiport.send(Packet:new(arpProtocol, receivedPacket.senderIP, arpPort, _G.IP.MAC, receivedPacket.senderMAC):build())
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
  local packet = Packet:new(arpProtocol, nil, arpPort, IP)
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