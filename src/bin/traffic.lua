
local ICMP = require("IP.protocols.ICMP")
local shell = require("shell")
local util = require("IP.IPUtil")
local ARP = require("IP.protocols.ARP")
local event = require("event")
local term = require("term")

local args, ops = shell.parse(...)

local function makePayload(size)
  local payload = ""
  local counter = 0x61
  for _ = 0, size do
    payload = payload .. string.char(counter)
    counter = counter + 1
    if(counter > 0x7A) then
      counter = 0x61
    end
  end
  return payload
end

local payloadSize

local function printInfo(IP, pings)
  local received = 0
  local min, max, avg
  local totalTime = 0
  for _, v in pairs(pings) do
    if(v.received) then
      received = received + 1
      if(not max or v.time > max) then max = v.time end
      if(not min or v.time < min) then min = v.time end
      totalTime = totalTime + v.time
    end
  end
  avg = totalTime / #pings
  local userFriendly = util.toUserFormat(IP)
  if(userFriendly ~= args[1]) then
    print("Sending traffic to " .. args[1] .. " [" .. userFriendly .. "] with " .. payloadSize .. " bytes of data (each).")
  else
    print("Sending traffic to " .. args[1] .. " with " .. payloadSize .. " bytes of data (each).")
  end
  print("Traffic statistics for " .. userFriendly .. ":\n" ..
  "\tPackets: Sent = " .. #pings .. ", Received = " .. received .. ", Lost = " .. #pings - received .. ",\n" ..
  "Approximate round trip times in ticks:\n" ..
  "\tMinimum = " .. math.floor((min or 0)*20*10000)/10000 .. " ticks, Maximum = " .. math.floor((max or 0)*20*10000)/10000 .. " ticks, Average = " .. math.floor((avg or 0)*20*10000)/10000 .. " ticks\n")
end

if(args[1] ~= nil and type(args[1]) == "string") then -- Take as IP.
  local IP = util.fromUserFormat(args[1])
  if(IP) then
    if(ops.l and type(ops.l) == "string") then
      payloadSize = tonumber(ops.l)
    else
      payloadSize = 32
    end
    if((IP ~= (_G.ROUTE and _G.ROUTE.routeModem.clientIP or _G.IP.primaryModem.clientIP)) and ARP.resolve(IP) == nil) then
      print("Could not resolve hostname " .. args[1] .. ".")
      return
    end
    local pings = {}
    local payload = makePayload(payloadSize)
    while true do
      local pcTime = require("computer").uptime()
      local uptime
      local response
      response = ICMP.send(IP, 0x1A, payload, true)
      if(response == nil) then
        table.insert(pings, {received=false})
      else
        uptime = require("computer").uptime()
        table.insert(pings, {time=uptime - pcTime, received=true})
      end
      if(event.pull(0.05, "interrupted")) then
        printInfo(util.toUserFormat(IP), pings)
        return
      end
      term.clear()
      printInfo(IP, pings)
    end
  end
end