
local util = require("IP.IPUtil")

for _, v in pairs(_G.IP.modems) do
  print("Interface: " .. util.toUserFormat(v.clientIP))
  print("  Internet Address\tPhysical Address\t\t\tType")
  local type = "dynamic" -- Type is always dynamic here, ARP doesn't support static routes yet.
  for j, w in pairs(_G.ARP.cachedMappings) do
    print("  " .. util.toUserFormat(w.IP) .. "\t" .. j .. "\t" .. type)
  end
  print()
end
