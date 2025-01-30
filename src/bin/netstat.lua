
local util = require("IP.IPUtil")

if(not _G.TCP) then
  print( "TCP not initialized.")
  return
end

print("Active Connections")

print(" Proto\tLocal Address\t\t\tForeign Address\t\t\tState")

local function makeSize(text, size)
  local stringifiedText = tostring(text)
  if(#stringifiedText < size) then
    for _ = 1, size do
      stringifiedText = stringifiedText .. " "
    end
  end
  return stringifiedText
end

for i, v in pairs(_G.TCP.sessions) do
  print(" TCP\t" .. util.toUserFormat(_G.IP.primaryModem.clientIP) .. ":" .. makeSize(v:getPort(), 6) .. "\t" .. util.toUserFormat(v:getIP()) .. ":" .. makeSize(v:getPort(), 6) .. "\t" .. v:getStatus())
end