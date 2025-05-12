
local util = require("IP.IPUtil")

print("Input host to connect to.")
local host = io.read()
if(not host) then
  return
end
host = util.fromUserFormat(host)
print("Input port to connect to.")
local port = io.read()
if(not port) then
  return
end
port = tonumber(port)

local tcp = require("IP.protocols.TCP")

tcp.setup()
local session = tcp.connect(host, port)

print("Session Info: ")
print(session.id)
print(session.status)
print(session.ackNum)
print(session.seqNum)

print("Sending test data... ")

session:send("Hello, world!")
session:send("Hello, world!")
session:send("Hello, world!")
session:send("Hello, world!")
session:send("Hello, world!")

print("Session Info: ")
print(session.id)
print(session.status)
print(session.ackNum)
print(session.seqNum)

if(session:getStatus() == "ESTABLISHED") then
  print("Finalizing connection... ")
  
  session:stop()
  
  print("Session Info: ")
  print(session.id)
  print(session.status)
  print(session.ackNum)
  print(session.seqNum)
end