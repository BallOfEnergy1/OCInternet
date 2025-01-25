
local util = require("IP.IPUtil").util
local ARP = require("IP.protocols.ARP")

local apipa = {}

local startingRange = util.fromUserFormat("0880:0000:0000:0000")

function apipa.register()
  ::start::
  local IP = util.createIP(startingRange, math.random(0xFFFFFFFF))
  local result, code = ARP.resolve(IP)
  if(result) then
    goto start
  end
  if(code == -1) then
    return nil, code
  end
  _G.DHCP.DHCPRegistered = true -- Worst case scenario, I end up having to make a new var here for simplicity. Not too bad.
  _G.IP.logger.write("APIPA IP: " .. util.toUserFormat(IP))
  _G.IP.clientIP = IP
  _G.IP.defaultGateway = 0x00
  _G.IP.subnetMask = util.fromUserFormat("FFFF:FFFF:0000:0000")
end

return apipa