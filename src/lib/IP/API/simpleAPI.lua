
--- Ok so those wanting to not have to deal with protocols... This is your savior!
--- This library effectively combines everything needed for making simple programs into a single *simple* API.
--- Examples can be found in the `examples` folder at the project root.
local simpleAPI = {}

--- @type Hyperpack
local hyperpack = require("hyperpack")
local UDP = require("IP.protocols.UDP")
local IPUtil = require("IP.IPUtil")
local multiport = require("IP.multiport")
local netAPI = require("IP.API.netAPI")

--- Sends a message to a client.
--- @param IP number|string IP to send to (can be in decimal or fancy string format).
--- @param port number Port to send on.
--- @param data any Data to send to the client.
--- @param protocol number Protocol index to use (optional).
--- @overload fun(IP:number|string,port:number,data:any):void
--- @return void
function simpleAPI.sendMessage(IP, port, data, protocol)
  assert(type(IP) == "string" or type(IP) == "number", "IP expected string or number, got " .. type(IP))
  assert(type(port) == "number", "Port expected number, got " .. type(port))
  assert(type(data) ~= "function", "Data cannot be a function.")
  if(type(data) == "table") then
    data = hyperpack.simplePack(data)
  end
  if(type(IP) == "string") then
    IP = IPUtil.fromUserFormat(IP)
  end
  UDP.send(IP, port, data, protocol)
end

--- Multicasts a message to a group (selective broadcast).
--- @param IP number|string IP to multicast over (can be in decimal or fancy string format).
--- @param port number Port to multicast on.
--- @param data any Data to send to the client.
--- @return void
function simpleAPI.multicastMessage(IP, port, data)
  error("Function not implemented.")
end

--- Broadcasts a message to (a) client(s).
--- @param port number Port to broadcast on.
--- @param data any Data to send to the client.
--- @param protocol number Protocol index to use (optional).
--- @overload fun(port:number,data:any):void
--- @return void
function simpleAPI.broadcastMessage(port, data, protocol)
  assert(type(port) ~= "number", "Port expected number, got " + type(port))
  assert(type(data) == "function", "Data cannot be a function.")
  if(type(data) == "table") then
    data = hyperpack.simplePack(data)
  end
  UDP.broadcast(port, data, protocol)
end

--- Waits for an unreliable message on a port from an IP (optional).
--- @param IP number|string IP to receive from (can be in decimal or fancy string format; optional).
--- @param port number Port to receive on.
--- @param timeout number Time to wait (in seconds) until timing out. Defaults to 0.
--- @return boolean, any Returns true and the data from the packet if succeeds, false and an error message otherwise.
--- @overload fun(port:number):boolean,any
function simpleAPI.waitForMessage(port, IP, timeout)
  local result = multiport.pullMessageWithTimeout(timeout or 0, function(packet) return packet.header.senderIP == IP and packet.header.targetPort == port end)
  if(not result) then
    return false, "Timed out waiting for packet."
  end
  local packer = hyperpack:new()
  local success, reason = packer:deserializeIntoClass(result.data)
  if(not success) then
    _G.IP.logger.write("Failed to unpack UDP data: " .. reason)
    return
  end
  packer:popValue()
  packer:popValue()
  local UDPData = packer:popValue()
  if(not success) then
    _G.IP.logger.write("Failed to unpack data string.")
    return false
  end
  return true, UDPData
end

--- Creates a callback to run when a message is received on a port from an IP (optional).
--- @param IP number|string IP to receive from (can be in decimal or fancy string format).
--- @param port number Port to receive on.
--- @param callback fun(data:table,port:number,IP:number) Callback function to run if a message satisfies the message requirements.
--- @return Callback Callback object for finding information about the callback.
--- @overload fun(port:number,callback:function):Callback
function simpleAPI.createMessageCallback(IP, port, callback)
  return UDP.UDPListen(port, function(message)
    if(message.header.targetPort == port) then
      if(IP) then
        if(message.header.senderIP == IP) then
          callback(message.data, port, IP)
        end
      else
        callback(message.data, port, message.header.senderIP)
      end
    end
  end)
end

--- Removes a callback.
--- @param callback Callback Callback object created when registering the callback.
function simpleAPI.removeMessageCallback(callback)
  return UDP.UDPIgnore(callback)
end

return simpleAPI