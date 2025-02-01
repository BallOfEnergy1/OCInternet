
local thread = require("thread")
thread.create(function()
  local config = {}
  loadfile("/etc/IP.conf", "t", config)()
  local IPUtil = require("IP.IPUtil")
  IPUtil.setup(config)
  local ARP = require("IP.protocols.ARP")
  ARP.setup() -- Init ARP before DHCP in-case APIPA is used.
  os.sleep(0.1) -- Give OS time to initialize.
  local DHCP = require("IP.protocols.DHCP")
  DHCP.setup(config)
  local ICMP = require("IP.protocols.ICMP")
  ICMP.setup()
  print("IP setup complete.")
  print("IP: " .. IPUtil.toUserFormat(_G.IP.primaryModem.clientIP))
  print("Subnet Mask: " .. IPUtil.toUserFormat(_G.IP.primaryModem.subnetMask))
end)