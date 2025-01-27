
local multiport = require("IP.multiport")
local serialization = require("serialization")
local event = require("event")
local Packet = require("IP.packetClass")
local util = require("IP.IPUtil")

local tcpProtocol = 5

local tcp = {}

local TCPHeader = {
  -- 0          0          0          0
  -- 2^3 = FIN, 2^2 = SYN, 2^1 = RST, 2^0 = ACK
  flags = 0x0,
  ackNum = 0,
  seqNum = 0
}

function TCPHeader:new(flags, ackNum, seqNum)
  local o = TCPHeader
  setmetatable(o, self)
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
  local packet = Packet:new(nil, tcpProtocol, IP, port, payload):build()
  multiport.send(packet, skipRegistration)
end

function Session:new(IP, port, seq, ack)
  local o = Session
  setmetatable(o, self)
  self.targetIP = IP
  self.targetPort = port
  self.ackNum = ack or 0
  self.seqNum = seq or math.random(0xFFFFFFFF)
  self.status = "CLOSE"
  self.id = require("UUID").next()
  _G.TCP.sessions[self.id] = self
  event.listen("multiport_message", function(_, _, _, targetPort, _, message)
    if(_G.TCP.allowedPorts[targetPort] and serialization.unserialize(message).protocol == tcpProtocol) then
      if(message.senderIP ~= IP) then
        return
      end
      local decoded = serialization.unserialize(message)
      
      if(decoded.tcp.flags == 0x02) then -- RST
        self:reset()
      end
      
      if(decoded.tcp.flags == 0x08) then -- FIN
        self:acceptFinalization(decoded)
      end
    end
  end)
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
        if(decoded.data.tcp.flags ~= 0x4) then -- SYN
          return
        end
        for i, v in pairs(_G.TCP.sessions) do
          if(v.targetIP == decoded.senderIP and v.targetPort == targetPort) then
            _G.TCP.sessions[i].status = "SYN-RECEIVED"
            _G.TCP.sessions[i]:acceptConnection(decoded)
            return
          end
        end
        local session = Session:new(decoded.senderIP, targetPort)
        session.status = "SYN-RECEIVED"
        session:acceptConnection(decoded)
      end
    end)
  end
end

-- Assumes there's already a connection waiting.
function Session:acceptConnection(SYNPacket)
  tcp.setup()
  self.ackNum = SYNPacket.data.tcp.seqNum + 1
  self.seqNum = math.random(0xFFFFFFFF)
  local message, code = multiport.requestMessageWithTimeout(Packet:new(nil,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x05, self.ackNum, self.seqNum):build(), data = nil} -- SYN-ACK
  ), false, false, 5, 5, function(_, _, _, targetPort, _, message) return targetPort == self.targetPort and serialization.unserialize(message).protocol == tcpProtocol end)
  
  if(message == nil and code == -1) then
    self.status = "CLOSE"
    return nil, code
  end
  
  local decoded = serialization.unserialize(message)
  local data = decoded.data
  if(decoded ~= nil and decoded.targetPort == self.targetPort) then
    if(data.tcp.flags ~= 0x01) then -- ACK
      self:reset()
      return
    else
      if(data.tcp.ackNum == self.seqNum + 1) then -- check ACK num.
        self.status = "ESTABLISHED"
        self.seqNum = self.seqNum + 1
        return true
      end
    end
  end
end

-- Assumes there's already a finalization waiting.
function Session:acceptFinalization(FINPacket)
  tcp.setup()
  self.ackNum = FINPacket.data.tcp.seqNum + 1
  self.seqNum = math.random(0xFFFFFFFF)
  local message, code = multiport.requestMessageWithTimeout(Packet:new(nil,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x05, self.ackNum, self.seqNum):build(), data = nil} -- SYN-ACK
  ), false, false, 5, 5, function(_, _, _, targetPort, _, message) return targetPort == self.targetPort and serialization.unserialize(message).protocol == tcpProtocol end)
  
  if(message == nil and code == -1) then
    self.status = "CLOSE"
    return nil, code
  end
  
  local decoded = serialization.unserialize(message)
  local data = decoded.data
  if(decoded ~= nil and decoded.targetPort == self.targetPort) then
    if(data.tcp.flags ~= 0x01) then -- ACK
      self:reset()
      return
    else
      if(data.tcp.ackNum == self.seqNum + 1) then -- check ACK num.
        self.status = "ESTABLISHED"
        self.seqNum = self.seqNum + 1
        return true
      end
    end
  end
end

function Session:start()
  tcp.setup()
  if(self.status ~= "CLOSE") then
    self:stop()
  end
  ::start::
  self.seqNum = math.random(0xFFFFFFFF)
  self.ackNum = 0
  self.status = "CLOSE"
  self.status = "SYN-SENT"
  local message, code = multiport.requestMessageWithTimeout(Packet:new(nil,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x04, 0, self.seqNum):build(), data = nil} -- SYN
  ), false, false, 5, 5, function(_, _, _, targetPort, _, message) return targetPort == self.targetPort and serialization.unserialize(message).protocol == tcpProtocol end)
  
  if(message == nil and code == -1) then
    send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
    self.status = "CLOSE"
    return nil, code
  end
  
  local decoded = serialization.unserialize(message)
  local data = decoded.data
  if(data.tcp.flags ~= 0x05) then -- SYN-ACK
    goto start
  else
    if(data.tcp.ackNum == self.seqNum + 1) then -- check ACK num.
      self.ackNum = data.tcp.seqNum
      self.status = "ESTABLISHED"
      self.ackNum = self.ackNum + 1
      send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), data = nil}, false) --  Send ACK
      return true
    end
  end
  _G.IP.logger.write("#[TCP] Failed to start session, connection timed out.")
  self.status = "CLOSE"
  self:reset()
  return false
end

function Session:reset()
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
  self.status = nil
end

function Session:stop()
  self.status = "FIN-WAIT-1"
  local message, code = multiport.requestMessageWithTimeout(Packet:new(nil,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x08, self.ackNum, self.seqNum):build(), data = nil} -- FIN
  ), false, false, 5, 5, function(_, _, _, targetPort, _, receivedMessage) return targetPort == self.targetPort and serialization.unserialize(receivedMessage).protocol == tcpProtocol end)
  
  if(message == nil and code == -1) then
    self:reset()
    self.status = "CLOSE"
    return nil, code
  end
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  local decoded = serialization.unserialize(message)
  local data = decoded.data
  if(data.tcp.flags ~= 0x01 or data.tcp.ackNum ~= self.seqNum + 1) then -- ACK
    self:reset()
    return
  end
  self.seqNum = self.seqNum + 1
  self.status = "FIN-WAIT-2"
  message, code = multiport.requestMessageWithTimeout(Packet:new(nil, nil, nil, nil, nil
  ), false, false, 5, 5, function(_, _, _, targetPort, _, receivedMessage) return targetPort == self.targetPort and serialization.unserialize(receivedMessage).protocol == tcpProtocol end, true)
  
  if(message == nil and code == -1) then
    send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
    self.status = "CLOSE"
    return nil, code
  end
  
  if(message == nil) then
    send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
    return false, "Connection closed; timed out."
  end
  
  decoded = serialization.unserialize(message)
  data = decoded.data
  if(data.tcp.flags ~= 0x08 or data.tcp.ackNum ~= self.seqNum + 1) then -- FIN
    self:reset()
    return
  end
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), data = nil}, false) --  Send ACK
  self.ackNum = self.ackNum + 1
  self.status = "TIME-WAIT"
  event.timer(10, function() self.status = "CLOSE" end)
end

function Session:send(payload)
  ::start::
  local message, code = multiport.requestMessageWithTimeout(Packet:new(nil,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x00, self.ackNum, self.seqNum):build(), data = payload} -- DATA
  ), false, false, 5, 5, function(_, _, _, targetPort, _, message) return targetPort == self.targetPort and serialization.unserialize(message).protocol == tcpProtocol end)
  
  if(message == nil and code == -1) then
    send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
    self.status = "CLOSE"
    return nil, code
  end
  
  if(message == nil) then
    send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
    return false, "Connection closed; timed out."
  end
  
  local decoded = serialization.unserialize(message)
  local data = decoded.data
  if(data.tcp.flags ~= 0x01) then -- ACK
    goto start
  else
    if(data.tcp.ackNum == self.seqNum + #serialization.serialize(payload)) then -- check ACK num.
      self.seqNum = self.seqNum + #serialization.serialize(payload)
      return true
    else
      goto start
    end
  end
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

function tcp.disconnect(id)
  _G.TCP.sessions[id]:stop()
end

return tcp