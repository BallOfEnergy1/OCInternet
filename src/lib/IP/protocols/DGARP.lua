
local multiport = require("IP/multiport").multiport
local packet = require("IP/packetUtil")

local dgarp = {}

local dgarpPort = 1023

function dgarp.resolve(IP)
  multiport.send(packet.construct(
    _G.IP.defaultGateway,
    dgarpPort,
    IP
  ))
end

return dgarp