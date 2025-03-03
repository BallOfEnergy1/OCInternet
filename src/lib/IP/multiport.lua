local subnet = require("IP.subnet")
local netAPI = require("IP.netAPI")
local netAPIInternal = require("IP.netAPIInternal")

local multiport = {}
local multiportPort = 500

function multiport.send(packet, skipRegister)
  if(not skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  netAPIInternal.sendUnicastUnsafe(packet)
  subnet.send(packet.header.targetMAC, multiportPort, packet)
end

function multiport.broadcast(packet, skipRegister)
  packet.header.targetMAC = _G.IP.constants.broadcastMAC
  packet.header.targetIP = _G.IP.constants.broadcastIP
  if(not skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  netAPIInternal.sendBroadcastUnsafe(packet)
  subnet.broadcast(multiportPort, packet)
end

function multiport.pullMessageWithTimeout(timeout, eventCondition)
  local result, timedOut
  local callback
  callback = netAPI.registerReceivingCallback(function(receivingPacket)
    if(eventCondition(receivingPacket)) then
      result = receivingPacket
    end
  end, timeout, function() timedOut = true end)
  while not result and not timedOut do
    os.sleep(0.05)
  end
  netAPI.unregisterCallback(callback)
  return result
end

function multiport.pullMessageWithAttempts(timeout, attempts, eventCondition)
  local tries = 1
  local result
  while result == nil and tries <= attempts do
    result = multiport.pullMessageWithTimeout(timeout, eventCondition)
    if(not result) then
      tries = tries + 1
    end
  end
  if(not result) then
    return nil
  end
  return result
end

function multiport.requestMessageWithTimeout(packet, skipRegister, broadcast, timeout, attempts, eventCondition)
  local tries = 1
  local result
  while result == nil and tries <= attempts do
    if(broadcast) then
      multiport.broadcast(packet, skipRegister)
    else
      multiport.send(packet, skipRegister)
    end
    result = multiport.pullMessageWithTimeout(timeout, eventCondition)
    if(not result) then
      tries = tries + 1
    end
  end
  return result
end

function multiport.process(targetPort, dist, message)
  if(targetPort == multiportPort) then
    netAPIInternal.receiveInboundUnsafe(message, dist)
  end
end

function multiport.setupModem(modem)
  modem.open(multiportPort)
end

return multiport