local term = require("term")
local filesystem = require("filesystem")
local serialization = require("serialization")
local gpu = term.gpu()

local resX, resY = gpu.maxResolution()

gpu.setResolution(resX, resY)

local tier = 1

if(resX == 80 and resY == 25) then
  tier = 2
elseif(resX == 160 and resY == 50) then
  tier = 3
end

local windowX, windowY = 30 * (tier * 1.25), 8 * (tier * 1.125)

local buffer = gpu.allocateBuffer(windowX, windowY)

if(buffer == nil) then
  print("Insufficient VRAM for installer, disabling VRAM buffering...")
  os.sleep(2)
  buffer = 0
end

local function getAssetsFile()
  return "/home/assets"
end

local function writeTextCentered(y, text)
  gpu.set((windowX / 2 + 1) - (math.floor(#text / 2)), y, text)
end

local function findExistingInstallation()
  -- There's a few things to check for an existing installation.
  -- 1. To check for an active installation, we can check for the initialized IP table.
  if(_G.IP ~= nil) then
    return 2 -- Installed, Initialized.
  end
  
  -- 2. To check for an uninstalled installation, check for the startup file itself.
  if(not filesystem.exists("/lib/IP/startup.lua")) then
    return 0 -- Not installed.
  end
  
  return 1 -- Installed but uninitialized.
end

local function validateExistingInstallation()
  local logHandle = io.open(os.getenv("PWD") .. "/validation.log", "w")
  local success, crc32 = pcall(function() return require("crc32") end)
  if(not success) then
    logHandle:write("CRC32 library not found.\n")
    logHandle:write(crc32)
    return false
  end
  local handle = io.open(getAssetsFile())
  if(not handle) then
    logHandle:write("Assets file not found.\n")
    return false
  end
  logHandle:write("Assets file found.\n")
  local assets = serialization.unserialize(handle:read("*a"))
  handle:close()
  logHandle:write("Assets deserialized.\n")
  
  for _, v in pairs(assets) do
    logHandle:write("Checking " .. v.path .. "\n")
    handle = io.open(v.path)
    local crc = crc32.Crc32(handle:read("*a"))
    if(crc ~= v.crc) then
      handle:close()
      logHandle:write("Checksum error found. Consider reinstalling the stack or this file.\n")
      logHandle:close()
      return false
    end
    handle:close()
  end
  logHandle:write("All files validated successfully.\n")
  logHandle:close()
  return true
end

gpu.setBackground(tier ~= 1 and 0xCC6DFF or 0x00)
gpu.fill(1, 1, resX, resY, " ")

gpu.setActiveBuffer(buffer)
gpu.setBackground(tier ~= 1 and 0xB4B4B4 or 0x00)
gpu.setForeground(tier ~= 1 and 0x00 or 0xFFFFFF)

gpu.fill(1, 1, windowX, windowY, " ")
gpu.fill(1, 1, windowX, 1, "═")
gpu.fill(1, windowY, windowX, 1, "═")
gpu.fill(1, 1, 1, windowY, "║")
gpu.fill(windowX, 1, 1, windowY, "║")
gpu.set(1, 1, "╔")
gpu.set(1, windowY, "╚")
gpu.set(windowX, 1, "╗")
gpu.set(windowX, windowY, "╝")

local event = require("event")
local unicode = require("unicode")

::Stage1::

local number

gpu.fill(2, 2, windowX-2, windowY-2, " ")
writeTextCentered(2, "1. Install OCIP network stack")
writeTextCentered(3, "2. Modify existing installation")
writeTextCentered(15, "0. Exit")
gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)

::Stage1_1::
local _, _, char, code = event.pull("key_down")
if char == 3 and code == 46 or char == 127 and code == 18 then
  gpu.setActiveBuffer(0)
  gpu.freeBuffer(buffer)
  return
elseif char ~= 0 then
  number = tonumber(unicode.char(char))
end
if(not number) then
  goto Stage1_1
end

gpu.fill(2, 2, windowX-2, windowY-2, " ")

if(number == 0) then
  gpu.setActiveBuffer(0)
  gpu.freeBuffer(buffer)
  gpu.setBackground(0x00)
  gpu.setForeground(0xFFFFFF)
  term.clear()
  return
elseif(number == 1) then
  gpu.fill(2, 2, windowX-2, windowY-2, " ")
  writeTextCentered(2, "Choose an installation method.")
  writeTextCentered(3, "1. Standard install")
  writeTextCentered(4, "2. Lightweight install.")
  writeTextCentered(5, "3. Server install")
  writeTextCentered(6, "4. Router install")
  writeTextCentered(7, "5. Advanced install")
  writeTextCentered(15, "0. Return to previous page")
  gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
  ::Stage2_1_1::
  _, _, char, code = event.pull("key_down")
  if char == 3 and code == 46 or char == 127 and code == 18 then
    goto Stage1
  elseif char ~= 0 then
    number = tonumber(unicode.char(char))
  end
  if(not number) then
    goto Stage2_1_1
  end
  
  if(number == 0) then
    goto Stage1
  elseif(number == 1) then
  
  elseif(number == 2) then
  
  elseif(number == 3) then
  
  elseif(number == 4) then
  
  elseif(number == 5) then
  
  end
elseif(number == 2) then
  local status = findExistingInstallation()
  if(status == 0) then
    gpu.fill(2, 2, windowX-2, windowY-2, " ")
    writeTextCentered(2, "No installation found")
    writeTextCentered(3, "Press any key to return.")
    gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
    event.pull("key_down")
    goto Stage1
  end
  local text = status == 1 and "Disabled" or "Enabled"
  gpu.fill(2, 2, windowX-2, windowY-2, " ")
  writeTextCentered(2, "Installation status: " .. text)
  writeTextCentered(4, "1. Validate installation")
  writeTextCentered(5, "2. Delete installation")
  if(status == 2) then
    writeTextCentered(6, "3. Deactivate installation")
  else
    writeTextCentered(6, "3. Activate installation")
  end
  writeTextCentered(15, "0. Return to previous page")
  gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
  ::Stage2_2_1::
  _, _, char, code = event.pull("key_down")
  if char == 3 and code == 46 or char == 127 and code == 18 then
    goto Stage1
  elseif char ~= 0 then
    number = tonumber(unicode.char(char))
  end
  if(number == 0) then
    goto Stage1
  elseif(number == 1) then
    gpu.fill(2, 2, windowX-2, windowY-2, " ")
    writeTextCentered(2, "Validating installation...")
    gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
    if(validateExistingInstallation()) then
      gpu.fill(2, 2, windowX-2, windowY-2, " ")
      writeTextCentered(2, "Installation validated successfully.")
      writeTextCentered(3, "Press any key to return.")
      gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
      event.pull("key_down")
      goto Stage1
    else
      gpu.fill(2, 2, windowX-2, windowY-2, " ")
      writeTextCentered(2, "Installation failed validation checks!")
      writeTextCentered(3, "See " .. os.getenv("PWD") .. "/validation.log for details.")
      writeTextCentered(4, "Press any key to return.")
      gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
      event.pull("key_down")
      goto Stage1
    end
  elseif(number == 2) then
    for _, v in pairs(getAssetsFile()) do
      filesystem.remove(v.name)
    end
    local handle = io.open("/home/.shrc", "r")
    local fileContent = handle:read("*a")
    local newContent = ""
    for line in fileContent:gmatch("[^\n]+") do
      if(line ~= "/lib/IP/startup.lua") then
        newContent = newContent .. line .. "\n"
      end
    end
    handle:close()
    handle = io.open("/home/.shrc", "w")
    handle:write(newContent)
    handle:close()
    gpu.fill(2, 2, windowX-2, windowY-2, " ")
    writeTextCentered(2, "A reboot is required.")
    writeTextCentered(3, "Press any key to reboot.")
    gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
    event.pull("key_down")
    os.execute("reboot")
  elseif(number == 3) then
    if(status == 1) then
      local handle = io.open("/home/.shrc", "r")
      local fileContent = handle:read("*a")
      handle:close()
      handle = io.open("/home/.shrc", "w")
      handle:write("/lib/IP/startup.lua\n" .. fileContent)
      handle:close()
      gpu.fill(2, 2, windowX-2, windowY-2, " ")
      writeTextCentered(2, "A reboot is required.")
      writeTextCentered(3, "Press any key to reboot.")
      gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
      event.pull("key_down")
      os.execute("reboot")
    elseif(status == 2) then
      local handle = io.open("/home/.shrc", "r")
      local fileContent = handle:read("*a")
      local newContent = ""
      for line in fileContent:gmatch("[^\n]+") do
        if(line ~= "/lib/IP/startup.lua") then
          newContent = newContent .. line .. "\n"
        end
      end
      handle:close()
      handle = io.open("/home/.shrc", "w")
      handle:write(newContent)
      handle:close()
      gpu.fill(2, 2, windowX-2, windowY-2, " ")
      writeTextCentered(2, "A reboot is required.")
      writeTextCentered(3, "Press any key to reboot.")
      gpu.bitblt(0, (resX / 2) - windowX / 2 + 1, (resY / 2) - windowY / 2 + 1)
      event.pull("key_down")
      os.execute("reboot")
    else
      goto Stage2_2_1
    end
  else
    goto Stage2_2_1
  end
else
  goto Stage1_1
end

gpu.setActiveBuffer(0)
gpu.freeBuffer(buffer)
gpu.setBackground(0x00)
gpu.setForeground(0xFFFFFF)
term.clear()