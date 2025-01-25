local IPUtil = require("IP.IPUtil")
IPUtil.setup()
local ARP = require("IP.protocols.ARP")
ARP.setup() -- Init ARP before DHCP in-case APIPA is used.
local DHCP = require("IP.protocols.DHCP")
DHCP.setup()
local ICMP = require("IP.protocols.ICMP")
ICMP.setup()