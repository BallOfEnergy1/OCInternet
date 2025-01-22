local component = require("component")
local serialization = require("serialization")
local modem = component.modem

local multiport  = {}
local multiportPort = 500

function multiport.send(packet, skipRegister)
  if(not skipRegister) then
    require("IP/protocols/DHCP").registerIfNeeded()
  end
  multiport.getModem().send(packet.targetMAC, multiportPort, serialization.serialize(packet))
end

function multiport.broadcast(packet, skipRegister)
  packet.targetMAC = nil
  packet.targetIP = require("IP/IPUtil").util.fromUserFormat("FFFF:FFFF:FFFF:FFFF")
  if(not skipRegister) then
    require("IP/protocols/DHCP").registerIfNeeded()
  end
  multiport.getModem().broadcast(multiportPort, serialization.serialize(packet))
end

function multiport.getModem()
  return modem
end

return {multiport = multiport, multiportPort = multiportPort}