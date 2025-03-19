
local ICMP = require("IP.protocols.ICMP")
local shell = require("shell")
local util = require("IP.IPUtil")
local ARP = require("IP.protocols.ARP")
local event = require("event")

local args, ops = shell.parse(...)

local function printInfo(IP, pings)
  print("Ping statistics for " .. IP .. ":")
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
  print("\tPackets: Sent = " .. #pings .. ", Received = " .. received .. ", Lost = " .. #pings - received .. ",")
  print("Approximate round trip times in ticks:")
  print("\tMinimum = " .. math.floor((min or 0)*20*10000)/10000 .. " ticks, Maximum = " .. math.floor((max or 0)*20*10000)/10000 .. " ticks, Average = " .. math.floor((avg or 0)*20*10000)/10000 .. " ticks")
end

if(args[1] ~= nil and type(args[1]) == "string") then -- Take as IP.
  local IP = util.fromUserFormat(args[1])
  if(IP) then
    local payloadSize
    if(ops.l and type(ops.l) == "string") then
      payloadSize = tonumber(ops.l)
    else
      payloadSize = 32
    end
    if((IP ~= (_G.ROUTE and _G.ROUTE.routeModem.clientIP or _G.IP.primaryModem.clientIP)) and ARP.resolve(IP) == nil) then
      print("Could not resolve hostname " .. args[1] .. ".")
      return
    end
    if(util.toUserFormat(IP) ~= args[1]) then
      print("Pinging " .. args[1] .. " [" .. util.toUserFormat(IP) .. "] with " .. payloadSize .. " bytes of data.")
    else
      print("Pinging " .. args[1] .. " with " .. payloadSize .. " bytes of data.")
    end
    local pings = {}
    local count = 4
    if(ops.c and type(ops.c) == "string") then
      count = tonumber(ops.c)
    elseif(ops.t) then
      count = math.huge
    end
    for i = 1, count do
      local pcTime = require("computer").uptime()
      local uptime
      local response
      response = ICMP.ping(IP, payloadSize)
      if(response == nil) then
        print("Ping timed out.")
        table.insert(pings, {received=false})
      else
        uptime = require("computer").uptime()
        print("Reply from " .. util.toUserFormat(IP) .. ": bytes=" .. payloadSize .. " time=" .. math.floor((uptime - pcTime) * 10000)/10000)
        table.insert(pings, {time=uptime - pcTime, received=true})
      end
      if(i ~= count) then
        if(event.pull((1 - ((uptime or pcTime + 1) - pcTime)), "interrupted")) then
          printInfo(util.toUserFormat(IP), pings)
          return
        end
      end
    end
    printInfo(util.toUserFormat(IP), pings)
  end
end