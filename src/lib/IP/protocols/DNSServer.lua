
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

local function makeSizeNumber(text, size)
  local stringifiedText = tostring(text)
  if(#stringifiedText < size) then
    for _ = 1, size - #stringifiedText do
      stringifiedText = stringifiedText .. "0"
    end
  end
  return stringifiedText
end

local function cutOutHeader(text)
  local start = text:find("\n")
  if(start == nil) then
    return text
  end
  return text:sub(start + 1)
end

local function checkRRDir()
  if(not fs.exists(_G.DNS.recordLocation) or fs.isDirectory(_G.DNS.recordLocation)) then
    fs.remove(_G.DNS.recordLocation) -- Remove in-case it's a file.
    fs.makeDirectory(fs.path(_G.DNS.recordLocation)) -- Remake (or make for the first time) as a directory.
    io.open(_G.DNS.recordLocation, "w"):close()
  end
end

local function readAllRRs()
  checkRRDir()
  local RRFile
  do
    local handle = io.open(_G.DNS.recordLocation, "r")
    RRFile = handle:read("*a")
    handle:close()
  end
  if(RRFile == nil or RRFile == "") then
    return nil
  end
  local records = {}
  if(RRFile:sub(1, 2, "Un")) then
    RRFile = cutOutHeader(RRFile)
  else
    if(RRFile:sub(1, 3) == "OCZ") then
      RRFile = cutOutHeader(RRFile)
      local ocz = require("oczlib")
      RRFile = ocz.decompress(RRFile)
    elseif(RRFile:sub(1, 7) == "DEFLATE") then
      RRFile = cutOutHeader(RRFile)
      if(not require("component").isAvailable("data")) then
        _G.IP.logger.write("DEFLATE/INFLATE compression unavailable; no data card available.")
        _G.IP.logger.write("Unable to read DNS records from " .. _G.DNS.recordLocation .. ".")
        return nil
      end
      local datacard = require("component").data
      RRFile = datacard.inflate(RRFile)
    elseif(RRFile:sub(1, 3) == "LZW") then
      RRFile = cutOutHeader(RRFile)
      local lzw = require("lualzw")
      RRFile = lzw.decompress(RRFile)
    end
  end
  while #RRFile > 0 do
    local nextLength = tonumber(RRFile:sub(1, 3))
    RRFile = RRFile:sub(4)
    table.insert(records, RRClass:new():deserialize(RRFile:sub(1, nextLength)))
    RRFile = RRFile:sub(nextLength + 1)
  end
  return records
end

local function getRR(name, type)
  checkRRDir()
  local allRecords = readAllRRs()
  if(allRecords == nil) then
    return nil, "Record not found."
  end
  local returns = {}
  for _, record in pairs(allRecords) do
    if(type == "*") then
      if(record.name == name) then
        table.insert(returns, record)
      end
    elseif(type == record.type and name == record.name) then
      return record
    end
  end
  if(#returns > 0) then
    return returns
  end
  return nil, "Record not found."
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
        serializedData = ocz.compress(cutOutHeader(RRFile) .. makeSizeNumber(#serializedData, 3) .. serializedData)
      else
        serializedData = ocz.compress(ocz.decompress(cutOutHeader(RRFile)) .. makeSizeNumber(#serializedData, 3) .. serializedData)
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
        serializedData = datacard.deflate(cutOutHeader(RRFile) .. makeSizeNumber(#serializedData, 3) .. serializedData)
      else
        serializedData = datacard.deflate(datacard.inflate(cutOutHeader(RRFile)) .. makeSizeNumber(#serializedData, 3) .. serializedData)
      end
    elseif(_G.DNS.recordCompressionMode == "LZW") then
      local lzw = require("lualzw")
      if(not RRFile:sub(1, 3) == "LZW") then
        serializedData = lzw.compress(cutOutHeader(RRFile) .. makeSizeNumber(#serializedData, 3) .. serializedData)
      else
        serializedData = lzw.compress(lzw.decompress(cutOutHeader(RRFile)) .. makeSizeNumber(#serializedData, 3) .. serializedData)
      end
    end
  else
    if(not RRFile:sub(1, 2) == "Un") then
      _G.IP.logger.write("Incompatible DNS RR file found, creating emergency RR file...")
      _G.IP.logger.write("Reason: Attempted to read a compressed DNS entry with compression disabled.")
      _G.DNS.recordLocation = fs.path(_G.DNS.recordLocation) .. "/emergency.RR"
      local handle = io.open(_G.DNS.recordLocation, "w")
      handle:write("Uncompressed DNS Records; Emergency file. These files are made when the original DNS file cannot be recovered, see logs for more details.\n")
      handle:write(makeSizeNumber(#serializedData, 3) .. serializedData)
      handle:close()
      _G.IP.logger.write("Created emergency RR file, adding new records to " .. _G.DNS.recordLocation .. ".")
      return
    end
  end
  do
    local handle = io.open(_G.DNS.recordLocation, "w")
    handle:write(_G.DNS.recordCompression and _G.DNS.recordCompressionMode or "Uncompressed" .. " DNS Records.\n")
    handle:write(cutOutHeader(RRFile) .. makeSizeNumber(#serializedData, 3) .. serializedData)
    handle:close()
  end
end

function dnsServer.readAllRRs()
  return readAllRRs()
end

function dnsServer.readRR(name, type)
  return getRR(name, type)
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
    _G.DNS.serverIsInitialized = true
  end
end

return dnsServer