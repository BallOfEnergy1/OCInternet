
local multiport = require("IP.multiport").multiport
local serialization = require("serialization")
local event = require("event")
local packetUtil = require("IP.packetUtil")

local icmpPort = 0
local icmpProtocol = 1

local icmp = {}

local function onICMPMessage(receivedPacket)
  if(receivedPacket.type == 0x1A) then -- ICMP echo request.
    multiport.send(packetUtil.constructWithKnownMAC(
      icmpProtocol,
      receivedPacket.senderMAC,
      receivedPacket.senderIP,
      icmpPort,
      {type = 0x00, payload = receivedPacket.payload} -- ICMP echo reply.
    ))
  end
end

function icmp.send(IP, type, payload)
  local raw = multiport.requestMessageWithTimeout(packetUtil.construct(
    icmpProtocol,
    IP,
    icmpPort,
    {type = type, payload = payload}
  , true, true, 2, 4, function(_, _, _, targetPort, _, message) return targetPort == icmpPort and serialization.unserialize(message).protocol == icmpProtocol end))
  if(raw == nil) then
    _G.IP.logger.write("#[ICMP] ICMP timed out.")
    return
  end
  local message = serialization.unserialize(raw)
  return message
end

function icmp.setup()
  if(not _G.ICMP or not _G.ICMP.isInitialized) then
    _G.ICMP = {}
    _G.ICMP.isInitialized = true
    event.listen("multiport_message", function(_, _, _, targetPort, _, message)
      if(targetPort == icmpPort and serialization.unserialize(message).protocol == icmpProtocol) then
        onICMPMessage(serialization.unserialize(message))
      end
    end)
  end
end

return icmp