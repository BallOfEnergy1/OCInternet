
local packetFrag = require("IP.packetFrag").fragmentation
local util = require("IP.IPUtil").util
local serialization = require("serialization")

local subnet = {}

function subnet.send(MAC, port, packet)
  if(util.getSubnet(packet.senderIP) ~= util.getSubnet(_G.IP.clientIP)) then
    packetFrag.send(_G.IP.defaultGateway, port, packet)
  else
    packetFrag.send(MAC, port, packet)
  end
end

function subnet.broadcast(port, packet)
  packetFrag.broadcast(port, packet)
end

function subnet.receive(_, b, c, targetPort, d, message)
  if(util.getSubnet(serialization.unserialize(message).senderIP) == util.getSubnet(_G.IP.clientIP)
    or serialization.unserialize(message).targetIP == util.fromUserFormat("FFFF:FFFF:FFFF:FFFF") -- Broadcast
    or serialization.unserialize(message).targetIP == util.fromUserFormat("0000:0000:0000:0000") -- Used internally for protocols lower than IPv4.1
  ) then
    require("IP.multiport").process(_, b, c, targetPort, d, message)
  end
end

return subnet