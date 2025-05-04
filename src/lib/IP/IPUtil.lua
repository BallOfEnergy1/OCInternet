
--- Utility class for IPs and subnets.
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

--- Converts a decimal IP format into a string-readable representation.
---
--- @param dec number Decimal representation of IP.
--- @return string "Fancy" representation of IP. Returns "nil" if `nil` or any non-number type was provided.
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

--- Converts a string IP into a decimal representation. This includes fancy formats/shorthands including `123::1` for `0123:0000:0000:0001`.
---
--- Returns `nil` and an error message if an incorrect input was given.
--- @param IP string String "fancy" representation of an IP.
--- @return number|nil Decimal representation of `IP`.
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

--- Creates an IP using a subnet identifier and a device identifier.
--- @param subnet number Subnet identifier.
--- @param ID number Device identifier.
--- @return number Combined subnet and device identifiers to form a proper IP.
function util.createIP(subnet, ID)
  return subnet | ID
end

--- Gets the subnet identifier from a given IP.
---
--- Throws an error if the given IP is non-numerical.
--- @param IP number IP to get the subnet identifier from.
--- @return number Subnet identifier in decimal form.
function util.getSubnet(IP)
  if(type(IP) ~= "number") then
    error("IP not numerical (" .. tostring(IP) .. ").")
  end
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  return IP & _G.IP.modems[addr].subnetMask
end

--- Gets the device identifier from a given IP.
---
--- Throws an error if the given IP is non-numerical.
--- @param IP number IP to get the device identifier from.
--- @return number Device identifier in decimal form.
function util.getID(IP)
  if(type(IP) ~= "number") then
    error("IP not numerical (" .. tostring(IP) .. ").")
  end
  local addr = _G.ROUTE and _G.ROUTE.routeModem.MAC or _G.IP.primaryModem.MAC
  return IP & (~_G.IP.modems[addr].subnetMask)
end

--- Checks if a given MAC address is valid.
---
--- @param MAC number MAC address to check validity of.
--- @return boolean If the address is valid.
function util.isValidMAC(MAC)
  return type(MAC) == "string" and (MAC:sub(9, 9) .. MAC:sub(14, 14) .. MAC:sub(19, 19) .. MAC:sub(24, 24) == "----")
end

--- @class Modem
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
  o.MAC = MAC
  o.modem = modem
  return o
end

--- Standard setup function, for use during initialization.
--- @private
function util.setup(config)
  if(not _G.IP or not _G.IP.isInitialized) then
    local multiport = require("IP.multiport")
    local packetFrag = require("IP.packetFrag")
    require("filesystem").makeDirectory("/var/ip") -- TODO get rid of this bs
    --- Global table used by the IP utility library, and therefore the entire network stack.
    _G.IP = {}
    do
      --- Global constants used by the network stack; it is not suggested to edit these.
      _G.IP.constants = {
        broadcastMAC = "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",    -- Broadcast MAC
        broadcastIP = util.fromUserFormat("FFFF:FFFF:FFFF:FFFF"), -- Broadcast IP
        internalIP = util.fromUserFormat("0000:0000:0000:0000")   -- Used internally for protocols lower than IPv5 or DHCP (IPs are required).
      }
      --- Global logger for the network stack.
      _G.IP.logger = logutil.initLogger("IPv5", "/var/ip/ip.log")
      --- Table of all registered modems on the network stack.
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
          --- Primary modem for the network stack (sending).
          _G.IP.primaryModem = modem
        end
      end
    end
    packetFrag.setup(config)
    --- Config table for use after initialization.
    _G.IP.config = config
    --- Initialization token.
    _G.IP.isInitialized = true
  end
end

return util