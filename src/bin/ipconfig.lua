
local util = require("IP.IPUtil")
print("OCIP IP Configuration\n\n")

for i, v in pairs(_G.IP.modems) do
  if(v.modem.isWireless()) then
    print("Wireless: " .. i .. "\n")
  else
    print("Ethernet: " .. i .. "\n")
  end
  print("\tMedia State . . . . . . . . . . . : Connected")
  print("\tConnection-specific DNS Suffix  . : ")
  print("\tIPv5 Address. . . . . . . . . . . : " .. util.toUserFormat(v.clientIP))
  print("\tSubnet Mask . . . . . . . . . . . : " .. util.toUserFormat(v.subnetMask))
  print("\tDefault Gateway . . . . . . . . . : " .. util.toUserFormat(v.defaultGateway))
  print("")
end