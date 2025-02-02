
local component = require("component")
local gpu = component.gpu

local resX, resY = gpu.maxResolution()

if(resX < 80 or resY < 25) then
  print("T2 or T3 Screen/GPU required.")
end

local event = require("event")
local buttonLib = require("button")

gpu.setResolution(resX, resY)

local backgroundColor = 0xFFFFFF
local accentColor = 0x66B6FF
local textColor = 0x000000

local buffer = gpu.allocateBuffer(resX, resY)

local status = 0
local selectedInterface
local packetsOnInterface

local function writeTopBar()
  gpu.setBackground(accentColor)
  gpu.fill(1, 1, resX, 1, " ")
  gpu.set(2, 1, "LuaShark Network Analyzer")
  local totalRAM = require("computer").totalMemory()
  local usedRAM = totalRAM - require("computer").freeMemory()
  gpu.set(resX - #"RAM Used: ..../....KB", 1, "RAM Used: " .. math.floor(usedRAM/1000) .. "/" .. math.floor(totalRAM/1000) .. "KB")
  gpu.setBackground(backgroundColor)
end

local registeredButtons = {}

do
  table.insert(registeredButtons, buttonLib.makeButton(1, 6, resX, 1, function()
    selectedInterface = 0
    status = 1
    packetsOnInterface = {}
  end, function()
    return status == 0
  end))
  
  local index = 0
  for i in pairs(_G.IP.modems) do
    table.insert(registeredButtons, buttonLib.makeButton(1, 7 + index, resX, 1, function()
      selectedInterface = i
      status = 1
      packetsOnInterface = {}
    end, function()
      return status == 0
    end))
    index = index + 1
  end
  table.insert(registeredButtons, buttonLib.makeButton(1, 1, resX, 1, function()
    selectedInterface = nil
    status = 0
    packetsOnInterface = nil
  end, function()
    return status == 1
  end))
end

local function drawEntryScreen()
  gpu.setForeground(textColor)
  gpu.setBackground(backgroundColor)
  gpu.fill(1, 1, resX, resY, " ")
  writeTopBar()
  gpu.set(3, 5, "Capture")
  gpu.set(4, 6, "- Loopback traffic")
  gpu.setBackground(0x0)
  gpu.fill(53, 6, 2, 1, " ")
  gpu.setBackground(backgroundColor)
  local index = 0
  for i, v in pairs(_G.IP.modems) do
    if(v.modem.isWireless()) then
      gpu.set(4, 7 + index, "- Wireless: " .. i)
    else
      gpu.set(4, 7 + index, "- Ethernet: " .. i)
    end
    gpu.setBackground(0x0)
    gpu.fill(53, 7 + index, 2, 1, " ")
    gpu.setBackground(backgroundColor)
    index = index + 1
  end
end

local function drawInterfaceScreen()

end

local function writeToScreen()
  gpu.bitblt()
end


local function updateNetworkIndicator(receiverMAC, senderMAC)
  if(status == 0) then -- In entry screen.
    local index = 1
    if(receiverMAC ~= senderMAC) then
      for i in pairs(_G.IP.modems) do
        if(i == receiverMAC) then
          break
        end
        index = index + 1
      end
    end
    gpu.setBackground(0x00FF00)
    gpu.fill(53, 6 + index, 2, 1, " ")
    writeToScreen()
    os.sleep(0.1)
    gpu.setBackground(0x00)
    gpu.fill(53, 6 + index, 2, 1, " ")
    gpu.setBackground(backgroundColor)
    writeToScreen()
  end
end

local function onNetworkEvent(_, receiverMAC, senderMAC, _, dist, message)
  updateNetworkIndicator(receiverMAC, senderMAC)
  if(status == 1 and selectedInterface == receiverMAC) then
    packetsOnInterface[#packetsOnInterface] = {dist = dist, packet = message}
  end
end

local function onNetworkSend(_, receiverMAC, senderMAC, _, dist, message)
  updateNetworkIndicator(receiverMAC, senderMAC)
  if(status == 1 and selectedInterface == senderMAC) then
    packetsOnInterface[#packetsOnInterface] = {dist = dist, packet = message}
  end
end

local function onNetworkBroadcast(_, receiverMAC, senderMAC, _, dist, message)
  updateNetworkIndicator(receiverMAC, senderMAC)
  if(status == 1 and selectedInterface == senderMAC) then
    packetsOnInterface[#packetsOnInterface] = {dist = dist, packet = message}
  end
end

gpu.setActiveBuffer(buffer)
drawEntryScreen()
writeToScreen()

local networkEvent = event.listen("multiport_message", onNetworkEvent)
local networkSend = event.listen("multiport_send", onNetworkSend)
local networkBroadcast = event.listen("multiport_broadcast", onNetworkBroadcast)

local running = true

local interruptedListener = event.listen("interrupted", function() running = false end)

while running do
  writeTopBar()
  writeToScreen()
  os.sleep(0.05)
end

for _, v in pairs(registeredButtons) do
  buttonLib.removeButton(v)
end

gpu.setActiveBuffer(0)

event.cancel(networkEvent)
event.cancel(networkSend)
event.cancel(networkBroadcast)
event.cancel(interruptedListener)

gpu.freeBuffer(buffer)