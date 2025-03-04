
local packetFrag = require("IP.packetFrag")
local util = require("IP.IPUtil")
local tableUtil = require("tableutil")

--- Subnet library, above hardware packet fragmentation and below the multiport library.
local subnet = {}

--- Sends a packet to the target MAC address or the default gateway depending on the packet target IP.
---
--- @param MAC string Target MAC address.
--- @param port number Target port.
--- @param packet Packet Packet to send.
--- @return nil
function subnet.send(MAC, port, packet)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  if(util.getSubnet(packet.header.senderIP) ~= util.getSubnet(_G.IP.modems[addr].clientIP)) then
    packetFrag.send(require("IP.protocols.ARP").resolve(_G.IP.defaultGateway), port, packet)
  else
    packetFrag.send(MAC, port, packet)
  end
end

--- Broadcasts a packet (no additional processing).
---
--- @param port number Target port.
--- @param packet Packet Packet to send.
--- @return nil
function subnet.broadcast(port, packet)
  packetFrag.broadcast(port, packet)
end

--- Internal subnet library receiver function.
--- @param receiverMAC string Recipient MAC address.
--- @param targetPort number Hardware target port.
--- @param dist number Distance the packet was sent from.
--- @param message Packet Packet received.
function subnet.receive(receiverMAC, targetPort, dist, message)
  ---@type Packet
  local packet = message
  if(util.getSubnet(packet.header.senderIP) == util.getSubnet(_G.IP.modems[receiverMAC].clientIP)
    or tableUtil.tableContainsItem({_G.IP.constants.broadcastIP, _G.IP.constants.internalIP}, packet.header.targetIP)) then
    require("IP.multiport").process(targetPort, dist, message)
  end
end

return subnet