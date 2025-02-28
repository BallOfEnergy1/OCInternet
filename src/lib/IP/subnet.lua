
local packetFrag = require("IP.packetFrag")
local util = require("IP.IPUtil")
local tableUtil = require("tableutil")

local subnet = {}

function subnet.send(MAC, port, packet)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  if(util.getSubnet(packet.header.senderIP) ~= util.getSubnet(_G.IP.modems[addr].clientIP)) then
    packetFrag.send(require("IP.protocols.ARP").resolve(_G.IP.defaultGateway, true), port, packet)
  else
    packetFrag.send(MAC, port, packet)
  end
end

function subnet.broadcast(port, packet)
  packetFrag.broadcast(port, packet)
end

function subnet.receive(receiverMAC, targetPort, dist, message)
  ---@type Packet
  local packet = message
  if(util.getSubnet(packet.header.senderIP) == util.getSubnet(_G.IP.modems[receiverMAC].clientIP)
    or tableUtil.tableContainsItem({_G.IP.constants.broadcastIP, _G.IP.constants.internalIP}, packet.header.targetIP)) then
    require("IP.multiport").process(targetPort, dist, message)
  end
end

return subnet