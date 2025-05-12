
local util = require("IP.IPUtil")
local tcp = require("IP.protocols.TCP")

local args, ops = require("shell").parse(...)

local connected = false
--- @type Session
local session

while true do
  io.write("ftp> ")
  
  local input = string.lower(io.read())
  
  if(not input or input == "bye" or input == "quit") then
    if(session) then
      session:stop()
      print("Disconnected.")
    end
    return
  elseif(input == "stat") then
    if(not connected) then
      print("Not connected.")
    end
  elseif(input == "open") then
    if(not connected) then
      io.write("To ")
      input = util.fromUserFormat(io.read())
      session = tcp.connect(input, 21)
      if(session:getStatus() == "ESTABLISHED") then
        print("Connected to " .. util.toUserFormat(input))
      end
    end
  else
    print("Invalid command.")
  end
end