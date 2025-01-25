
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

print("Checking presence of default gateway...")
local response, code = ARP.resolve(_G.IP.defaultGateway)
if(response) then
  if(code == -1) then
    print("Operation canceled.")
    return
  end
  print("Failed to start router software, default gateway already present.")
end
print("No default gateway found.")

print("Starting DHCP server...")
local DHCPServer = require("IP.protocols.DHCPServer")
DHCPServer.setup()
print("DHCP server started.")

print("Setting IP...")
DHCP.flush()
_G.IP.clientIP = _G.IP.defaultGateway
print("IP set to " .. IPUtil.util.toUserFormat(_G.IP.clientIP))