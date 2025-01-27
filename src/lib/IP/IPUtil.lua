local util = {}

local logutil = require("logutil")
local component = require("component")

function util.toHex(dec)
  local output = string.format("%x", dec)
  if(#output ~= 4) then
    repeat
      output = "0" .. output
    until (#output == 4)
  end
  return output
end

function util.toUserFormat(dec)
  local mask = 65535
  local endingString = ""
  for quartet = 0, 2 do
    endingString = ":" .. util.toHex((dec & mask) >> quartet * 16) .. endingString
    mask = mask << 16
  end
  endingString = util.toHex((dec & mask) >> 48) .. endingString
  return endingString
end

function util.fromUserFormat(IP)
  local firstQuartetIP  = IP:sub(1, 4)
  local secondQuartetIP = IP:sub(6, 9)
  local thirdQuartetIP  = IP:sub(11, 14)
  local fourthQuartetIP = IP:sub(16, 19)
  local parsedIP = tonumber(firstQuartetIP .. secondQuartetIP .. thirdQuartetIP .. fourthQuartetIP, 16)
  return parsedIP
end

-- Takes in dec representations!
function util.createIP(subnet, ID)
  return subnet | ID
end

function util.getSubnet(IP)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  return IP & _G.IP.modems[addr].subnetMask
end

function util.getID(IP)
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  return IP & (~_G.IP.modems[addr].subnetMask)
end

local Modem = {
  clientIP = nil,
  subnetMask = nil,
  defaultGateway = nil,
  MAC = nil,
  modem = nil,
}

function Modem:new(clientIP, subnetMask, defaultGateway, MAC, modem)
  local o = Modem
  setmetatable(o, self)
  self.clientIP = clientIP
  self.subnetMask = subnetMask
  self.defaultGateway = defaultGateway
  self.MAC  = MAC
  self.modem   = modem
  return o
end

function util.setup()
  require("filesystem").makeDirectory("/var/ip") -- TODO get rid of this bs
  if(not _G.IP or not _G.IP.isInitialized) then
    _G.IP = {}
    do
      _G.IP.logger = logutil.initLogger("IPv4.1", "/var/ip/ip.log")
      _G.IP.modems = {}
      local config = {}
      loadfile("/etc/IP.conf", "t", config)()
      for addr in pairs(component.list("modem")) do
        local modem = Modem:new(
          util.fromUserFormat(config.IP.staticIP),
          util.fromUserFormat(config.IP.staticSubnetMask),
          util.fromUserFormat(config.IP.staticGateway),
          addr,
          component.proxy(addr)
        )
        require("IP.multiport").setupModem(modem.modem)
        _G.IP.modems[addr] = modem
        if(_G.IP.primaryModem == nil) then
          _G.IP.primaryModem = modem
        end
      end
    end
    require("IP.packetFrag").setup()
    _G.IP.isInitialized = true
  end
end

return util