
local packetFrag = require("IP.packetFrag")
local util = require("IP.IPUtil")
local serialization = require("serialization")

local subnet = {}

function subnet.send(MAC, port, packet)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  if(util.getSubnet(packet.senderIP) ~= util.getSubnet(_G.IP.modems[addr].clientIP)) then
    packetFrag.send(require("IP.protocols.ARP").resolve(_G.IP.defaultGateway, true), port, packet)
  else
    packetFrag.send(MAC, port, packet)
  end
end

function subnet.broadcast(port, packet)
  packetFrag.broadcast(port, packet)
end

function subnet.receive(_, b, c, targetPort, d, message)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  if(util.getSubnet(serialization.unserialize(message).senderIP) == util.getSubnet(_G.IP.modems[addr].clientIP)
    or serialization.unserialize(message).targetIP == util.fromUserFormat("FFFF:FFFF:FFFF:FFFF") -- Broadcast
    or serialization.unserialize(message).targetIP == util.fromUserFormat("0000:0000:0000:0000") -- Used internally for protocols lower than IPv4.1 or DHCP.
  ) then
    require("IP.multiport").process(_, b, c, targetPort, d, message)
  end
end

return subnet