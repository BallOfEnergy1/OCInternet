local subnet = require("IP.subnet")
local netAPI = require("IP.API.netAPI")
local netAPIInternal = require("IP.netAPIInternal")

--- This class is the primary class for sending packets through a network.
--- @class Multiport
local multiport = {}
local multiportPort = 500

--- Sends a packet of choice (direct send).
---@param packet Packet The packet to send.
---@return nil
function multiport.send(packet)
  if(not _G.DHCP.skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  local address = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  netAPIInternal.sendUnicastUnsafe(packet, address)
  subnet.send(packet.header.targetMAC, multiportPort, packet)
end

--- Sends a packet of choice (broadcast).
---@param packet Packet The packet to broadcast.
---@return nil
function multiport.broadcast(packet)
  packet.header.targetMAC = _G.IP.constants.broadcastMAC
  packet.header.targetIP = _G.IP.constants.broadcastIP
  if(not _G.DHCP.skipRegister) then
    require("IP.protocols.DHCP").registerIfNeeded()
  end
  local address = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  netAPIInternal.sendBroadcastUnsafe(packet, address)
  subnet.broadcast(multiportPort, packet)
end

--- Waits for a message from another client for a specified timeout based on a defined condition.
---
--- Returns nil if no message was received after waiting `timeout` seconds.
---@param timeout number Timeout in seconds.
---@param eventCondition fun(packet:Packet):boolean The condition the function must satisfy to be returned (can be used for filtering to a port or protocol).
---@return Packet|nil
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

--- Sends/broadcasts a packet to a receiver and waits for a response. `attempts` can be used to control how many times the packet will be attempted to be sent.
---
--- Returns nil if no message was received after making `attempts` tries, each waiting `timeout` seconds.
---@param packet Packet Packet to send as a request.
---@param broadcast boolean Whether the packet sent should be broadcasted or sent directly.
---@param timeout number Timeout in seconds (per attempt).
---@param attempts number Amount of times to send the packet.
---@param eventCondition fun(packet:Packet):boolean The condition the function must satisfy to be returned (can be used for filtering to a port or protocol).
---@return Packet|nil
function multiport.requestMessageWithTimeout(packet, broadcast, timeout, attempts, eventCondition)
  local tries = 1
  local result
  while result == nil and tries <= attempts do
    if(broadcast) then
      multiport.broadcast(packet)
    else
      multiport.send(packet)
    end
    result = multiport.pullMessageWithTimeout(timeout, eventCondition)
    if(not result) then
      tries = tries + 1
    end
  end
  return result
end

--- Internal function, not for outside use.
--- @param targetPort number Hardware target port.
--- @param dist number Packet sent distance.
--- @param message Packet Received packet.
--- @private
function multiport.process(receiverMAC, targetPort, dist, message)
  if(targetPort == multiportPort) then
    netAPIInternal.receiveInboundUnsafe(message, receiverMAC, dist)
  end
end

--- For use when setting up a modem, only for use during stack initialization or when a new modem is added.
--- @param modem table Modem proxy table.
--- @private
function multiport.setupModem(modem)
  modem.open(multiportPort)
end

return multiport