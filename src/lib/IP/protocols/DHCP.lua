
local multiport = require("IP/multiport").multiport
local event = require("event")
local serialization = require("serialization")
local util = require("IP/IPUtil").util

local dhcp = {}

local dhcpServerPort = 27
local dhcpClientPort = 26

local function onDHCPMessage(receivedPacket)
  if(receivedPacket.data == 0x11) then
    dhcp.flush()
  end
end

function dhcp.flush()
  _G.DHCP.DHCPRegistered = false
end

local function setup()
  if(not _G.DHCP or not _G.DHCP.isInitialized) then
    _G.DHCP = {}
    do
      _G.DHCP.DHCPRegistered = false
      _G.DHCP.static         = true
    end
    event.listen("multiport_message", function(_, _, _, targetPort, _, message)
      if(targetPort == dhcpClientPort) then
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
    packet.senderPort = dhcpClientPort -- Server -> Client
    packet.senderIP   = 0
    packet.senderMAC  = _G.IP.MAC
    packet.targetPort = dhcpServerPort -- Client -> Server
    local raw = multiport.requestMessageWithTimeout(packet, true, true, 2, 3, function(_, _, _, targetPort) return targetPort == dhcpClientPort end)
    if(raw == nil) then
      _G.IP.logger.write("#[DHCP] DHCP Failed (3 tries).")
      return
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

return {dhcp = dhcp, setup = setup}