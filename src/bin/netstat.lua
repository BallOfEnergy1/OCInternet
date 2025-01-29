
local util = require("IP.IPUtil")

if(not _G.TCP) then
  print( "TCP not initialized.")
  return
end

print("Active Connections")

print(" Proto\tLocal Address\t\t\tForeign Address\t\t\tState")

for i, v in pairs(_G.TCP.sessions) do
  print(" TCP\t" .. util.toUserFormat(_G.IP.primaryModem.clientIP) .. ":" .. v:getPort() .. "\t" .. util.toUserFormat(v:getIP()) .. ":" .. v:getPort() .. "\t" .. v:getStatus())
end