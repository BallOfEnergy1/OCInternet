
local ICMP = require("IP.protocols.ICMP")
local shell = require("shell")
local util = require("IP.IPUtil").util
local serialization = require("serialization")
local ARP = require("IP.protocols.ARP")

local args, ops = shell.parse(...)

local function makePayload(size)
  local payload = ""
  for _ = 0, size do
    payload = payload .. string.char(math.random(0xFF))
  end
  return serialization.serialize(payload)
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
    print("Pinging " .. args[1] .. " with " .. payloadSize .. " bytes of data.")
    local pings = {}
    for _ = 0, 4 do
      local pcTime = require("computer").uptime()
      local response = ICMP.send(IP, 0x1A, makePayload(32))
      if(response == nil) then
        print("Ping timed out.")
        table.insert(pings, {received=false})
      else
        print("Reply from " .. args[1] .. ": bytes=" .. payloadSize .. " time=" .. require("computer").uptime() - pcTime)
        table.insert(pings, {time=require("computer").uptime() - pcTime, received=true})
      end
    end
    print("Ping statistics for " .. args[1] .. ":")
    local recieved
    local min, max, avg = 0, 0, 0
    local totalTime = 0
    for _, v in pairs(pings) do
      if(v.received) then
        recieved = recieved + 1
        if(v.time > max) then max = v.time end
        if(v.time < min) then min = v.time end
        totalTime = totalTime + v.time
      end
    end
    avg = totalTime / #pings
    print("\tPackets: Sent = " .. #pings .. ", Received = " .. recieved .. ", Lost = " .. #pings - recieved .. ",")
    print("Approximate round trip times in ticks:")
    print("\tMinimum = " .. min .. "t, Maximum = " .. max .. "t, Average = " .. avg .. "t")
  end
end