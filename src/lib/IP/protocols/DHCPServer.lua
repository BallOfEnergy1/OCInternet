local DHCP = require("IP.protocols.DHCP")
local util = require("IP.IPUtil").util
local Packet = require("IP.packetClass")
local multiport = require("IP.multiport").multiport
local tableUtil = require("tableutil")
local udp = require("IP.protocols.UDP")

local dhcpServerPort = 27
local dhcpClientPort = 26

local dhcpServer = {}

function dhcpServer.flushAllAndNotify() -- This is to prevent the IP space from getting very full. Run this occasionally and clients will not be affected (too much).
  for _, v in pairs(_G.DHCP.allRegisteredMACs) do
    udp.send(v, dhcpClientPort, 0x11)
  end
  _G.DHCP.allRegisteredMACs = {}
  _G.DHCP.IPIndex = 0
end

local function onDHCPMessage(receivedPacket)
  if(receivedPacket.data == 0x10) then
    _G.DHCP.IPIndex = _G.DHCP.allRegisteredMACs[receivedPacket.senderMAC].index
    _G.DHCP.allRegisteredMACs[receivedPacket.senderMAC] = {}
    return
  end
  _G.IP.logger.write("#[DHCPServer] Recieved DHCP request from '" .. receivedPacket.senderMAC .. "'.")
  local IP
  if(_G.DHCP.allRegisteredMACs[receivedPacket.senderMAC] == nil) then
    _G.DHCP.allRegisteredMACs[receivedPacket.senderMAC] = {}
  end
  if(_G.DHCP.allRegisteredMACs[receivedPacket.senderMAC] ~= nil) then
    IP = _G.DHCP.allRegisteredMACs[receivedPacket.senderMAC].ip
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
  multiport.send(Packet:new(4 --[[ UDP ]], 0, dhcpClientPort, {registeredIP = IP, subnetMask = _G.DHCP.providedSubnetMask, defaultGateway = _G.IP.defaultGateway}, receivedPacket.senderMAC):build())
  _G.DHCP.allRegisteredMACs[receivedPacket.senderMAC] = {ip = IP, index = _G.DHCP.IPIndex}
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
  _G.DHCP.providedSubnetMask = _G.IP.subnetMask
  _G.DHCP.subnetIdentifier = util.getSubnet(_G.IP.clientIP)
  local config = {}
  loadfile("/etc/IP.conf", "t", config)()
  _G.DHCP.IPIndex = config.DHCPServer.startingIndex
  _G.DHCP.userReservedIPs = config.DHCPServer.reservedIPs
  _G.DHCP.allRegisteredMACs = {}
  _G.DHCP.systemReservedIPs = {
    0,
    1,
    0xFFFFFFFFFF  -- IP #0, #1, and the last IP in the system.
  }
  udp.UDPListen(dhcpServerPort, onDHCPMessage)
end

return dhcpServer