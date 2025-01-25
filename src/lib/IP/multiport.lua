local event = require("event")
local packetFrag = require("IP.packetFrag").fragmentation
local serialization = require("serialization")

local multiport  = {}
local multiportPort = 500

function multiport.send(packet, skipRegister)
  if(not skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  packetFrag.send(packet.targetMAC, multiportPort, packet)
end

function multiport.broadcast(packet, skipRegister)
  packet.targetMAC = nil
  packet.targetIP = require("IP/IPUtil").util.fromUserFormat("FFFF:FFFF:FFFF:FFFF")
  if(not skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  packetFrag.broadcast(multiportPort, packet)
end

function multiport.requestMessageWithTimeout(packet, skipRegister, broadcast, timeout, attempts, eventCondition)
  local tries = 1
  ::start::
  if(broadcast) then
    multiport.broadcast(packet, skipRegister)
  else
    multiport.send(packet, skipRegister)
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

local function process(_, b, c, targetPort, d, message)
  if(targetPort == require("IP.multiport").multiportPort) then
    local decodedPacket = serialization.unserialize(message)
    event.push("multiport_message", b, c, decodedPacket.targetPort, d, message)
  end
end

local function setup()
  local component = require("component")
  component.modem.open(multiportPort)
end

return {process = process, setup = setup, multiport = multiport, multiportPort = multiportPort}