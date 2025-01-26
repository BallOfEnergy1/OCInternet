
local multiport = require("IP.multiport").multiport
local serialization = require("serialization")
local event = require("event")
local Packet = require("IP.packetClass")
local util = require("IP.IPUtil").util

local tcpProtocol = 5

local tcp = {}

local TCPHeader = {
  -- 0          0          0          0
  -- 2^3 = FIN, 2^2 = SYN, 2^1 = RST, 2^0 = ACK
  flags = 0x0,
  ackNum = 0,
  seqNum = 0
}

function TCPHeader:new(o, flags, ackNum, seqNum)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  self.flags = flags
  self.ackNum = ackNum
  self.seqNum = seqNum
  return o
end

function TCPHeader:build()
  return {flags = self.flags, ackNum = self.ackNum, seqNum = self.seqNum}
end

local Session = {
  id = nil,
  status = nil,
  targetIP = nil,
  targetPort = nil,
  ackNum = 0x0,
  seqNum = 0x0
}

local function send(IP, port, payload, skipRegistration)
  local packet = Packet:new(tcpProtocol, IP, port, payload):build()
  multiport.send(packet, skipRegistration)
end

function Session:new(o, IP, port, seq, ack)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  self.targetIP = IP
  self.targetPort = port
  self.ackNum = ack or 0
  self.seqNum = seq or math.random(0xFFFFFFFF)
  self.status = "CLOSE"
  self.id = require("UUID").next()
  _G.TCP.sessions[self.id] = self
  return o
end

function tcp.setup()
  if(not _G.TCP or not _G.TCP.isInitialized) then
    _G.TCP = {}
    _G.TCP.sessions = {}
    _G.TCP.allowedPorts = {}
    _G.TCP.isInitialized = true
    event.listen("multiport_message", function(_, _, _, targetPort, _, message)
      if(_G.TCP.allowedPorts[targetPort] and serialization.unserialize(message).protocol == tcpProtocol) then
        local decoded = serialization.unserialize(message)
        if(decoded.tcp.)
        local session = Session:new(decoded.senderIP, targetPort)
        session:acceptConnection()
      end
    end)
  end
end

-- Assumes there's already a connection waiting.
function Session:acceptConnection()

end

function Session:start()
  tcp.setup()
  if(self.status ~= "CLOSE") then
    self:stop()
  end
  self.seqNum = math.random(0xFFFFFFFF)
  self.ackNum = 0
  self.status = "CLOSE"
  local decoded
  for i = 1, 5 do
    send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x04, 0, self.seqNum):build(), data = nil}) -- SYN
    self.status = "SYN-SENT"
    local _, _, _, targetPort, _, message = event.pull("multiport_message")
    if(targetPort == self.targetPort) then
      decoded = serialization.unserialize(message)
      if(decoded.tcp.flags ~= 0x05) then -- SYN-ACK
        send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
        i = 1
      else
        if(decoded.tcp.ackNum == self.seqNum + 1) then -- check ACK num.
          self.ackNum = decoded.seqNum
          self.status = "ESTABLISHED"
          local header = TCPHeader:new(0x1, self.ackNum + 1, self.seqNum + 1)
          self.seqNum = self.seqNum + 1
          self.ackNum = self.ackNum + 1
          send(self.targetIP, self.targetPort, {tcp = header, data = nil}, false) --  Send ACK
          return true
        end
      end
    end
  end
  _G.IP.logger.write("#[TCP] Failed to start session, server did not respond with SYN-ACK.")
  self.status = "CLOSE"
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
  return false
end

function Session:stop()
  send(self.targetIP, self.targetPort, {})
end

function Session:send(payload)
  for _ = 1, 5 do
    send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x00, self.ackNum, self.seqNum):build(), data = payload}) -- Data
    local _, _, _, targetPort, _, message = event.pull(5, "multiport_message")
    if(targetPort == self.targetPort) then
      local decoded = serialization.unserialize(message)
      if(decoded.tcp.flags == 0x01) then -- ACK
        if(decoded.tcp.ackNum ~= self.seqNum + #serialization.serialize(payload)) then
          return false, "TCP Out-Of-Order packet; unimplemented."
        end
        self.seqNum = self.seqNum + #serialization.serialize(payload)
        return true
      end
    end
  end
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
  return false, "ACK was not received, connection closed."
end

function Session:attachListener(callback)
  event.listen("multiport_message", function(_, _, _, targetPort, _, message)
    if(targetPort == self.targetPort and serialization.unserialize(message).protocol == tcpProtocol) then
      callback(serialization.unserialize(message))
    end
  end)
end

function Session:pull(sessionID, timeout, callback)
  if(_G.TCP.sessions[sessionID] == nil) then
    _G.IP.logger.write("#[TCP] Attempted to pull from an invalid session.")
    return nil, "Session closed."
  end
  local _, _, _, targetPort, _, message = event.pull(timeout or math.huge, "multiport_message")
  if(targetPort == _G.TCP.sessions[sessionID] and serialization.unserialize(message).protocol == tcpProtocol) then
    if(not callback) then
      return serialization.unserialize(message)
    end
    return callback(serialization.unserialize(message))
  end
end

function tcp.allowConnection(port)
  tcp.setup()
  _G.TCP.allowedPorts[port] = true
end

function tcp.disallowConnection(port)
  tcp.setup()
  _G.TCP.allowedPorts[port] = nil
end

function tcp.connect(IP, port)
  tcp.setup()
  local session = Session:new(IP, port)
  session:start()
  return session.id
end

function tcp.disconnect(IP, port)
  local session = Session:new(IP, port)
end

return tcp