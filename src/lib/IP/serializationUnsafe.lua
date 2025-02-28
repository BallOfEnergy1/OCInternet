
--- Ok so here's the problem here...
--- The default recursive serialization library is
---
--- 1. Slow
--- 2. CPU intensive
---
--- Because of this, it's very recommended to NEVER use tables in network sending unless absolutely required.
--- To remind myself not to be an idiot, I am labeling this under a new class, as well as changing any existing definitions in any protocols to use this serialization
--- if the default is used.
--- @class SerializationUnsafe
local unsafeSerialization = {}

local serialization = require("serialization")

function unsafeSerialization.serialize(...)
  if(not _G.SERIAL.deprecatedNoWarn) then
    _G.IP.logger.write("Deprecated serialization library used, this can lead to excessive CPU usage.")
  end
  return serialization.serialize(...)
end

function unsafeSerialization.unserialize(...)
  if(not _G.SERIAL.deprecatedNoWarn) then
    _G.IP.logger.write("Deprecated serialization library used, this can lead to excessive CPU usage.")
  end
  return serialization.unserialize(...)
end

function unsafeSerialization.setup(config)
  if(not _G.SERIAL or not _G.SERIAL.isInitialized) then
    _G.SERIAL = {}
    _G.SERIAL.deprecatedNoWarn = config.SERIAL.deprecatedNoWarn
    _G.SERIAL.isInitialized = true
  end
end

return unsafeSerialization
