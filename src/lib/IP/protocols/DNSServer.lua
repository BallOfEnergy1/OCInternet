
local DNS = require("IP.protocols.DNS")
local util = require("IP.IPUtil")
local tableUtil = require("tableutil")
local udp = require("IP.protocols.UDP")
local hyperPack = require("hyperpack")
local fs = require("filesystem")

local RRClass = require("IP.classes.DNS.RRClass")

local dnsPort = 53
local dnsUDPProtocol = 2

local dnsServer = {}

local function onDNSMessage(receivedPacket)

end

local function checkRRDir()
  if(not fs.exists(_G.DNS.recordLocation) or not fs.isDirectory(_G.DNS.recordLocation)) then
    fs.remove(_G.DNS.recordLocation) -- Remove in-case it's a file.
    fs.makeDirectory(_G.DNS.recordLocation) -- Remake (or make for the first time) as a directory.
  end
  
end

local function getRR(type, domain)
  checkRRDir()

end

local function writeRRToDisk(RR)
  checkRRDir()
  ---@type RR
  local record = RR
  local serializedData = record:serialize()
  local RRFile
  do
    local handle = io.open(_G.DNS.recordLocation, "r")
    RRFile = handle:read("*a")
    handle:close()
  end
  ::reset::
  if(_G.DNS.recordCompression) then
    -- Initiate compression
    if(_G.DNS.recordCompressionMode == "OCZ") then
      local ocz = require("oczlib")
      if(not RRFile:sub(1, 3) == "OCZ") then
        serializedData = ocz.compress(RRFile .. serializedData)
      else
        serializedData = ocz.compress(ocz.decompress(RRFile) .. serializedData)
      end
    elseif(_G.DNS.recordCompressionMode == "DEFLATE") then
      if(not require("component").isAvailable("data")) then
        _G.IP.logger.write("DEFLATE/INFLATE compression unavailable; no data card available.")
        _G.IP.logger.write("Disabling compression as a fallback...")
        _G.DNS.recordCompression = false
        goto reset
      end
      local datacard = require("component").data
      if(not RRFile:sub(1, 7) == "DEFLATE") then
        serializedData = datacard.deflate(RRFile .. serializedData)
      else
        serializedData = datacard.deflate(datacard.inflate(RRFile) .. serializedData)
      end
    elseif(_G.DNS.recordCompressionMode == "LZW") then
      local lzw = require("lualzw")
      if(not RRFile:sub(1, 3) == "LZW") then
        serializedData = lzw.compress(RRFile .. serializedData)
      else
        serializedData = lzw.compress(lzw.decompress(RRFile) .. serializedData)
      end
    end
  else
    if(not RRFile:sub(1, 3) == "Un") then
      _G.IP.logger.write("Incompatible DNS RR file found, creating emergency RR file...")
      _G.IP.logger.write("Reason: Attempted to read a compressed DNS entry with compression disabled.")
      _G.DNS.recordLocation = fs.path(_G.DNS.recordLocation) .. "/emergency.RR"
      local handle = io.open(_G.DNS.recordLocation, "w")
      handle:write("Uncompressed DNS Records; Emergency file. These files are made when the original DNS file cannot be recovered, see logs for more details.")
      handle:write(serializedData)
      handle:close()
      _G.IP.logger.write("Created emergency RR file, adding new records to " .. _G.DNS.recordLocation .. ".")
      return
    end
  end
  do
    local handle = io.open(_G.DNS.recordLocation, "w")
    handle:write(serializedData)
    handle:close()
  end
end

function dnsServer.createRR(type, name, ttl, ...)
  local RR = RRClass:new(name, type, ttl, nil)
  if(type == 1 or type == 5 or type == 16 or type == 17) then -- AA, CNAME, TXT, or RP Record; One value
    RR.data = ...
  elseif(type == 13) then -- HINFO Record; Two values
    local args = table.pack(...)
    RR.data = {
      CPU = args[1],
      OS = args[2]
    }
  end
  writeRRToDisk(RR)
  return RR
end

function dnsServer.setup(config)
  DNS.setup(config)
  if(not _G.DNS or not _G.DNS.isInitialized) then
    _G.DNS = {}
    _G.DNS.recordLocation = config.DNSServer.RRLocation .. "/primary.RR"
    _G.DNS.recordCompression = config.DNSServer.compression
    _G.DNS.recordCompressionMode = config.DNSServer.compressionMode
    _G.DNS.serverCallback = udp.UDPListen(dnsPort, function(packet)
      if(packet.udpProto == dnsUDPProtocol) then
        onDNSMessage(packet)
      end
    end)
    _G.DNS.isInitialized = true
  end
end