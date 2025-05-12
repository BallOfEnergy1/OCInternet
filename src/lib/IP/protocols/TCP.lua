
local multiport = require("IP.multiport")
local serialization = require("IP.serializationUnsafe")
local event = require("event")
local Packet = require("IP.classes.PacketClass")
local RingBuffer = require("IP.classes.RingBufferClass")
local api = require("IP.API.netAPI")
local hyperpack = require("hyperpack")

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
  return {self.flags, self.ackNum, self.seqNum}
end

--- @class Session
local Session = {
  id = nil,
  status = nil,
  targetIP = nil,
  targetPort = nil,
  ackNum = nil,
  seqNum = nil,
  buffer = nil,
  listenerCallback = nil,
  senderMAC = nil
}

function Session:new(sender, IP, port, seq, ack)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.senderMAC = sender
  o.targetIP = IP
  o.targetPort = port
  o.ackNum = ack or 0
  o.seqNum = seq or math.random(0xFFFFFFFF)
  o.status = "CLOSE"
  o.buffer = RingBuffer:new(127)
  local id = require("UUID").next()
  o.id = id
  _G.TCP.sessions[id] = o
  o.listenerCallback = api.registerReceivingCallback(function(message)
    
    if(_G.TCP.allowedPorts[message.header.targetPort] and message.header.protocol == tcpProtocol) then
      
      local success, data = hyperpack.simpleUnpack(message.data)
      if(not success) then
        _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
        return
      end
      local tcpFlags = data[1]
      
      if(tcpFlags == 0x00) then -- DATA
        o:acceptData(message)
      end
      
      if(tcpFlags == 0x02) then -- RST
        o:reset(true)
      end
      
      if(tcpFlags == 0x08) then -- FIN
        if(o.status == "ESTABLISHED") then
          api.unregisterCallback(o.listenerCallback)
          o:acceptFinalization()
        end
      end
    end
  end, nil, nil, "TCP Listener (" .. id:sub(1, 8) .. ")")
  return o
end

function Session:sendRaw(payload)
  payload = hyperpack.simplePack(payload)
  local packet = Packet:new(self.senderMAC, tcpProtocol, self.targetIP, self.targetPort, payload)
  multiport.send(packet)
end

function tcp.setup()
  if(not _G.TCP or not _G.TCP.isInitialized) then
    _G.TCP = {}
    _G.TCP.sessions = {}
    _G.TCP.allowedPorts = {}
    _G.TCP.isInitialized = true
    _G.TCP.callback = api.registerReceivingCallback(function(message, _, MAC)
      if(_G.TCP.allowedPorts[message.header.targetPort] and message.header.protocol == tcpProtocol) then
        
        local success, data = hyperpack.simpleUnpack(message.data)
        if(not success) then
          _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
          return
        end
        local tcpFlags = data[1]
        
        if(tcpFlags ~= 0x4) then -- SYN
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
        local session = Session:new(MAC, message.header.senderIP, message.header.targetPort)
        session.status = "SYN-RECEIVED"
        session:acceptConnection(data)
      end
    end, nil, nil, "TCP Handler")
  end
end

-- Assumes there's already a connection waiting.
function Session:acceptConnection(unpackedData)
  tcp.setup()
  local tcpSeqNum = unpackedData[3]
  self.ackNum = tcpSeqNum + 1
  self.seqNum = math.random(0xFFFFFFFF)
  local message = multiport.requestMessageWithTimeout(Packet:new(
    self.senderMAC,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    hyperpack.simplePack({TCPHeader:new(0x05, self.ackNum, self.seqNum):build(), ""})-- SYN-ACK
  ), false, 5, 5, function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  local success, data = hyperpack.simpleUnpack(message.data)
  if(not success) then
    _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
    return
  end
  if(message ~= nil and message.header.targetPort == self.targetPort) then
    local tcpFlags = data[1]
    if(tcpFlags ~= 0x01) then -- ACK
      self:reset()
      return
    else
      local tcpAckNum = data[2]
      if(tcpAckNum == self.seqNum + 1) then -- check ACK num.
        self.status = "ESTABLISHED"
        return true
      end
    end
  end
end

-- Assumes there's already a finalization waiting.
function Session:acceptFinalization()
  tcp.setup()
  self.status = "CLOSE-WAIT"
  self.ackNum = self.ackNum + 1
  self:sendRaw({TCPHeader:new(0x01, self.ackNum, self.seqNum):build(), ""})
  self.seqNum = self.seqNum + 1
  local limit = 60
  
  local reached = false
  for _ = 1, limit do
    if(not self.buffer:checkHasData()) then
      self:sendRaw({TCPHeader:new(0x08, self.ackNum, self.seqNum):build(), ""})
      reached = true
      break
    end
    os.sleep(0.25)
  end
  
  if(not reached) then -- TODO: find something better than this BS
    self:sendRaw({TCPHeader:new(0x08, self.ackNum, self.seqNum):build(), ""}) -- Push data regardless, else it will RST the connection.
  end
  
  self.status = "LAST-ACK"
  local message = multiport.pullMessageWithTimeout(5 * 5 --[[ 5 sec timeout, 5 attempts ]], function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  local success, data = hyperpack.simpleUnpack(message.data)
  if(not success) then
    _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
    return
  end
  local tcpFlags = data[1]
  local tcpAckNum = data[2]
  if(tcpFlags ~= 0x01 or tcpAckNum ~= self.seqNum + 1) then -- ACK
    self:reset()
    return
  end
  self.status = "CLOSE"
  self.buffer:clear()
  api.unregisterCallback(self.listenerCallback)
  _G.TCP.sessions[self.id] = nil
end

-- Assumes there's already data waiting.
function Session:acceptData(DATAPacket)
  tcp.setup()
  if(self.status ~= "ESTABLISHED") then
    self:reset()
  end
  local success, data = hyperpack.simpleUnpack(DATAPacket.data)
  if(not success) then
    _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
    return
  end
  local sentData = data[4]
  self.buffer:writeData(sentData)
  self.ackNum = self.ackNum + #serialization.serialize(sentData)
  self:sendRaw({TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), ""}) --  Send ACK
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
    self.senderMAC,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    hyperpack.simplePack({TCPHeader:new(0x04, 0, self.seqNum):build(), ""}) -- SYN
  ), false, 5, 5, function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  local success, data = hyperpack.simpleUnpack(message.data)
  if(not success) then
    _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
    return
  end
  local tcpFlags = data[1]
  local tcpAckNum = data[2]
  local tcpSeqNum = data[3]
  
  if(tcpFlags ~= 0x05) then -- SYN-ACK
    goto start
  else
    if(tcpAckNum == self.seqNum + 1) then -- check ACK num.
      self.ackNum = tcpSeqNum
      self.status = "ESTABLISHED"
      self.ackNum = self.ackNum + 1
      self:sendRaw({TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), ""}) --  Send ACK
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
    self:sendRaw({TCPHeader:new(0x02, self.ackNum, self.seqNum):build(), ""}) -- RST
  end
  self.status = "CLOSE"
  api.unregisterCallback(self.listenerCallback)
  _G.TCP.sessions[self.id] = nil
end

function Session:stop()
  self.status = "FIN-WAIT-1"
  self.seqNum = self.seqNum + 1
  local message = multiport.requestMessageWithTimeout(Packet:new(
    self.senderMAC,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    hyperpack.simplePack({TCPHeader:new(0x08, self.ackNum, self.seqNum):build(), ""}) -- FIN
  ), false, 5, 5, function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  local success, data = hyperpack.simpleUnpack(message.data)
  if(not success) then
    _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
    return
  end
  local tcpFlags = data[1]
  local tcpAckNum = data[2]
  
  if(tcpFlags ~= 0x01 or tcpAckNum ~= self.seqNum + 1) then -- ACK
    self:reset()
    return
  end
  self.status = "FIN-WAIT-2"
  message = multiport.pullMessageWithTimeout(5 * 5 --[[ 5 sec timeout, 5 attempts ]], function(receivedMessage) return receivedMessage.header.targetPort == self.targetPort and receivedMessage.header.protocol == tcpProtocol end)

  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  
  success, data = hyperpack.simpleUnpack(message.data)
  if(not success) then
    _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
    return
  end
  tcpFlags = data[1]
  tcpAckNum = data[2]
  if(tcpFlags ~= 0x08 or tcpAckNum ~= self.seqNum + 1) then -- FIN
    self:reset()
    return
  end
  self.ackNum = self.ackNum + 1
  self:sendRaw({TCPHeader:new(0x1, self.ackNum, self.seqNum):build(), ""}) --  Send ACK
  self.status = "TIME-WAIT"
  event.timer(10, function()
    self.status = "CLOSE"
    self.buffer:clear()
    api.unregisterCallback(self.listenerCallback)
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
    self.senderMAC,
    tcpProtocol,
    self.targetIP,
    self.targetPort,
    hyperpack.simplePack({TCPHeader:new(0x00, self.ackNum, self.seqNum):build(), payload}) -- DATA
  ), false, 5, 5, function(message) return message.header.targetPort == self.targetPort and message.header.protocol == tcpProtocol end)
  
  if(message == nil) then
    self:reset()
    return false, "Connection closed; timed out."
  end
  local success, data = hyperpack.simpleUnpack(message.data)
  if(not success) then
    _G.IP.logger.write("Failed to unpack TCP packet: " .. data)
    return
  end
  local tcpFlags = data[1]
  local tcpAckNum = data[2]
  if(tcpFlags ~= 0x01) then -- ACK
    goto start
  else
    if(tcpAckNum == self.seqNum + #serialization.serialize(payload) + 1) then -- check ACK num.
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

function Session:getSenderMAC()
  return self.senderMAC
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
  local session = Session:new(_G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC, IP, port)
  session:start()
  return session
end

return tcp