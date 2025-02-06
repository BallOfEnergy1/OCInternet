local event = require("event")
local serialization = require("serialization")
local hyperPack = require("hyperpack")
local subnet = require("IP.subnet")

local multiport  = {}
local multiportPort = 500

function multiport.send(packet, skipRegister)
  if(not skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  if(not _G.IP.disableSendEvents) then
    local packedString = hyperPack:new()
    for _, v in pairs(packet.header) do
      packedString:pushValue(v)
    end
    packedString:pushValue(packet.data)
    event.push("multiport_sent", packet.targetMAC, packet.senderMAC, packet.targetPort, 0, packedString:serialize())
  end
  subnet.send(packet.targetMAC, multiportPort, packet)
end

function multiport.broadcast(packet, skipRegister)
  packet.targetMAC = "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
  packet.targetIP = require("IP/IPUtil").fromUserFormat("FFFF:FFFF:FFFF:FFFF")
  if(not skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  if(not _G.IP.disableSendEvents) then
    local packedString = hyperPack:new()
    for _, v in pairs(packet.header) do
      packedString:pushValue(v)
    end
    packedString:pushValue(packet.data)
    event.push("multiport_broadcast", packet.targetMAC, packet.senderMAC, packet.targetPort, 0, packedString:serialize())
  end
  subnet.broadcast(multiportPort, packet)
end

function multiport.requestMessageWithTimeout(packet, skipRegister, broadcast, timeout, attempts, eventCondition, noSend)
  local tries = 1
  ::start::
  local startingTime = require("computer").uptime()
  local globalTimeout = startingTime + timeout
  if(not noSend) then
    if(broadcast) then
      multiport.broadcast(packet, skipRegister)
    else
      multiport.send(packet, skipRegister)
    end
  end
  ::wait::
  local a, b, c, d, e, f = event.pull(timeout)
  if(a ~= "multiport_message" and a ~= "interrupted") then
    if(require("computer").uptime() > globalTimeout) then
      tries = tries + 1
      if(tries > attempts) then
        return nil
      end
      goto start
    else
      goto wait
    end
  end
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
  end
  goto wait
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