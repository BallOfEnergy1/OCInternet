
local thread = require("thread")
thread.create(function()
  local config = {}
  os.sleep(0.05)
  loadfile("/etc/OCIP/IP.conf", "t", config)()
  local serializationUnsafe = require("IP.serializationUnsafe")
  -- Setup unsafe serialization library.
  serializationUnsafe.setup(config)
  
  local netAPI = require("IP.API.netAPI")
  -- Setup netAPI library.
  netAPI.setup(config)
  
  local IPUtil = require("IP.IPUtil")
  -- Setup IPUtil library.
  IPUtil.setup(config)
  
  local ARP = require("IP.protocols.ARP")
  -- Setup ARP protocol.
  ARP.setup(config) -- Init ARP before DHCP in-case APIPA is used.
  os.sleep(0.05) -- Give OS time to initialize.
  
  local DHCP = require("IP.protocols.DHCP")
  -- Setup DHCP protocol.
  DHCP.setup(config)
  
  local ICMP = require("IP.protocols.ICMP")
  -- Setup ICMP protocol.
  ICMP.setup()
  
  while true do
    os.sleep(0.05) -- Thread loop.
  end
end):detach()