
local component = require("component")

local function getUserYN()
  local userInput = io.read()
  if(userInput == "y" or userInput == "Y") then
    return true
  else
    return false
  end
end

print("Initializing router software...")

print("Starting libraries...")

_G.DHCP.static = true

local IPUtil = require("IP.IPUtil")
print(">IPUtil begin")
IPUtil.setup()
print(">IPUtil end")
local DHCP = require("IP.protocols.DHCP")
print(">DHCP begin")
DHCP.setup()
print(">DHCP end")
local ARP = require("IP.protocols.ARP")
print(">ARP begin")
ARP.setup()
print(">ARP end")
local ICMP = require("IP.protocols.ICMP")
print(">ICMP begin")
ICMP.setup()
print(">ICMP end")

print("Libraries started.")

local externalModemAddr
do
  ::select::
  print("Select network card for external communications.")
  local i = 1
  for addr, modem in pairs(component.list("modem")) do
    print(i .. ": " .. addr .. "; " .. modem)
    i = i + 1
  end
  local num = io.read()
  if(not tonumber(num) or tonumber(num) > i - 1) then
    print("Try again.")
    goto select
  end
  local j = 1
  for addr in pairs(component.list("modem")) do
    if(tonumber(num) == j) then
      externalModemAddr = addr
      break
    end
    j = j + 1
  end
end
local internalModemAddr
do
  ::select::
  print("Select network card for internal communications.")
  local i = 1
  for addr, modem in pairs(component.list("modem")) do
    print(i .. ": " .. addr .. "; " .. modem)
    i = i + 1
  end
  local num = io.read()
  if(not tonumber(num) or tonumber(num) > i - 1) then
    print("Try again.")
    goto select
  end
  local j = 1
  for addr in pairs(component.list("modem")) do
    if(tonumber(num) == j) then
      internalModemAddr = addr
      break
    end
    j = j + 1
  end
end

_G.ROUTE = {}
_G.ROUTE.externalModem = _G.IP.modems[externalModemAddr]
_G.ROUTE.internalModem = _G.IP.modems[internalModemAddr]
_G.ROUTE.routeModem = _G.IP.modems[internalModemAddr]
_G.ROUTE.isInitialized = true

print("Checking presence of default gateway...")
local addr = _G.ROUTE.internalModem.MAC
local response, code = ARP.resolve(_G.IP.modems[addr].defaultGateway)
if(response) then
  if(code == -1) then
    print("Operation canceled.")
    return
  end
  print("Failed to start router software, default gateway already present.")
  return
end
print("No default gateway found.")

print("Starting DHCP server...")
local DHCPServer = require("IP.protocols.DHCPServer")
DHCPServer.setup()
print("DHCP server started.")

print("Setting IP...")
DHCP.release()
_G.IP.modems[addr].clientIP = _G.IP.modems[addr].defaultGateway
print("IP set to " .. IPUtil.toUserFormat(_G.IP.modems[addr].clientIP))

local event = require("event")
local serialization = require("serialization")
local util = require("IP.IPUtil")

event.listen("multiport_message", function(_, _, _, _, _, message)
  if(serialization.unserialize(message).targetIP ~= util.fromUserFormat("0000:0000:0000:0000") and -- Check for broadcasts and filter out.
    serialization.unserialize(message).targetIP ~= util.fromUserFormat("FFFF:FFFF:FFFF:FFFF")
  ) then
    local packet = serialization.unserialize(message)
    -- TODO: Implement RIPv2 for routing.
  end
end)