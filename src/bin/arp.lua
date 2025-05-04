
local util = require("IP.IPUtil")
local shell = require("shell")
local ARP = require("IP.protocols.ARP")

local args, ops = shell.parse(...)

local function printHelp()
  print("Displays and modifies the IP-to-Physical address translation tables used by address resolution protocol (ARP).")
  print("ARP -s inet_addr eth_addr")
  print("ARP -d inet_addr")
  print("ARP -a")
  print()
  print("\t-a\tDisplays current ARP entries by interrogating the current protocol data.")
  print("\t-s\tAdds the host and associates the Internet address inet_addr with the Physical address eth_addr.")
  print("\t-d\tDeletes the host specified by inet_addr. inet_addr may be wildcarded with * to delete all hosts.")
end

if(ops["a"]) then
  for MAC, v in pairs(_G.IP.modems) do
    print("Interface: " .. util.toUserFormat(v.clientIP))
    print("  Internet Address\tPhysical Address\t\t\tType")
    if(_G.ARP.staticMappings[MAC]) then
      for j, w in pairs(_G.ARP.staticMappings[MAC]) do
        print("  " .. util.toUserFormat(w.IP) .. "\t" .. j .. "\tstatic")
      end
    end
    if(_G.ARP.cachedMappings[MAC]) then
      for j, w in pairs(_G.ARP.cachedMappings[MAC]) do
        print("  " .. util.toUserFormat(w.IP) .. "\t" .. j .. "\tdynamic")
      end
    end
    print()
  end
elseif(ops["s"]) then
  if(args[1] ~= nil and args[2] ~= nil) then
    if(not util.fromUserFormat(args[1])) then
      print("Invalid IP address.")
    end
    if(not util.isValidMAC(args[2])) then
      print("Invalid MAC address.")
    end
    for MAC, _ in pairs(_G.IP.modems) do
      if(not _G.ARP.staticMappings[MAC]) then _G.ARP.staticMappings[MAC] = {} end
      _G.ARP.staticMappings[MAC][args[2]] = {IP = util.fromUserFormat(args[1]), ignore = false}
    end
    ARP.writeToDB()
    print()
  else
    printHelp()
  end
elseif(ops["d"]) then
  if(args[1] ~= nil) then
    local IP = util.fromUserFormat(args[1])
    if(not IP) then
      print("Invalid IP address.")
    end
    for modemMAC, _ in pairs(_G.IP.modems) do
      for MAC, v in pairs(_G.ARP.staticMappings[modemMAC]) do
        if(v.IP == IP) then
          _G.ARP.staticMappings[modemMAC][MAC] = nil
        end
      end
    end
    ARP.writeToDB()
    print()
  else
    printHelp()
  end
else
  printHelp()
end