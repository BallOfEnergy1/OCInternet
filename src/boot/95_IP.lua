print("Registering IP Utility...")
local IPUtil = require("IP/IPUtil")
IPUtil.setup()
print("Leasing IP via DHCPv4.1...")
local DHCP = require("IP/protocols/DHCP")
DHCP.setup()
print("Done.")