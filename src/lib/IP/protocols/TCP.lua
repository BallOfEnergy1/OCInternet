
local multiport = require("IP.multiport")
local serialization = require("serialization")
local event = require("event")
local Packet = require("IP.classes.PacketClass")
local RingBuffer = require("IP.classes.RingBufferClass")

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
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.flags = flags
  o.ackNum = ackNum
  o.seqNum = seqNum
  return o
end

function TCPHeader:build()
  return {flags = self.flags, ackNum = self.ackNum, seqNum = self.seqNum}
end

local Session = {
  id = "00000000-0000-0000-0000-000000000000",
  status = "CLOSE",
  targetIP = 0x0,
  targetPort = 0x0,
  ackNum = 0x0,
  seqNum = 0x0,
  buffer = RingBuffer:new(127),
  listenerID = 0x0
}

local function send(IP, port, payload, skipRegistration)
  local packet = Packet:new(nil, tcpProtocol, IP, port, payload, nil, nil):build()
  multiport.send(packet, skipRegistration)
end

function Session:new(IP, port, seq, ack)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.targetIP = IP
  o.targetPort = port
  o.ackNum = ack or 0
  o.seqNum = seq or math.random(0xFFFFFFFF)
  o.status = "CLOSE"
  local id = require("UUID").next()
  o.id = id
  _G.TCP.sessions[id] = o
  o.listenerID = event.listen("multiport_message", function(_, _, _, targetPort, _, message)
    local decoded = serialization.unserialize(message)
    if(_G.TCP.allowedPorts[targetPort] and decoded.protocol == tcpProtocol) then
      
      if(decoded.data.tcp.flags == 0x00) then -- DATA
        self:acceptData(decoded)
      end
      
      if(decoded.data.tcp.flags == 0x02) then -- RST
        self:reset(true)
      end
      
      if(decoded.data.tcp.flags == 0x08) then -- FIN
        event.cancel(o.listenerID)
        self:acceptFinalization()
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
            if(_G.TCP.sessions[i].status ~= "CLOSE") then
              _G.TCP.sessions[i]:reset()
            end
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
  ):build(), false, false, 5, 5, function(_, _, _, targetPort, _, message) return targetPort == self.targetPort and serialization.unserialize(message).protocol == tcpProtocol end)
  
  if(message == nil and code == -1) then
    self.status = "CLOSE"
    return nil, code
  end
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
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
function Session:acceptFinalization()
  print(1)
  tcp.setup()
  self.status = "CLOSE-WAIT"
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x01, self.ackNum, self.seqNum):build(), data = nil})
  print(2)
  local limit = 60
  
  for _ = 1, limit do
    if(not self.buffer:checkHasData()) then
      send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x08, self.ackNum, self.seqNum):build(), data = nil})
      break
    end
    os.sleep(0.25)
  end
  print(3)
  
  self.status = "LAST-ACK"
  local message, code = multiport.requestMessageWithTimeout(nil, false, false, 5, 5, function(_, _, _, targetPort, _, receivedMessage) return targetPort == self.targetPort and serialization.unserialize(receivedMessage).protocol == tcpProtocol end, true)
  if(message == nil and code == -1) then
    self:reset()
    return nil, code
  end
  print(4)
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
  print(5)
  self.status = "CLOSE"
  self.buffer:clear()
  event.cancel(self.listenerID)
  _G.TCP.sessions[self.id] = nil
end

-- Assumes there's already data waiting.
function Session:acceptData(DATAPacket)
  tcp.setup()
  if(self.status ~= "ESTABLISHED") then
    self:reset()
  end
  self.buffer:writeData(DATAPacket.data.data)
  self.ackNum = self.ackNum + #serialization.serialize(DATAPacket.data.data)
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), data = nil}, false) --  Send ACK
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
  ):build(), false, false, 5, 5, function(_, _, _, targetPort, _, message) return targetPort == self.targetPort and serialization.unserialize(message).protocol == tcpProtocol end)
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
  if(data.tcp.flags ~= 0x05) then -- SYN-ACK
    goto start
  else
    if(data.tcp.ackNum == self.seqNum + 1) then -- check ACK num.
      self.ackNum = data.tcp.seqNum
      self.status = "ESTABLISHED"
      self.ackNum = self.ackNum + 1
      send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), data = nil}, false) --  Send ACK
      self.ackNum = self.ackNum + 1
      return true
    end
  end
  _G.IP.logger.write("#[TCP] Failed to start session, connection timed out.")
  self.status = "CLOSE"
  self:reset()
  return false
end

function Session:reset(sentByOther)
  if(not sentByOther) then
    send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), data = nil}) -- RST
  end
  self.status = "CLOSE"
  event.cancel(self.listenerID)
  _G.TCP.sessions[self.id] = nil
end

function Session:stop()
  print(1)
  self.status = "FIN-WAIT-1"
  local message, code = multiport.requestMessageWithTimeout(Packet:new(nil,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x08, self.ackNum, self.seqNum):build(), data = nil} -- FIN
  ):build(), false, false, 5, 5, function(_, _, _, targetPort, _, receivedMessage) return targetPort == self.targetPort and serialization.unserialize(receivedMessage).protocol == tcpProtocol end)
  print(2)
  if(message == nil and code == -1) then
    self:reset()
    self.status = "CLOSE"
    return nil, code
  end
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  print(3)
  local decoded = serialization.unserialize(message)
  local data = decoded.data
  if(data.tcp.flags ~= 0x01 or data.tcp.ackNum ~= self.seqNum + 1) then -- ACK
    self:reset()
    return
  end
  print(4)
  self.seqNum = self.seqNum + 1
  self.status = "FIN-WAIT-2"
  message, code = multiport.requestMessageWithTimeout(nil, false, false, 5, 5, function(_, _, _, targetPort, _, receivedMessage) return targetPort == self.targetPort and serialization.unserialize(receivedMessage).protocol == tcpProtocol end, true)
  print(5)
  if(message == nil and code == -1) then
    self:reset()
    self.status = "CLOSE"
    return nil, code
  end
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  print(6)
  decoded = serialization.unserialize(message)
  data = decoded.data
  if(data.tcp.flags ~= 0x08 or data.tcp.ackNum ~= self.seqNum + 1) then -- FIN
    self:reset()
    return
  end
  print(7)
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), data = nil}, false) --  Send ACK
  self.ackNum = self.ackNum + 1
  self.status = "TIME-WAIT"
  event.timer(10, function()
    self.status = "CLOSE"
    self.buffer:clear()
    event.cancel(self.listenerID)
    _G.TCP.sessions[self.id] = nil
    print(8)
  end)
end

function Session:send(payload)
  if(self.status ~= "ESTABLISHED") then
    self:reset()
    return
  end
  ::start::
  local message, code = multiport.requestMessageWithTimeout(Packet:new(nil,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x00, self.ackNum, self.seqNum):build(), data = payload} -- DATA
  ):build(), false, false, 5, 5, function(_, _, _, targetPort, _, message) return targetPort == self.targetPort and serialization.unserialize(message).protocol == tcpProtocol end)
  
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
  if(data.tcp.flags ~= 0x01) then -- ACK
    goto start
  else
    if(data.tcp.ackNum == self.seqNum + #serialization.serialize(payload) + 1) then -- check ACK num.
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

function Session:pull(timeout, callback)
  timeout = timeout or math.huge
  local start = require("computer").uptime()
  local time = start
  repeat
    if(self.buffer:checkHasData()) then
      local output = self.buffer:readData()
      if(not callback) then
        return output
      end
      return callback(output)
    end
    if(event.pull(0.05, "interrupted")) then
      return nil, -1
    end
    time = require("computer").uptime()
  until time - (timeout + start) > 0
end

function Session:getIP()
  return self.targetIP
end

function Session:getPort()
  return self.targetPort
end

function Session:getStatus()
  return self.status
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
  tcp.allowConnection(port)
  local session = Session:new(IP, port)
  session:start()
  return session
end

return tcp