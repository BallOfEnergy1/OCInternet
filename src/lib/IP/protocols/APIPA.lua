
local util = require("IP.IPUtil")
local ARP = require("IP.protocols.ARP")

local apipa = {}

local startingRange = util.fromUserFormat("0880:0000:0000:0000")

function apipa.register()
  ::start::
  local IP = util.createIP(startingRange, math.random(0xFFFFFFFF))
  local result, code = ARP.resolve(IP, true)
  if(result) then
    goto start
  end
  if(code == -1) then
    return nil, code
  end
  _G.DHCP.DHCPRegisteredModems[_G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC] = true -- Worst case scenario, I end up having to make a new var here for simplicity. Not too bad.
  _G.IP.logger.write("APIPA IP: " .. util.toUserFormat(IP))
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  _G.IP.modems[addr].clientIP = IP
  _G.IP.modems[addr].defaultGateway = 0x00
  _G.IP.modems[addr].subnetMask = util.fromUserFormat("FFFF:FFFF:0000:0000")
end

return apipa