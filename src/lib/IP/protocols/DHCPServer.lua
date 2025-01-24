local DHCP = require("IP.protocols.DHCP")
local util = require("IP.IPUtil").util
local packet = require("IP.packetUtil")
local multiport = require("IP.multiport").multiport
local serialization = require("serialization")
local event = require("event")
local tableUtil = require("tableutil")

local dhcpServerPort = 27
local dhcpClientPort = 26
local dhcpProtocol = 3

local dhcpServer = {}

function dhcpServer.flushAllAndNotify() -- This is to prevent the IP space from getting very full. Run this occasionally and clients will not be affected (too much).
  for i, v in pairs(_G.DHCP.allRegisteredMACs) do
    multiport.send(packet.constructWithKnownMAC(dhcpProtocol, i, v, dhcpClientPort, 0x11)) -- Notify clients to renew their DHCP IP.
  end
  _G.DHCP.allRegisteredMACs = {}
  _G.DHCP.IPIndex = 0
end

local function onDHCPMessage(receivedPacket)
  _G.IP.logger.write("#[DHCPServer] Recieved DHCP request from '" .. receivedPacket.senderMAC .. "'.")
  local IP
  if(_G.DHCP.allRegisteredMACs[receivedPacket.senderMAC] ~= nil) then
    IP = _G.DHCP.allRegisteredMACs[receivedPacket.senderMAC]
  end
  for MAC, reservedIP in pairs(_G.DHCP.userReservedIPs) do
    if(MAC == receivedPacket.senderMAC and reservedIP ~= nil) then
      IP = reservedIP
    end
  end
  if(IP == nil) then
    ::DHCPStart::
    _G.DHCP.IPIndex = _G.DHCP.IPIndex + 1
    if(tableUtil.tableContainsItem(_G.DHCP.systemReservedIPs, _G.DHCP.IPIndex)) then
      goto DHCPStart
    end
    if(tableUtil.tableContainsItem(_G.DHCP.userReservedIPs, _G.DHCP.IPIndex)) then
      goto DHCPStart
    end
    IP = util.createIP(_G.DHCP.subnetIdentifier, _G.DHCP.IPIndex)
  end
  _G.IP.logger.write("#[DHCPServer] Sending IP '" .. IP .. "' to client.")
  multiport.send(packet.constructWithKnownMAC(dhcpProtocol, receivedPacket.senderMAC, 0, dhcpClientPort, {
  registeredIP = IP,
  subnetMask = _G.DHCP.providedSubnetMask,
  defaultGateway = _G.IP.defaultGateway
  }))
  _G.DHCP.allRegisteredMACs[receivedPacket.senderMAC] = IP
end

function dhcpServer.addReservedIP(MAC, IP)
  _G.DHCP.userReservedIPs[MAC] = IP
end

function dhcpServer.removeReservedIP(MAC)
  _G.DHCP.userReservedIPs[MAC] = nil
end

function dhcpServer.setup()
  DHCP.setup()
  local success = pcall(DHCP.registerIfNeeded)
  if(not success) then
    _G.IP.logger.write("#[DHCPServer] No DHCP servers found on this network.")
  end
  _G.DHCP.providedSubnetMask = util.fromUserFormat("FFFF:FF00:0000:0000")
  _G.DHCP.subnetIdentifier = util.getSubnet(util.fromUserFormat("0123:4500:0000:0000"))
  _G.DHCP.IPIndex = 0
  _G.DHCP.userReservedIPs = {}
  _G.DHCP.allRegisteredMACs = {}
  _G.DHCP.systemReservedIPs = {
    0,
    1,
    0xFFFFFFFFFF  -- IP #0, #1, and the last IP in the system.
  }
  event.listen("multiport_message", function(_, _, _, targetPort, _, message)
    if(targetPort == dhcpServerPort and serialization.unserialize(message).protocol == dhcpProtocol) then
      onDHCPMessage(serialization.unserialize(message))
    end
  end)
end

return dhcpServer