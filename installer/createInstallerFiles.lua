
local stackRequired = {
  "/etc/OCIP/IP.conf",
  "/lib/IP",
  "/lib/button.lua",
  "/lib/hyperpack.lua",
  "/lib/logutil.lua",
  "/lib/tableutil.lua",
  "/lib/crc32.lua",
  "/lib/tableutil.lua",
  "/lib/auto_progress.lua",
  "/lib/oczlib.lua",
  "/lib/lualzw.lua",
  "/bin/tar.lua",
  "/bin/ocz.lua",
  "/bin/ipconfig.lua",
  "/bin/ping.lua"
}

local standardInstall = {
  "/bin/ochat.lua",
  "/bin/traffic.lua",
  "/bin/tcpdebug.lua",
  "/bin/luashark.lua",
  "/bin/ftp.lua",
  "/bin/arp.lua",
  "/bin/netstat.lua",
  "/usr/man/tar.man",
}

local serverInstall = {
  "/bin/ochat.lua",
  "/bin/traffic.lua",
  "/bin/tcpdebug.lua",
  "/bin/dns.lua",
  "/bin/ftpd.lua",
  "/bin/ftp.lua",
  "/bin/arp.lua",
  "/bin/netstat.lua",
  "/usr/man/tar.man",
}

local routerInstall = {
  "/bin/router.lua",
  "/bin/dns.lua",
  "/bin/traffic.lua",
  "/bin/arp.lua"
}

local formattedStackRequired = ""

for i, v in pairs(stackRequired) do
  formattedStackRequired = formattedStackRequired .. " " .. v
end

local formattedStandardInstall = formattedStackRequired .. " "

for i, v in pairs(standardInstall) do
  formattedStandardInstall = formattedStandardInstall .. " " .. v
end

local formattedServerInstall = formattedStackRequired .. " "

for i, v in pairs(serverInstall) do
  formattedServerInstall = formattedServerInstall .. " " .. v
end

local formattedRouterInstall = formattedStackRequired .. " "

for i, v in pairs(routerInstall) do
  formattedRouterInstall = formattedRouterInstall .. " " .. v
end

os.execute("tar -c -f lightweightInstall.tar " .. formattedStackRequired)
os.execute("tar -c -f standardInstall.tar " .. formattedStandardInstall)
os.execute("tar -c -f serverInstall.tar " .. formattedServerInstall)
os.execute("tar -c -f routerInstall.tar " .. formattedRouterInstall)
print("All files archived, beginning compression.")
os.execute("ocz -c -l lightweightInstall.tar.ocz " .. os.getenv("PWD") .. "/lightweightInstall.tar")
os.execute("ocz -c -l standardInstall.tar.ocz " .. os.getenv("PWD") .. "/standardInstall.tar")
os.execute("ocz -c -l serverInstall.tar.ocz " .. os.getenv("PWD") .. "/serverInstall.tar")
os.execute("ocz -c -l routerInstall.tar.ocz " .. os.getenv("PWD") .. "/routerInstall.tar")
print("All files compressed.")
os.execute("rm lightweightInstall.tar standardInstall.tar serverInstall.tar routerInstall.tar")