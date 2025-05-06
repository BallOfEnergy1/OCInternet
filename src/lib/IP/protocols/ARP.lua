
local multiport = require("IP.multiport")
local event = require("event")
local api = require("IP.API.netAPI")
local Packet = require("IP.classes.PacketClass")
local hyperPack = require("hyperpack")

local arpPort = 3389
local arpProtocol = 2

local arp = {}

local timeout = 300

local function onARPMessage(receivedPacket, MAC)
  local instance = hyperPack:new()
  local success = instance:deserializeIntoClass(receivedPacket.data)
  if(not success) then
    return
  end
  if(instance:popValue() == 1 --[[ ARP Request ]] and instance:popValue() == _G.IP.modems[MAC].clientIP) then
    instance = hyperPack:new()
    instance:pushValue(2) -- ARP Reply
    instance:pushValue(_G.IP.modems[MAC].MAC)
    local data = instance:serialize()
    multiport.send(Packet:new(MAC, arpProtocol, receivedPacket.header.senderIP, arpPort, data, receivedPacket.header.senderMAC))
  end
end

local function getTimeout(time)
  return time + require("computer").uptime()
end

function arp.resolve(IP)
  local modemMAC = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  if(_G.ARP.staticMappings[modemMAC]) then
    for MAC, IPtable in pairs(_G.ARP.staticMappings[modemMAC]) do
      if(IPtable.IP == IP) then
        return MAC
      end
    end
  end
  if(_G.ARP.cachedMappings[modemMAC]) then
    for MAC, IPtable in pairs(_G.ARP.cachedMappings[modemMAC]) do
      if(IPtable.IP == IP and IPtable.timeout > require("computer").uptime()) then
        return MAC
      elseif IPtable.timeout < require("computer").uptime() then
        arp.trimCache()
      end
    end
  end
  local packer = hyperPack:new()
  packer:pushValue(1) -- ARP Request
  packer:pushValue(IP)
  local data = packer:serialize()
  local packet = Packet:new(modemMAC, arpProtocol, _G.IP.constants.broadcastIP, arpPort, data)
  local message = multiport.requestMessageWithTimeout(packet, true, 3, 1,
    function(message)
      if(message.header.targetPort == arpPort and message.header.protocol == arpProtocol) then
        packer = hyperPack:new()
        local success, reason = packer:deserializeIntoClass(message.data)
        if(not success) then
          _G.IP.logger.write("Failed to unpack ARP data: " .. reason)
          return
        end
        if(packer:popValue() == 2) then -- ARP Reply
          return packer:popValue()
        end
      end
    end, modemMAC)
  if(message == nil) then
    return nil
  end
  return message.data
end

function arp.trimCache()
  for modemMAC, interface in pairs(_G.ARP.cachedMappings) do
    for MAC, IPtable in pairs(interface) do
      if(IPtable.timeout < require("computer").uptime()) then
        _G.ARP.cachedMappings[modemMAC][MAC] = nil
      end
    end
  end
end

function arp.updateCache(packet, modemMAC)
  if(packet.header.senderIP == _G.IP.constants.broadcastIP) then
    return
  end
  if(packet.header.senderIP == _G.IP.constants.internalIP or packet.header.targetIP == _G.IP.constants.internalIP) then
    return
  end
  if(not _G.ARP.cachedMappings[modemMAC]) then _G.ARP.cachedMappings[modemMAC] = {} end
  for MAC, IPtable in pairs(_G.ARP.cachedMappings[modemMAC]) do
    if(IPtable.IP == packet.header.senderIP and MAC == packet.header.senderMAC) then
      IPtable.timeout = getTimeout(timeout)
    end
  end
  -- IP not found on network.
  _G.ARP.cachedMappings[modemMAC][packet.header.senderMAC] = {IP = packet.header.senderIP, timeout = getTimeout(timeout)} -- 5 minutes (normally would be 240 but bro what this is OC).
  return
end

function arp.writeToDB()
  require("filesystem").remove(_G.ARP.dbLocation)
  local handle = io.open(_G.ARP.dbLocation, "w")
  local filtered = {}
  for i, v in pairs(_G.ARP.staticMappings) do
    local interface = {}
    for j, w in pairs(v) do
      if(not v.ignore) then
        interface[j] = w
      end
    end
    if(#interface ~= 0) then
      filtered[i] = interface
    end
  end
  handle:write(require("serialization").serialize(filtered))
  handle:close()
end

function arp.setup(config)
  if(not _G.ARP or not _G.ARP.isInitialized) then
    _G.ARP = {}
    _G.ARP.dbLocation = config.ARP.dbLocation
    do
      _G.ARP.cachedMappings = {
        -- "mac" = IP, timeout
      }
      _G.ARP.staticMappings = {
        -- "mac" = IP
      }
      for _, v in pairs(_G.IP.modems) do
        _G.ARP.staticMappings[v.MAC] = {}
        _G.ARP.staticMappings[v.MAC][v.MAC] = {IP = v.clientIP, ignore = true}
      end
      local handle = io.open(_G.ARP.dbLocation, "r")
      if(handle ~= nil) then
        local data = handle:read("*a")
        local staticTable = require("serialization").unserialize(data) -- listen, this is ok only because it's ONLY on initialization. ANYWHERE ELSE, and I'd be shitting myself at the sight of this.
        for _, v in pairs(staticTable) do
          _G.ARP.staticMappings[v.INT][v.MAC] = {IP = v.IP, ignore = false}
        end
        handle:close()
      end
    end
    
    _G.ARP.callback = api.registerReceivingCallback(function(message, _, MAC)
      arp.updateCache(message, MAC)
      if(message.header.targetPort == arpPort and message.header.protocol == arpProtocol) then
        onARPMessage(message, MAC)
      end
    end, nil, nil, "ARP Handler", 2)
    event.timer(timeout * 1.5, arp.trimCache, math.huge)
    _G.ARP.isInitialized = true
  end
end

return arp