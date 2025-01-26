
local util = require("IP.IPUtil").util
local APIPA = require("IP.protocols.APIPA")
local udp = require("IP.protocols.UDP")

local dhcp = {}

local dhcpServerPort = 27
local dhcpClientPort = 26

function dhcp.release()
  _G.DHCP.DHCPRegistered = false
  udp.broadcast(dhcpServerPort, 0x10, true)
end

function dhcp.setup()
  if(not _G.DHCP or not _G.DHCP.isInitialized) then
    _G.DHCP = {}
    do
      _G.DHCP.DHCPRegistered = false
      local config = {}
      loadfile("/etc/IP.conf", "t", config)()
      _G.DHCP.static         = config.DHCP.static
    end
    udp.UDPListen(dhcpClientPort, function(receivedPacket)
      if(receivedPacket.data == 0x11) then
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
  if(not _G.DHCP.DHCPRegistered) then
    local attempts = 2
    local message, code
    for _ = 1, attempts do
      udp.broadcast(dhcpServerPort, nil, true)
      message, code = udp.pullUDP(dhcpClientPort, 5)
      if(message or code == -1) then break end
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
    _G.DHCP.DHCPRegistered = true
    _G.IP.clientIP       = message.data.registeredIP
    _G.IP.subnetMask     = message.data.subnetMask
    _G.IP.defaultGateway = message.data.defaultGateway
    _G.IP.logger.write("IP: " .. util.toUserFormat(_G.IP.clientIP))
    _G.IP.logger.write("Subnet Mask: " .. util.toUserFormat(_G.IP.subnetMask))
    _G.IP.logger.write("Default Gateway: " .. util.toUserFormat(_G.IP.defaultGateway))
  end
end

return dhcp