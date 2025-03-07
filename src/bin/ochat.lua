
local udp = require("IP.protocols.UDP")
local tableutil = require("tableutil")
local term = require("term")
local util = require("IP.IPUtil")

local port = 555

local allClients = {}
local inputBuffer = ""
local systemMessages = false

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

local function receiveMessage(packet)
  do -- Extremely similar to ARP or NRP, basically a primitive multicast/client finding algorithm.
    if(packet.data == 0xFF) then -- Broadcast from other client.
      if(packet.header.senderIP == _G.IP.primaryModem.clientIP) then -- this shouldn't be possible, but broadcasts are weird...
        return
      end
      sendIndividualMessage(packet.header.senderIP, 0xFE)
      if(not tableutil.tableContainsItem(allClients, packet.header.senderIP)) then
        table.insert(allClients, packet.header.senderIP)
        if(systemMessages) then
          local _, y = term.getCursor()
          term.clearLine()
          term.write("System: Client " .. util.toUserFormat(packet.header.senderIP) .. " connected.")
          term.setCursor(1, y + 1)
          term.clearLine()
          term.setCursor(1, y + 2)
          term.write("OChat>" .. inputBuffer)
          term.setCursor(#("OChat>" .. inputBuffer), y + 2)
        end
      end
      return
    elseif(packet.data == 0xFE) then -- Client response to broadcast.
      if(not tableutil.tableContainsItem(allClients, packet.header.senderIP)) then
        table.insert(allClients, packet.header.senderIP)
        if(systemMessages) then
          local _, y = term.getCursor()
          term.clearLine()
          term.write("System: Client " .. util.toUserFormat(packet.header.senderIP) .. " connected.")
          term.setCursor(1, y + 1)
          term.clearLine()
          term.setCursor(1, y + 2)
          term.write("OChat>" .. inputBuffer)
          term.setCursor(#("OChat>" .. inputBuffer), y + 2)
        end
      end
      return
    elseif(packet.data == 0xFD) then -- Client (graceful) disconnect.
      local contains, index = tableutil.tableContainsItem(allClients, packet.header.senderIP)
      if(contains) then
        table.remove(allClients, index)
        if(systemMessages) then
          local _, y = term.getCursor()
          term.clearLine()
          term.write("System: Client " .. util.toUserFormat(packet.header.senderIP) .. " disconnected.")
          term.setCursor(1, y + 1)
          term.clearLine()
          term.setCursor(1, y + 2)
          term.write("OChat>" .. inputBuffer)
          term.setCursor(#("OChat>" .. inputBuffer), y + 2)
        end
      end
      return
    end
  end
  local _, y = term.getCursor()
  term.clearLine()
  term.write("[" .. util.toUserFormat(packet.header.senderIP) .. "]> " .. packet.data)
  term.setCursor(1, y + 1)
  term.clearLine()
  term.setCursor(1, y + 2)
  term.write("OChat>" .. inputBuffer)
  term.setCursor(#("OChat>" .. inputBuffer), y + 2)
end

local callback = udp.UDPListen(port, receiveMessage)

print("Finding clients...")
broadcastMessage(0xFF) -- Broadcast to find other clients.

os.sleep(1)
print("Found " .. #allClients .. " clients on the network.")

systemMessages = true

local event = require("event")
local unicode = require("unicode")

local running = true

local function onKeyDown(_, _, key, code)
  local _, y = term.getCursor()
  if key == 0 then
    return
  elseif key == 3 then
    running = false
    return false
  elseif code == 28 then -- Enter key.
    if(inputBuffer:sub(0, 2) == "-/") then -- Terminal command.
      if(inputBuffer == "-/Connected") then
        print("\nConnected clients:")
        for i, v in pairs(allClients) do
          print("Client #" .. i .. ": " .. util.toUserFormat(v))
        end
        _, y = term.getCursor()
        term.setCursor(1, y + 1)
      elseif(inputBuffer == "-/SystemMessages") then
        systemMessages = not systemMessages
        _, y = term.getCursor()
        term.setCursor(1, y + 1)
      elseif(inputBuffer == "-/Clear") then
        term.clear()
      end
    elseif(inputBuffer ~= "") then
      sendMessage(inputBuffer)
      _, y = term.getCursor()
      term.setCursor(1, y + 1)
    end
    inputBuffer = ""
  elseif code == 14 then -- Backspace key.
    if inputBuffer ~= "" then
      inputBuffer = inputBuffer:sub(1, #inputBuffer - 1)
    end
  else
    inputBuffer = inputBuffer .. unicode.char(key)
  end
  _, y = term.getCursor()
  term.clearLine()
  term.write("OChat>" .. inputBuffer)
  term.setCursor(#("OChat>" .. inputBuffer), y)
end

local listener = event.listen("key_down", onKeyDown)

local _, y = term.getCursor()
term.setCursor(1, y + 1)
term.write("OChat>")
term.setCursor(7, y + 1)
term.setCursorBlink(true)

while not event.pull(0.05, "interrupted") and running do
  os.sleep(0)
end

print("\nExiting OChat...")

broadcastMessage(0xFD)

event.cancel(listener)

udp.UDPIgnore(callback)