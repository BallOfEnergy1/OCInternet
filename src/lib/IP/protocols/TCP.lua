
local multiport = require("IP.multiport")
local serialization = require("IP.serializationUnsafe")
local event = require("event")
local Packet = require("IP.classes.PacketClass")
local RingBuffer = require("IP.classes.RingBufferClass")
local api = require("IP.netAPI")

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
  listenerCallback = {}
}

local function send(IP, port, payload)
  local packet = Packet:new(tcpProtocol, IP, port, payload)
  multiport.send(packet)
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
  o.listenerCallback = api.registerReceivingCallback(function(message)

    if(_G.TCP.allowedPorts[message.header.targetPort] and message.header.protocol == tcpProtocol) then
      
      if(message.data.tcp.flags == 0x00) then -- DATA
        self:acceptData(message)
      end
      
      if(message.data.tcp.flags == 0x02) then -- RST
        self:reset(true)
      end
      
      if(message.data.tcp.flags == 0x08) then -- FIN
        api.unregisterCallback(o.listenerCallback)
        self:acceptFinalization()
      end
    end
  end, nil, nil, "TCP Listener (" .. id:sub(1, 8) .. ")")
  return o
end

function tcp.setup()
  if(not _G.TCP or not _G.TCP.isInitialized) then
    _G.TCP = {}
    _G.TCP.sessions = {}
    _G.TCP.allowedPorts = {}
    _G.TCP.isInitialized = true
    _G.TCP.callback = api.registerReceivingCallback(function(message)
      if(_G.TCP.allowedPorts[message.header.targetPort] and message.header.protocol == tcpProtocol) then

        if(message.data.tcp.flags ~= 0x4) then -- SYN
          return
        end
        for i, v in pairs(_G.TCP.sessions) do
          if(v.targetIP == message.header.senderIP and v.targetPort == message.header.targetPort) then
            if(_G.TCP.sessions[i].status ~= "CLOSE") then
              _G.TCP.sessions[i]:reset()
            end
            _G.TCP.sessions[i].status = "SYN-RECEIVED"
            _G.TCP.sessions[i]:acceptConnection(message)
            return
          end
        end
        local session = Session:new(message.header.senderIP, message.header.targetPort)
        session.status = "SYN-RECEIVED"
        session:acceptConnection(message)
      end
    end, nil, nil, "TCP Handler")
  end
end

-- Assumes there's already a connection waiting.
function Session:acceptConnection(SYNPacket)
  tcp.setup()
  self.ackNum = SYNPacket.data.tcp.seqNum + 1
  self.seqNum = math.random(0xFFFFFFFF)
  local message = multiport.requestMessageWithTimeout(Packet:new(
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x05, self.ackNum, self.seqNum):build(), data = nil} -- SYN-ACK
  ), false, 5, 5, function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  local data = message.data
  if(message ~= nil and message.header.targetPort == self.targetPort) then
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
  tcp.setup()
  self.status = "CLOSE-WAIT"
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x01, self.ackNum, self.seqNum):build(), data = nil})
  self.ackNum = self.ackNum + 1
  local limit = 60
  
  for _ = 1, limit do
    if(not self.buffer:checkHasData()) then
      send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x08, self.ackNum, self.seqNum):build(), data = nil})
      self.seqNum = self.seqNum + 1
      break
    end
    os.sleep(0.25)
  end
  
  self.status = "LAST-ACK"
  local message = multiport.pullMessageWithTimeout(5 * 5 --[[ 5 sec timeout, 5 attempts ]], function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  local data = message.data
  if(data.tcp.flags ~= 0x01 or data.tcp.ackNum ~= self.seqNum + 1) then -- ACK
    self:reset()
    return
  end
  self.status = "CLOSE"
  self.buffer:clear()
  event.cancel(self.listenerCallback)
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
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), data = nil}) --  Send ACK
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
  local message = multiport.requestMessageWithTimeout(Packet:new(
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x04, 0, self.seqNum):build(), data = nil} -- SYN
  ), false, 5, 5, function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  local data = message.data
  if(data.tcp.flags ~= 0x05) then -- SYN-ACK
    goto start
  else
    if(data.tcp.ackNum == self.seqNum + 1) then -- check ACK num.
      self.ackNum = data.tcp.seqNum
      self.status = "ESTABLISHED"
      self.ackNum = self.ackNum + 1
      send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), data = nil}) --  Send ACK
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
  event.cancel(self.listenerCallback)
  _G.TCP.sessions[self.id] = nil
end

function Session:stop()
  self.status = "FIN-WAIT-1"
  local message = multiport.requestMessageWithTimeout(Packet:new(
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x08, self.ackNum, self.seqNum):build(), data = nil} -- FIN
  ), false, 5, 5, function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  local data = message.data
  if(data.tcp.flags ~= 0x01 or data.tcp.ackNum ~= self.seqNum + 1) then -- ACK
    self:reset()
    return
  end
  self.seqNum = self.seqNum + 1
  self.status = "FIN-WAIT-2"
  message = multiport.pullMessageWithTimeout(5 * 5 --[[ 5 sec timeout, 5 attempts ]], function(receivedMessage) return receivedMessage.header.targetPort == self.targetPort and receivedMessage.header.protocol == tcpProtocol end)

  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  data = message.data
  if(data.tcp.flags ~= 0x08 or data.tcp.ackNum ~= self.seqNum + 1) then -- FIN
    self:reset()
    return
  end
  send(self.targetIP, self.targetPort, {tcp = TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), data = nil}) --  Send ACK
  self.ackNum = self.ackNum + 1
  self.status = "TIME-WAIT"
  event.timer(10, function()
    self.status = "CLOSE"
    self.buffer:clear()
    event.cancel(self.listenerCallback)
    _G.TCP.sessions[self.id] = nil
  end)
end

function Session:send(payload)
  if(self.status ~= "ESTABLISHED") then
    self:reset()
    return
  end
  ::start::
  local message = multiport.requestMessageWithTimeout(Packet:new(
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    {tcp = TCPHeader:new(0x00, self.ackNum, self.seqNum):build(), data = payload} -- DATA
  ), false, 5, 5, function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  local data = message.data
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
  return api.registerReceivingCallback(function(message)
    if(message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol) then
      callback(message)
    end
  end, nil, nil, "TCP Callback Listener (Port " .. self.targetPort .. ")")
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