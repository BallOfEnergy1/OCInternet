
local util = require("IP.IPUtil")
local APIPA = require("IP.protocols.APIPA")
local udp = require("IP.protocols.UDP")

local dhcp = {}

local dhcpServerPort = 67
local dhcpClientPort = 68
local dhcpUDPProtocol = 1

function dhcp.release()
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  _G.DHCP.DHCPRegisteredModems[addr] = false
  udp.broadcast(dhcpServerPort, 0x10, dhcpUDPProtocol, true)
end

function dhcp.setup(config)
  if(not _G.DHCP or not _G.DHCP.isInitialized) then
    _G.DHCP = {}
    do
      _G.DHCP.DHCPRegisteredModems = {}
      _G.DHCP.static         = config.DHCP.static
    end
    udp.UDPListen(dhcpClientPort, function(receivedPacket)
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
    local attempts = 2
    local message, code
    for _ = 1, attempts do
      udp.broadcast(dhcpServerPort, nil, dhcpUDPProtocol, true)
      message, code = udp.pullUDP(dhcpClientPort, 2)
      if(message and message.udpProto == dhcpUDPProtocol) then
        break
      end
      if(code == -1) then
        break
      end
    end
    if(code == -1) then
      return nil, code
    end
    if(not message) then
      _G.IP.logger.write("#[DHCP] DHCP Failed (" .. attempts .. " tries), defaulting to APIPA.")
      return APIPA.register()
    end
    --------------------------------------------------------------------------------
    _G.IP.logger.write("#[DHCP] DHCP registration success.")
    _G.DHCP.DHCPRegisteredModems[addr]        = true
    _G.IP.modems[addr].clientIP               = message.data.registeredIP
    _G.IP.modems[addr].subnetMask             = message.data.subnetMask
    _G.IP.modems[addr].defaultGateway         = message.data.defaultGateway
    _G.IP.logger.write("IP: " .. util.toUserFormat(_G.IP.modems[addr].clientIP))
    _G.IP.logger.write("Subnet Mask: " .. util.toUserFormat(_G.IP.modems[addr].subnetMask))
    _G.IP.logger.write("Default Gateway: " .. util.toUserFormat(_G.IP.modems[addr].defaultGateway))
  end
end

return dhcp