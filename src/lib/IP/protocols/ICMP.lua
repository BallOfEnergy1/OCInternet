
local multiport = require("IP.multiport").multiport
local serialization = require("serialization")
local event = require("event")
local Packet = require("IP.packetClass")

local icmpPort = 0
local icmpProtocol = 1

local icmp = {}

local function onICMPMessage(receivedPacket)
  local data = serialization.unserialize(receivedPacket.data)
  if(data.type == 0x1A) then -- ICMP echo request.
    icmp.send(receivedPacket.senderIP, 0x00, serialization.unserialize(data.payload) or data.payload, false) -- ICMP echo reply.
  end
end

function icmp.send(IP, type, payload, expectResponse)
  local packet = Packet:new(icmpProtocol, IP, icmpPort, {type = type, payload = payload}):build()
  if(expectResponse) then
    local raw, code = multiport.requestMessageWithTimeout(packet
    , false, false, 5, 1, function(_, _, _, targetPort, _, message) return targetPort == icmpPort and serialization.unserialize(message).protocol == icmpProtocol end)
    if(raw == nil) then
      if(code == -1) then
        return nil, code
      end
      _G.IP.logger.write("#[ICMP] ICMP timed out.")
      return
    end
    local message = serialization.unserialize(raw)
    return message
  else
    multiport.send(packet, false)
  end
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