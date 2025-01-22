
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

function dhcp.setup()
  if(not _G.DHCP or not _G.DHCP.isInitialized) then
    _G.DHCP = {}
    do
      _G.DHCP.DHCPRegistered = false
      _G.DHCP.static         = true
    end
    event.listen("modem_message", function(_, _, _, targetPort, _, message)
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
    local tries = 1
    ::send::
    _G.IP.logger.write("#[DHCP] Registering via DHCP (attempt #" .. tries .. ")...")
    local packet = _G.IP.__packet
    packet.senderPort = dhcpClientPort -- Server -> Client
    packet.senderIP   = 0
    packet.senderMAC  = multiport.getModem().address
    packet.targetPort = dhcpServerPort -- Client -> Server
    multiport.broadcast(packet, true)
    --------------------------------------------------------------------------------
    ::checkEvent::
    local name, _, _, targetPort, _, message = event.pull(5, "modem_message")
    if(not name) then
      _G.IP.logger.write("#[DHCP] DHCP registration failed, timed out waiting for response.")
      tries = tries + 1
      if(tries > 3) then
        error("#[DHCP] DHCP registration failed.")
      end
      goto send
    end
    if(targetPort ~= dhcpClientPort) then goto checkEvent end
    _G.IP.logger.write("#[DHCP] DHCP registration success.")
    _G.DHCP.DHCPRegistered = true
    _G.IP.clientIP       = serialization.unserialize(message).data.registeredIP
    _G.IP.subnetMask     = serialization.unserialize(message).data.subnetMask
    _G.IP.defaultGateway = serialization.unserialize(message).data.defaultGateway
    _G.IP.logger.write("IP: " .. util.toUserFormat(_G.IP.clientIP))
    _G.IP.logger.write("Subnet Mask: " .. util.toUserFormat(_G.IP.subnetMask))
    _G.IP.logger.write("Default Gateway: " .. util.toUserFormat(_G.IP.defaultGateway))
  end
end

return dhcp