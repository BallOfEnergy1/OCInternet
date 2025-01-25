
local multiport = require("IP.multiport").multiport
local event = require("event")
local serialization = require("serialization")
local util = require("IP.IPUtil").util
local APIPA = require("IP.protocols.APIPA")

local dhcp = {}

local dhcpServerPort = 27
local dhcpClientPort = 26
local dhcpProtocol = 3

local function onDHCPMessage(receivedPacket)
  if(receivedPacket.data == 0x11) then
    dhcp.flush()
  end
end

function dhcp.flush()
  _G.DHCP.DHCPRegistered = false
end

function dhcp.setup()
  if(not _G.DHCP or not _G.DHCP.isInitialized) then
    _G.DHCP = {}
    do
      _G.DHCP.DHCPRegistered = false
      _G.DHCP.static         = false
    end
    event.listen("multiport_message", function(_, _, _, targetPort, _, message)
      if(targetPort == dhcpClientPort and serialization.unserialize(message).protocol == dhcpProtocol) then
        onDHCPMessage(serialization.unserialize(message))
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
    local packet = _G.IP.__packet
    packet.protocol = dhcpProtocol
    packet.senderPort = dhcpClientPort -- Server -> Client
    packet.senderIP   = 0
    packet.senderMAC  = _G.IP.MAC
    packet.targetPort = dhcpServerPort -- Client -> Server
    local attempts = 2
    local raw, code = multiport.requestMessageWithTimeout(packet, true, true, 2, attempts,
      function(_, _, _, targetPort, _, message) return targetPort == dhcpClientPort and serialization.unserialize(message).protocol == dhcpProtocol end)
    if(raw == nil) then
      if(code == -1) then
        return nil, code
      end
      _G.IP.logger.write("#[DHCP] DHCP Failed (" .. attempts .. " tries), defaulting to APIPA.")
      return APIPA.register()
    end
    local message = serialization.unserialize(raw)
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