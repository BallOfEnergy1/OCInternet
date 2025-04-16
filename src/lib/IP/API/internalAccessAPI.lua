
--- This is an API for safely grabbing/setting values inside the network stack.
---
--- Using this in itself is risky, as it allows access to the inner-workings of the network stack.
---
--- This does however make it safer for applications (such as `arp`) to grab internal values (such as the ARP table) without breaking stuff.
local internalAccessAPI = {}

--[[
The API works off of a concept of "access codes", basically a unique pointer to a certain resource in the stack.

The format is as follows:
abc.xyz

The first group defines the library or API to pull from, such as `arp` or `IP`.
The second group defines the resource to access, such as the ARP table (`cachedMappings`) or the current primary modem (`primaryModem`).

A full list of access codes can be found below.

Standard:

IP - General IP handler.
  ip.constants
  ip.logger
  ip.modems
  ip.primaryModem
  ip.isInitialized

frag - Packet fragmentation subsystem.
  frag.staticMTU
  frag.fragmentLimit
  frag.isInitialized

serial - Serialization deprecation library.
  serial.deprecatedNoWarn
  serial.isInitialized

nat - Network Address Translation subsystem.
  nat.connections
  nat.isInitialized

netAPI - Network API.
  api.maxInboundHandles
  api.maxOutboundHandles
  api.allowAttachOutbound
  api.isInitialized

arp - ARP protocol.
  arp.cachedMappings
  arp.isInitialized
  arp.callback
  
dhcp - DHCP protocol.
  Client -
    dhcp.DHCPRegisteredModems
    dhcp.static
    dhcp.skipRegister
    dhcp.callback
    dhcp.isInitialized
  Server -
    dhcp.providedSubnetMask
    dhcp.subnetIdentifier
    dhcp.IPIndex
    dhcp.userReservedIPs
    dhcp.allRegisteredMACs
    dhcp.systemReservedIPs
    dhcp.serverCallback

dns - DNS protocol.
  Client -
    None yet.
  Server -
    dns.recordLocation
    dns.recordCompression
    dns.recordCompressionMode
    dns.serverCallback
    dns.serverIsInitialized

tcp - Transport Control Protocol.
  tcp.sessions
  tcp.allowedPorts
  tcp.isInitialized
  tcp.callback

icmp - ICMP protocol.
  icmp.isInitialized
  icmp.callback
  
route - Router software values.
  route.externalModem
  route.internalModem
  route.routeModem
  route.isInitialized

Shortcuts:
  Shortcut codes are denoted by a leading `s:` for identification purposes.
s:ip.ready                          - If the network stack is ready/initialized.
s:ip.primaryIP                      - The IP of the primary modem.
s:ip.primaryMask                    - The subnet mask of the primary modem.
s:ip.primaryGateway                 - The default gateway of the primary modem.
s:ip.primaryMAC                     - The MAC address of the primary modem.
s:ip.primaryProxy                   - The component proxy of the primary modem.
s:stack.openInboundConnections      - The current inbound connections on the stack.
s:stack.openOutboundConnections     - The current outbound connections on the stack.
]]


--- Grabs a field based on the access code given.
---
--- @param code string Access code of the needed field.
--- @return any Data from the field, returns `nil` and logs internally if the field couldn't be found.
function internalAccessAPI.get(code)
  assert(type(code) == "string", "Access code must be a string.")
  
  if(code:sub(0, 2) == "s:") then -- shortcut code.
    code = code:sub(3)
    local iterator = code:gmatch("[^%.]+")
    local first = iterator()
    local second = iterator()
    if(first == "ip") then
      if(second == "ready") then
        return _G.IP.isInitialized
      elseif(second == "primaryIP") then
        return _G.IP.primaryModem.clientIP
      elseif(second == "primaryMask") then
        return _G.IP.primaryModem.subnetMask
      elseif(second == "primaryGateway") then
        return _G.IP.primaryModem.defaultGateway
      elseif(second == "primaryMAC") then
        return _G.IP.primaryModem.MAC
      elseif(second == "primaryProxy") then
        return _G.IP.primaryModem.modem
      end
    elseif(first == "stack") then -- These two are ripped straight from the netAPI file.
      if(second == "openInboundConnections") then
        return _G.API.registeredCallbacks.receiving.count
      elseif(second == "openInboundConnections") then
        return _G.API.registeredCallbacks.unicast.count +
          _G.API.registeredCallbacks.multicast.count +
          _G.API.registeredCallbacks.broadcast.count
      end
    end
  else
    local iterator = code:gmatch("[^%.]+")
    local first = iterator()
    local second = iterator()
    if(first == "ip") then
      error("Function not implemented.")
    end
  end
end

function internalAccessAPI.set(code, value)
  error("Function not implemented.")
end