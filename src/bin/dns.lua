
local shell = require("shell")
local args, ops = shell.parse(...)

if(not _G.DNS.serverIsInitialized) then
  print("DNS server not initialized, exiting...")
  return
end

local DNSServer = require("IP.protocols.DNSServer")

local allRecords = DNSServer.readAllRRs()

print("OCIP DNS Commandline Tool\n")

local function makeSize(text, size)
  local stringifiedText = tostring(text)
  if(#stringifiedText < size) then
    for _ = 1, size - #stringifiedText do
      stringifiedText = stringifiedText .. " "
    end
  end
  return stringifiedText
end

if(#args == 0) then
  print("Reading from " .. _G.DNS.recordLocation .. "...")
  
  if(allRecords == nil) then
    print("No records found.")
    return
  end
  
  print("Record Index  Record Name         Record Type  Record TTL  Record Data")
  for i, v in pairs(allRecords) do
    print(makeSize(i, 14) .. makeSize(v.name, 20) .. makeSize(v.type, 13) .. makeSize(v.ttl, 12) .. v.data)
  end
  print("End of list.")
elseif(args[1] == "create" or args[1] == "c") then
  local record = DNSServer.createRR(tonumber(args[2]), args[3], tonumber(args[4]), table.unpack(args, 5))
  print("Created below record.")
  print("Record Name         Record Type  Record TTL  Record Data")
  print(makeSize(record.name, 20) .. makeSize(record.type, 13) .. makeSize(record.ttl, 12) .. record.data)
end