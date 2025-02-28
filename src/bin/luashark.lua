
local component = require("component")
local gpu = component.gpu

local resX, resY = gpu.maxResolution()

if(resX < 80 or resY < 25) then
  print("T2 or T3 Screen/GPU required.")
end

local event = require("event")
local buttonLib = require("button")
local serialization = require("IP.serializationUnsafe")
local ipUtil = require("IP.IPUtil")
local api    = require("IP.netAPI")

gpu.setResolution(resX, resY)

local backgroundColor = 0xFFFFFF
local accentColor = 0x66B6FF
local redColor = gpu.maxDepth() == 8 and 0xFF0000 or 0x00
local greenColor = gpu.maxDepth() == 8 and 0x00FF00 or 0x00
local darkBackgroundColor = 0xDDDDDD
local textColor = 0x000000

local buffer = gpu.allocateBuffer(resX, resY)

local status = 0
local capturing = false
local selectedInterface
local packetsOnInterface
local scroll = 0

local showExtendedInfo = resY > 25

local function makeSize(text, size)
  local stringifiedText = tostring(text)
  if(#stringifiedText < size) then
    for _ = 1, size - #stringifiedText do
      stringifiedText = stringifiedText .. " "
    end
  end
  return stringifiedText
end

local function writeTopBar()
  gpu.setBackground(accentColor)
  gpu.fill(1, 1, resX, 1, " ")
  gpu.set(2, 1, "LuaShark Network Analyzer")
  local totalRAM = require("computer").totalMemory()
  local usedRAM = totalRAM - require("computer").freeMemory()
  gpu.set(resX - #"RAM Used: ..../....KB", 1, "RAM Used: " .. math.floor(usedRAM/1000) .. "/" .. math.floor(totalRAM/1000) .. "KB")
  gpu.setBackground(backgroundColor)
end

local function writeBottomBar()
  gpu.setBackground(accentColor)
  gpu.fill(1, resY, resX, 1, " ")
  if(capturing) then
    gpu.setForeground(greenColor)
    gpu.set(2, resY, "Capturing")
  else
    gpu.setForeground(redColor)
    gpu.set(2, resY, "Stopped")
  end
  gpu.setForeground(textColor)
  gpu.setBackground(backgroundColor)
end

local registeredButtons = {}

local interfaceStartTime

do
  table.insert(registeredButtons, buttonLib.makeButton(1, 6, resX, 1, function()
    selectedInterface = 0
    status = 1
    packetsOnInterface = {}
    interfaceStartTime = require("computer").uptime()
  end, function()
    return status == 0
  end))
  
  local index = 0
  for i in pairs(_G.IP.modems) do
    table.insert(registeredButtons, buttonLib.makeButton(1, 7 + index, resX, 1, function()
      selectedInterface = i
      status = 1
      packetsOnInterface = {}
      interfaceStartTime = require("computer").uptime()
    end, function()
      return status == 0
    end))
    index = index + 1
  end
  table.insert(registeredButtons, buttonLib.makeButton(1, 1, resX, 1, function()
    selectedInterface = nil
    status = 0
    packetsOnInterface = nil
    interfaceStartTime = nil
    capturing = false
  end, function()
    return status == 1
  end))
  table.insert(registeredButtons, buttonLib.makeButton(1, 2, 15, 1, function()
    if(capturing == false) then -- Will be true.
      packetsOnInterface = {} -- Clear capture.
    end
    capturing = not capturing
  end, function()
    return status == 1
  end))
end

local function drawEntryScreen()
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

local function inferProtocolFromPacket(packet)
  if(packet.header.protocol == 1) then
    return "ICMP"
  elseif(packet.header.protocol == 2) then
    return "ARP"
  elseif(packet.header.protocol == 3) then
    --unassigned somehow
    return "Unk."
  elseif(packet.header.protocol == 4) then
    if(packet.udpProto == 1) then
      return "DHCP"
    end
    return "UDP"
  elseif(packet.header.protocol == 5) then
    return "TCP"
  end
  return "Unk."
end

local function inferInfoFromPacket(packet)
  local protocol = inferProtocolFromPacket(packet)
  if(protocol == "ICMP") then
    if(packet.data.type == 0x1A) then
      return "Echo (ping) request", 0xCCB6FF
    elseif(packet.data.type == 0x00) then
      return "Echo (ping) reply", 0xCCB6FF
    end
  elseif(protocol == "ARP") then
    if(packet.header.targetIP == ipUtil.fromUserFormat(_G.IP.constants.broadcastIP)) then
      return "Who has " .. ipUtil.toUserFormat(packet.data) .. "? Tell " .. ipUtil.toUserFormat(packet.header.senderIP), 0xFFFFC0
    else
      return ipUtil.toUserFormat(packet.header.senderIP) .. " is at " .. packet.data, 0xFFFFC0
    end
  elseif(protocol == "UDP") then
    return packet.header.senderPort .. " → " .. packet.header.targetPort .. " " .. "Len=" .. (packet.udpLength or "Unk."), 0xCCFFFF
  elseif(protocol == "DHCP") then
    if(packet.data == 0x10) then
      return "DHCP Release", 0xCCFFFF
    elseif(packet.data == 0x11) then
      return "DHCP Flush", 0xCCFFFF
    elseif(packet.header.targetPort == 67) then
      return "DHCP Request", 0xCCFFFF
    elseif(packet.header.targetPort == 68) then
      return "DHCP Response", 0xCCFFFF
    end
  elseif(protocol == "TCP") then
    return "", 0xCCFFC0
  elseif(protocol == "Unk.") then
    return "", 0x992400
  end
end

local function drawInterfaceScreen()
  gpu.setBackground(darkBackgroundColor)
  gpu.set(2, 2, (capturing and "Stop Capturing" or "Start Capturing"))
  gpu.setBackground(backgroundColor)
  gpu.set(2, 3, "No.    Time      Source               Destination          Protocol  Length   Info")
  scroll = math.max(0, #packetsOnInterface - resY - 4)
  for i, v in pairs(packetsOnInterface) do
    if(i > scroll) then
      if(showExtendedInfo) then
        local text, color = inferInfoFromPacket(v.packet)
        gpu.setBackground(color)
        gpu.fill(1, 4 + i - scroll - 1, resX, 1, " ")
        gpu.set(2, 4 + i - scroll - 1,
          makeSize(i, 6) .. " " ..
            makeSize(math.floor(v.time*100)/100, 9) .. " " ..
            makeSize(ipUtil.toUserFormat(v.packet.header.senderIP) or "nil", 19) .. "  " ..
            makeSize(ipUtil.toUserFormat(v.packet.header.targetIP) or "nil", 19) .. "  " ..
            makeSize(inferProtocolFromPacket(v.packet), 8) .. "  " ..
            makeSize(#serialization.serialize(v.packet), 6) .. "   " .. -- TODO: Change to hyperpack!
            text
        )
      else
        gpu.set(2, 4 + i - scroll - 1,
          makeSize(i, 6) .. " " ..
            makeSize(math.floor(v.time*100)/100, 9) .. " " ..
            makeSize(ipUtil.toUserFormat(v.packet.header.senderIP) or "nil", 19) .. "  " ..
            makeSize(ipUtil.toUserFormat(v.packet.header.targetIP) or "nil", 19) .. "  " ..
            makeSize(inferProtocolFromPacket(v.packet), 8) .. "  " ..
            makeSize(#serialization.serialize(v.packet), 6) -- TODO: Change to hyperpack!
        )
      end
    end
  end
  gpu.setBackground(backgroundColor)
end

local function writeToScreen()
  gpu.bitblt()
end


local function updateNetworkIndicator(receiverMAC, senderMAC)
  if(status == 0) then -- In entry screen.
    local index = 1
    if(receiverMAC ~= senderMAC) then
      for i in pairs(_G.IP.modems) do
        if(i == receiverMAC or i == senderMAC) then
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

local function onNetworkEvent(message, dist)
  updateNetworkIndicator(message.header.receiverMAC, message.header.senderMAC)
  if(status == 1 and selectedInterface == message.header.receiverMAC and capturing) then
    packetsOnInterface[#packetsOnInterface + 1] = {dist = dist, packet = message, time = require("computer").uptime() - interfaceStartTime}
  end
end

local function onNetworkSent(message)
  updateNetworkIndicator(message.header.receiverMAC, message.header.senderMAC)
  if(status == 1 and selectedInterface == message.header.senderMAC and capturing) then
    message = serialization.unserialize(message)
    packetsOnInterface[#packetsOnInterface + 1] = {dist = 0, packet = message, time = require("computer").uptime() - interfaceStartTime}
  end
end

local function onNetworkBroadcast(message)
  updateNetworkIndicator(message.header.receiverMAC, message.header.senderMAC)
  if(status == 1 and selectedInterface == message.header.senderMAC and capturing) then
    packetsOnInterface[#packetsOnInterface + 1] = {dist = 0, packet = message, time = require("computer").uptime() - interfaceStartTime}
  end
end

gpu.setActiveBuffer(buffer)
gpu.setForeground(textColor)
gpu.setBackground(backgroundColor)
gpu.fill(1, 1, resX, resY, " ")
writeTopBar()
drawEntryScreen()
writeToScreen()

local networkEvent = api.registerReceivingCallback(onNetworkEvent)
local networkSent = api.registerUnicastSendingCallback(onNetworkSent)
local networkBroadcast = api.registerBroadcastSendingCallback(onNetworkBroadcast)

local running = true

local interruptedListener = event.listen("interrupted", function() running = false end)

buttonLib.start()

while running do
  gpu.setForeground(textColor)
  gpu.setBackground(backgroundColor)
  gpu.fill(1, 1, resX, resY, " ")
  writeTopBar()
  writeBottomBar()
  if(status == 1) then
    drawInterfaceScreen()
  else
    drawEntryScreen()
  end
  writeToScreen()
  os.sleep(0.05)
end

for _, v in pairs(registeredButtons) do
  buttonLib.removeButton(v)
end

buttonLib.stop()

gpu.setActiveBuffer(0)

api.unregisterCallback(networkEvent)
api.unregisterCallback(networkSent)
api.unregisterCallback(networkBroadcast)
event.cancel(interruptedListener)

gpu.freeBuffer(buffer)

require("term").clear()