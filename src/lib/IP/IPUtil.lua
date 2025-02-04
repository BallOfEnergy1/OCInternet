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
  if(dec == nil or type(dec) ~= "number") then
    return "nil"
  end
  local mask = 65535
  local endingString = ""
  for quartet = 0, 2 do
    endingString = ":" .. util.toHex((dec & mask) >> quartet * 16) .. endingString
    mask = mask << 16
  end
  endingString = util.toHex((dec & mask) >> 48) .. endingString
  return string.upper(endingString)
end

function util.fromUserFormat(IP)
  local formatted
  if(string.find(IP, "::")) then
    local s, e = string.find(IP, "::")
    local prefix = IP:sub(0, s - 1)
    local suffix = IP:sub(e, #IP)
    local t = 1
    while t < 4-1 do
      t = 1
      for _ in (prefix .. suffix):gmatch(":") do
        t = t + 1
      end
      prefix = prefix .. ":0"
    end
    formatted = prefix .. suffix
    if(formatted:sub(0, 1) == ":") then
      formatted = "0" .. formatted
    end
    if(formatted:sub(#formatted) == ":") then
      formatted = formatted .. "0"
    end
  end
  if(formatted == nil) then
    formatted = IP
  end
  local segments = {}
  for str in formatted:gmatch("([^:]+)") do
    for _ = 1, 4 - #str do
      str = "0" .. str
    end
    if(#str > 4) then
      return nil, "Invalid input."
    end
    table.insert(segments, str)
  end
  local parsedIP = tonumber(segments[1] .. segments[2] .. segments[3] .. segments[4], 16)
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
  clientIP = 0,
  subnetMask = 0,
  defaultGateway = 0,
  MAC = "",
  modem = {},
}

function Modem:new(clientIP, subnetMask, defaultGateway, MAC, modem)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.clientIP = clientIP
  o.subnetMask = subnetMask
  o.defaultGateway = defaultGateway
  o.MAC  = MAC
  o.modem   = modem
  return o
end

function util.setup(config)
  if(not _G.IP or not _G.IP.isInitialized) then
    local multiport = require("IP.multiport")
    local packetFrag = require("IP.packetFrag")
    require("filesystem").makeDirectory("/var/ip") -- TODO get rid of this bs
    _G.IP = {}
    do
      _G.IP.logger = logutil.initLogger("IPv5", "/var/ip/ip.log")
      _G.IP.modems = {}
      local list = component.list("modem")
      for addr in list do
        local modem = Modem:new(
          util.fromUserFormat(config.IP.staticIP),
          util.fromUserFormat(config.IP.staticSubnetMask),
          util.fromUserFormat(config.IP.staticGateway),
          addr,
          component.proxy(addr)
        )
        multiport.setupModem(modem.modem)
        _G.IP.modems[addr] = modem
        if(_G.IP.primaryModem == nil) then
          _G.IP.primaryModem = modem
        end
      end
    end
    packetFrag.setup()
    _G.IP.isInitialized = true
  end
end

return util