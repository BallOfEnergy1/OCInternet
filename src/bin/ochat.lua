
local udp = require("IP.protocols.UDP")
local tableutil = require("tableutil")
local term = require("term")
local util = require("IP.IPUtil")
local hyperPack = require("hyperpack")

local port = 555

local allClients = {}

local line = 1
local function displayMessage(message)
  term.gpu().setForeground(0xFFFFFF)
  term.gpu().setBackground(0x000000)
  local w, h = term.getViewport()
  if(line >= h - 2) then
    line = h - 2
    term.gpu().copy(1, 1, w, h - 2, 0, -1)
  end
  term.setCursor(1, line)
  term.clearLine()
  term.write(message)
  line = line + math.ceil(#message / w)
end

local function clearMessages()
  line = 1
  term.clear()
end

local function sendIndividualMessage(target, text)
  udp.send(target, port, text)
end

-- TODO: Multicasting to chat groups for performance?
local function sendMessage(text)
  for _, v in pairs(allClients) do
    sendIndividualMessage(v, text)
  end
end

-- TODO: Multicasting here too...
local function broadcastMessage(text)
  udp.broadcast(port, text)
end

local args, ops = require("shell").parse(...)

if(args[1] == "start-server") then
  if(not _G.OCHAT or not _G.OCHAT.isInitialized) then -- This basically allows for persistent "daemon" type running, if OChat were a foreground program then this would be where the program would run.
    print("Starting OChat server...")
    _G.OCHAT = {}
    _G.OCHAT.allClients = allClients -- sync em
    _G.OCHAT.callback = udp.UDPListen(port, function(packet) -- Create server callback.
      if(packet.data == 0xFF or packet.data == 0xFE or packet.data == 0xFD) then
        return -- Ignore P2P packets in server mode.
      end
      local packer = hyperPack:new():deserializeIntoClass(packet.data) -- Server-client format.
      local data = packer:popValue()
      local extra = packer:popValue() -- Mostly for username during connecting.
      if(data == 0xFC) then -- Server connect
        if(not tableutil.tableContainsItem(allClients, packet.header.senderIP)) then
          allClients[packet.header.senderIP] = {IP = packet.header.senderIP, user = extra}
        end
      elseif(data == 0xFB) then -- Server disconnect
        allClients[packet.header.senderIP] = nil
      else
        for i, v in pairs(allClients) do -- Send message to all clients; TODO: Filtering?
          if(v.IP ~= packet.header.senderIP) then -- Don't send back where it came from.
            packer = hyperPack:new()
            packer:pushValue(allClients[packet.header.senderIP].user)
            packer:pushValue(data)
            sendIndividualMessage(v.IP, packer:serialize())
          end
        end
      end
    end)
    --- Initialization token.
    _G.OCHAT.isInitialized = true
    print("OChat server started.")
  else
    print("OChat server already running.")
  end
  return
elseif(args[1] == "stop-server") then
  if(not _G.OCHAT or not _G.OCHAT.isInitialized) then
    print("No OChat server running.")
  else
    for _, v in pairs(_G.OCHAT.allClients) do
      sendIndividualMessage(v.IP, 0xFA)
    end
    udp.UDPIgnore(_G.OCHAT.callback)
    _G.OCHAT = nil
    print("Stopped OChat server.")
  end
  return
elseif(args[1]) then
  print("Unknown argument.")
  return
end

print("Select a mode argument from the following list:")
print("1 - Server mode")
print("2 - P2P mode")
local serverAddress, username, serverMode
if(io.read() == "1") then -- aaaaa
  print("Input server address to connect to.")
  serverAddress = io.read()
  if(not serverAddress) then
    return
  end
  serverAddress = util.fromUserFormat(serverAddress)
  print("Input username to use.")
  username = io.read()
  if(not username) then
    return
  end
  serverMode = true
  local ICMP = require("IP.protocols.ICMP")
  if(not ICMP.ping(serverAddress, 0, 3)) then
    print("Server did not respond.")
    return
  end
  local packer = hyperPack:new()
  packer:pushValue(0xFC)
  packer:pushValue(username)
  sendIndividualMessage(serverAddress, packer:serialize())
end

term.clear()

if(serverMode) then
  displayMessage("Connected to server at " .. util.toUserFormat(serverAddress) .. " with the username " .. username .. ".")
end

local systemMessages = false

local function receiveMessage(packet)
  if(serverMode) then
    if(packet.data == 0xFF or packet.data == 0xFE or packet.data == 0xFD) then
      return -- Ignore P2P packets in server mode.
    end
    if(packet.header.senderIP ~= serverAddress) then
      return -- Ignore packets not from the server.
    end
    if(packet.data == 0xFA) then -- Administrative disconnect.
      displayMessage("Server forcefully closed connection.")
      return
    end
    local packer = hyperPack:new():deserializeIntoClass(packet.data) -- Special formatting for users.
    local user = packer:popValue()
    local content = packer:popValue()
    displayMessage("[" .. user .. "]> " .. content)
    return
  end
  do -- Extremely similar to ARP or NRP, basically a primitive multicast/client finding algorithm.
    if(packet.data == 0xFF) then -- Broadcast from other client.
      if(packet.header.senderIP == _G.IP.primaryModem.clientIP) then -- this shouldn't be possible, but broadcasts are weird...
        return
      end
      sendIndividualMessage(packet.header.senderIP, 0xFE)
      if(not tableutil.tableContainsItem(allClients, packet.header.senderIP)) then
        table.insert(allClients, packet.header.senderIP)
        if(systemMessages) then
          displayMessage("System: Client " .. util.toUserFormat(packet.header.senderIP) .. " connected.")
        end
      end
      return
    elseif(packet.data == 0xFE) then -- Client response to broadcast.
      if(not tableutil.tableContainsItem(allClients, packet.header.senderIP)) then
        table.insert(allClients, packet.header.senderIP)
        if(systemMessages) then
          displayMessage("System: Client " .. util.toUserFormat(packet.header.senderIP) .. " connected.")
        end
      end
      return
    elseif(packet.data == 0xFD) then -- Client (graceful) disconnect.
      local contains, index = tableutil.tableContainsItem(allClients, packet.header.senderIP)
      if(contains) then
        table.remove(allClients, index)
        if(systemMessages) then
          displayMessage("System: Client " .. util.toUserFormat(packet.header.senderIP) .. " disconnected.")
        end
      end
      return
    end
  end
  displayMessage("[" .. util.toUserFormat(packet.header.senderIP) .. "]> " .. packet.data)
end

local callback = udp.UDPListen(port, receiveMessage)

if(not serverMode) then
  displayMessage("Finding clients...")
  broadcastMessage(0xFF) -- Broadcast to find other clients.
  
  os.sleep(1)
  displayMessage("Found " .. #allClients .. " clients on the network.")
  
  systemMessages = true
end

local event = require("event")

local w, h = term.getViewport()
term.setCursor(1, h - 1)
local bar = ""
for _ = 1, w do
  bar = bar .. "═"
end
term.write(bar)
term.setCursor(1, h)
term.write("OChat>")
term.setCursor(7, h)
term.setCursorBlink(true)

while not event.pull(0.05, "interrupted") do
  term.setCursor(1, h)
  term.write("OChat>")
  term.setCursor(7, h)
  local input = term.read(nil, false) -- no break
  term.setCursor(1, h)
  if(not input) then
    break
  end
  if(input:sub(0, 2) == "-/") then -- Terminal command.
    if(input == "-/Connected") then
      if(serverMode) then
        displayMessage("\nThis command is disabled while in server mode.")
      else
        displayMessage("\nConnected clients:")
        for i, v in pairs(allClients) do
          displayMessage("Client #" .. i .. ": " .. util.toUserFormat(v))
        end
      end
    elseif(input == "-/SystemMessages") then
      systemMessages = not systemMessages
      displayMessage("Server messages " .. (systemMessages and "enabled." or "disabled."))
    elseif(input == "-/Clear") then
      clearMessages()
    end
  elseif(input ~= "") then
    if(serverMode) then
      local packer = hyperPack:new()
      packer:pushValue(input)
      packer:pushValue("")
      sendIndividualMessage(serverAddress, packer:serialize())
    else
      sendMessage(input)
    end
    displayMessage("[You]>" .. input)
  end
  term.setCursor(1, h)
  term.clearLine()
  os.sleep(0)
end

print("\nExiting OChat...")

if(not serverMode) then
  broadcastMessage(0xFD)
else
  local packer = hyperPack:new()
  packer:pushValue(0xFB)
  packer:pushValue("")
  sendIndividualMessage(serverAddress, packer:serialize())
end

udp.UDPIgnore(callback)