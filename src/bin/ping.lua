
local ICMP = require("IP.protocols.ICMP")
local shell = require("shell")
local util = require("IP.IPUtil").util
local ARP = require("IP.protocols.ARP")
local event = require("event")

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

local function printInfo(pings)
  print("Ping statistics for " .. args[1] .. ":")
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
  print("\tMinimum = " .. math.floor(min*20*100)/100 .. " ticks, Maximum = " .. math.floor(max*20*100)/100 .. " ticks, Average = " .. math.floor(avg*20*100)/100 .. " ticks")
end

if(args[1] ~= nil and type(args[1]) == "string") then -- Take as IP.
  if(util.fromUserFormat(args[1])) then
    local payloadSize
    if(ops.l and type(ops.l) == "string") then
      payloadSize = tonumber(ops.l)
    else
      payloadSize = 32
    end
    local IP = util.fromUserFormat(args[1])
    if(ARP.resolve(IP) == nil) then
      print("Could not resolve hostname " .. args[1] .. ".")
      return
    end
    print("Pinging " .. args[1] .. " with " .. payloadSize .. " bytes of data.")
    local pings = {}
    local count = 4
    if(ops.c and type(ops.c) == "string") then
      count = tonumber(ops.c)
    elseif(ops.t) then
      count = math.huge
    end
    for i = 1, count do
      local pcTime = require("computer").uptime()
      local response, code = ICMP.send(IP, 0x1A, makePayload(32), true)
      if(response == nil) then
        if(code == -1) then
          printInfo(pings)
          return
        end
        print("Ping timed out.")
        table.insert(pings, {received=false})
      else
        print("Reply from " .. args[1] .. ": bytes=" .. payloadSize .. " time=" .. require("computer").uptime() - pcTime)
        table.insert(pings, {time=require("computer").uptime() - pcTime, received=true})
      end
      if(i ~= count) then
        if(event.pull(1, "interrupted")) then
          printInfo(pings)
          return
        end
      end
    end
    printInfo(pings)
  end
end