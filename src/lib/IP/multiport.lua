local event = require("event")
local serialization = require("serialization")

local subnet = require("IP.subnet")

local multiport  = {}
local multiportPort = 500

function multiport.send(packet, skipRegister)
  if(not skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  subnet.send(packet.targetMAC, multiportPort, packet)
end

function multiport.broadcast(packet, skipRegister)
  packet.targetMAC = "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
  packet.targetIP = require("IP/IPUtil").fromUserFormat("FFFF:FFFF:FFFF:FFFF")
  if(not skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  subnet.broadcast(multiportPort, packet)
end

function multiport.requestMessageWithTimeout(packet, skipRegister, broadcast, timeout, attempts, eventCondition, noSend)
  local tries = 1
  ::start::
  if(not noSend) then
    if(broadcast) then
      multiport.broadcast(packet, skipRegister)
    else
      multiport.send(packet, skipRegister)
    end
  end
  ::wait::
  local a, b, c, d, e, f = event.pullFiltered(timeout, function(name) return name == "multiport_message" or name == "interrupted" end)
  if(a == "interrupted") then
    return nil, -1
  end
  if(a == nil) then
    tries = tries + 1
    if(tries > attempts) then
      return nil
    end
    goto start
  end
  if(eventCondition(a, b, c, d, e, f)) then
    return f
  else
    goto wait
  end
end

function multiport.process(_, receiverMAC, c, targetPort, d, message)
  if(targetPort == multiportPort) then
    local decodedPacket = serialization.unserialize(message)
    event.push("multiport_message", receiverMAC, c, decodedPacket.targetPort, d, message)
  end
end

function multiport.setupModem(modem)
  modem.open(multiportPort)
end

return multiport