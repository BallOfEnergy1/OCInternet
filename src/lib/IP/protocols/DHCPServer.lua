local DHCP = require("IP.protocols.DHCP")
local util = require("IP.IPUtil")
local tableUtil = require("tableutil")
local udp = require("IP.protocols.UDP")
local hyperPack = require("hyperpack")

local dhcpServerPort = 67
local dhcpClientPort = 68
local dhcpUDPProtocol = 1

local dhcpServer = {}

function dhcpServer.flushAllAndNotify() -- This is to prevent the IP space from getting very full. Run this occasionally and clients will not be affected (too much).
  for _, v in pairs(_G.DHCP.allRegisteredMACs) do
    udp.send(v.ip, dhcpClientPort, 0x11, dhcpUDPProtocol)
  end
  _G.DHCP.allRegisteredMACs = {}
  _G.DHCP.IPIndex = 0
end

local function onDHCPMessage(receivedPacket)
  if(receivedPacket.data == 0x10) then
    if(not _G.DHCP.allRegisteredMACs[receivedPacket.header.senderMAC]) then
      return
    end
    _G.DHCP.IPIndex = _G.DHCP.allRegisteredMACs[receivedPacket.header.senderMAC].index
    _G.DHCP.allRegisteredMACs[receivedPacket.header.senderMAC] = nil
    return
  end
  _G.IP.logger.write("#[DHCPServer] Recieved DHCP request from '" .. receivedPacket.header.senderMAC .. "'.")
  local IP
  if(_G.DHCP.allRegisteredMACs[receivedPacket.header.senderMAC] == nil) then
    _G.DHCP.allRegisteredMACs[receivedPacket.header.senderMAC] = {}
  end
  if(_G.DHCP.allRegisteredMACs[receivedPacket.header.senderMAC] ~= nil) then
    IP = _G.DHCP.allRegisteredMACs[receivedPacket.header.senderMAC].ip
  end
  for MAC, reservedIP in pairs(_G.DHCP.userReservedIPs) do
    if(MAC == receivedPacket.header.senderMAC and reservedIP ~= nil) then
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
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  local packer = hyperPack:new()
  packer:pushValue(IP)
  packer:pushValue(_G.DHCP.providedSubnetMask)
  packer:pushValue(_G.IP.modems[addr].defaultGateway)
  local data = packer:serialize()
  udp.send(0, dhcpClientPort, data, dhcpUDPProtocol, receivedPacket.header.senderMAC)
  _G.DHCP.allRegisteredMACs[receivedPacket.header.senderMAC] = {ip = IP, index = _G.DHCP.IPIndex}
end

function dhcpServer.addReservedIP(MAC, IP)
  _G.DHCP.userReservedIPs[MAC] = IP
end

function dhcpServer.removeReservedIP(MAC)
  _G.DHCP.userReservedIPs[MAC] = nil
end

function dhcpServer.setup(config)
  DHCP.setup(config)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  _G.DHCP.providedSubnetMask = _G.IP.modems[addr].subnetMask
  _G.DHCP.subnetIdentifier = util.getSubnet(_G.IP.modems[addr].clientIP)
  _G.DHCP.IPIndex = config.DHCPServer.startingIndex
  _G.DHCP.userReservedIPs = config.DHCPServer.reservedIPs
  _G.DHCP.allRegisteredMACs = {}
  _G.DHCP.systemReservedIPs = {
    0, -- IP 0
    1, -- IP 1
    ~_G.DHCP.providedSubnetMask -- Last IP in the system.
  }
  _G.DHCP.serverCallback = udp.UDPListen(dhcpServerPort, function(packet)
    if(packet.udpProto == dhcpUDPProtocol) then
      onDHCPMessage(packet)
    end
  end)
end

return dhcpServer