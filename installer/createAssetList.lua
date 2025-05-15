
local serialization = require("serialization")

local assets = {
  "/etc/OCIP",
  "/lib/IP",
  "/lib/button.lua",
  "/lib/hyperpack.lua",
  "/lib/logutil.lua",
  "/lib/tableutil.lua",
  "/lib/crc32.lua",
  "/lib/tableutil.lua",
  "/bin/arp.lua",
  "/bin/dns.lua",
  "/bin/ftp.lua",
  "/bin/ftpd.lua",
  "/bin/ipconfig.lua",
  "/bin/luashark.lua",
  "/bin/netstat.lua",
  "/bin/ochat.lua",
  "/bin/ping.lua",
  "/bin/router.lua",
  "/bin/tcpdebug.lua",
  "/bin/traffic.lua"
}

local crc32 = require("crc32")
local filesystem = require("filesystem")

local formatted = {}

local function processAllInDirectory(dir)
  for v in filesystem.list(dir) do
    if(filesystem.isDirectory(dir .. "/".. v)) then
      processAllInDirectory(dir .. "/" .. v)
    else
      local path = (dir .. "/" .. v):gsub("/+", "/")
      print("> " .. path)
      local handle = io.open(path)
      if(not handle) then
        print("File not found.")
      else
        table.insert(formatted, {path = path, crc = crc32.Crc32(handle:read("*a"))})
        handle:close()
      end
    end
  end
end

for i, v in pairs(assets) do
  if(filesystem.isDirectory(v)) then
    processAllInDirectory(v)
  else
    print("> " .. v)
    local handle = io.open(v)
    if(not handle) then
      print("File not found.")
    else
      table.insert(formatted, {path = v, crc = crc32.Crc32(handle:read("*a"))})
      handle:close()
    end
  end
end

local file = io.open(os.getenv("PWD") .. "/assets", "w")
local serialized = serialization.serialize(formatted)
file:write(serialized)
file:close()

print("Wrote " .. #serialized .. " Bytes to " .. os.getenv("PWD") .. "/assets.")