local util = {}

local logutil = require("logutil")

function util.toHex(dec)
  local output = string.format("%x", dec)
  if(#output ~= 4) then
    repeat
      output = "0" .. output
    until (#output == 4)
  end
  return output
end

function util.toUserFormat(dec)
  local mask = 65535
  local endingString = ""
  for quartet = 0, 2 do
    endingString = ":" .. util.toHex((dec & mask) >> quartet * 16) .. endingString
    mask = mask << 16
  end
  endingString = util.toHex((dec & mask) >> 48) .. endingString
  return endingString
end

function util.fromUserFormat(IP)
  local firstQuartetIP  = IP:sub(1, 4)
  local secondQuartetIP = IP:sub(6, 9)
  local thirdQuartetIP  = IP:sub(11, 14)
  local fourthQuartetIP = IP:sub(16, 19)
  local parsedIP = tonumber(firstQuartetIP .. secondQuartetIP .. thirdQuartetIP .. fourthQuartetIP, 16)
  return parsedIP
end

-- Takes in dec representations!
function util.createIP(subnet, ID)
  return subnet | ID
end

function util.getSubnet(IP)
  return IP & _G.IP.subnetMask
end

function util.getID(IP)
  return IP & (~_G.IP.subnetMask)
end

local function setup()
  require("filesystem").makeDirectory("/var/ip") -- TODO get rid of this bs
  if(not _G.IP or not _G.IP.isInitialized) then
    _G.IP = {}
    do
      _G.IP.__packet       = {
        protocol = nil,
        senderPort = nil,
        targetPort = nil,
        targetMAC = nil,
        senderMAC = nil,
        senderIP = nil,
        targetIP = nil,
        data = nil
      }
      _G.IP.logger         = logutil.initLogger("IPv4.1", "/var/ip/ip.log")
      _G.IP.clientIP       = util.fromUserFormat("0123:4567:89ab:cdef")
      _G.IP.subnetMask     = util.fromUserFormat("FFFF:FF00:0000:0000")
      _G.IP.defaultGateway = util.fromUserFormat("0123:4500:0000:0001")
      _G.IP.MAC            = require("component").modem.address
    end
    require("IP.packetFrag").setup()
    require("IP.multiport").setup()
    _G.IP.isInitialized = true
  end
end

return {
  util      = util,
  setup     = setup
}