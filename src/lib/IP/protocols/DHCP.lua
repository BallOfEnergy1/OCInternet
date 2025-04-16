
local util = require("IP.IPUtil")
local APIPA = require("IP.protocols.APIPA")
local udp = require("IP.protocols.UDP")
local hyperPack = require("hyperpack")

local dhcp = {}

local dhcpServerPort = 67
local dhcpClientPort = 68
local dhcpUDPProtocol = 1

function dhcp.release()
  udp.broadcast(dhcpServerPort, 0x10, dhcpUDPProtocol)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  _G.DHCP.DHCPRegisteredModems[addr] = false
end

function dhcp.setup(config)
  if(not _G.DHCP or not _G.DHCP.isInitialized) then
    _G.DHCP = {}
    do
      _G.DHCP.DHCPRegisteredModems = {}
      _G.DHCP.static         = config.DHCP.static
      _G.DHCP.skipRegister   = false
    end
    _G.DHCP.callback = udp.UDPListen(dhcpClientPort, function(receivedPacket)
      if(receivedPacket.udpProto == dhcpUDPProtocol and receivedPacket.data == 0x11) then
        dhcp.release()
      end
    end)
    _G.DHCP.isInitialized = true
    dhcp.registerIfNeeded()
  end
end

function dhcp.registerIfNeeded()
  if(_G.DHCP.static) then
    return
  end
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  if(not _G.DHCP.DHCPRegisteredModems[addr]) then
    _G.DHCP.skipRegister = true
    _G.IP.modems[addr].clientIP = 0
    local attempts = 2
    local message
    for _ = 1, attempts do
      udp.broadcast(dhcpServerPort, nil, dhcpUDPProtocol)
      message = udp.pullUDP(dhcpClientPort, 2)
      if(message and message.udpProto == dhcpUDPProtocol) then
        break
      end
    end
    if(not message) then
      _G.IP.logger.write("#[DHCP] DHCP Failed (" .. attempts .. " tries), defaulting to APIPA.")
      return APIPA.register()
    end
    --------------------------------------------------------------------------------
    _G.IP.logger.write("#[DHCP] DHCP registration success.")
    _G.DHCP.DHCPRegisteredModems[addr]        = true
    local packer = hyperPack:new()
    local success, reason = packer:deserializeIntoClass(message.data)
    if(not success) then
      _G.IP.logger.write("Failed to unpack DHCP data: " .. reason)
    end
    _G.IP.modems[addr].clientIP               = packer:popValue()
    _G.IP.modems[addr].subnetMask             = packer:popValue()
    _G.IP.modems[addr].defaultGateway         = packer:popValue()
    _G.IP.logger.write("IP: " .. util.toUserFormat(_G.IP.modems[addr].clientIP))
    _G.IP.logger.write("Subnet Mask: " .. util.toUserFormat(_G.IP.modems[addr].subnetMask))
    _G.IP.logger.write("Default Gateway: " .. util.toUserFormat(_G.IP.modems[addr].defaultGateway))
    _G.DHCP.skipRegister = false
  end
end

return dhcp