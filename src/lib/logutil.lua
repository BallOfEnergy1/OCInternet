--[[
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
]]--

-- Logging utility for OC.

local component = require("component")
local event = require("event")

local version = "1.0.1"

local runningLoggers = {}

local function getTimestamp(name)
  if(runningLoggers[name].hasOcelot) then
    return os.date("%Y-%m-%d, %H:%M:%S", runningLoggers[name].ocelotProxy.getTimestamp() / 1000)
  else
    return require("computer").uptime() .. " (Uptime)"
  end
end

local function checkOpenHandles()
  for _, v in ipairs(runningLoggers) do
    if(v.closeTimer ~= 0) then
      if(require("computer").uptime() > v.closeTimer) then
        v.closeTimer = 0
        v.handle:close()
        v.handle = nil
      end
    end
  end
end

local function log(name, format, ocelot, ...)
  local handle = runningLoggers[name].handle or io.open(runningLoggers[name].filePath, "a")
  if(runningLoggers[name].hasOcelot and (ocelot or ocelot == nil)) then
    runningLoggers[name].ocelotProxy.log(string.format("[%s]|[%s]: " .. format .. "\n", getTimestamp(name), name, ...))
  end
  if(not ocelot --[[ technically this also will be true for nil... ]]) then
    handle:write(string.format("[%s]|[%s]: " .. format .. "\n", getTimestamp(name), name, ...))
  end
  runningLoggers[name].closeTimer = require("computer").uptime() + 1
end

-- Special routine to check for an ocelot card/block.
local function checkForOcelot()
  if(component.isAvailable("ocelot")) then
    return true, component.getPrimary("ocelot")
  end
  return false
end

local function checkComponents(type, name, name2)
  if(type == "component_available" and name == "ocelot") then
    for _, v in pairs(runningLoggers) do
      v.hasOcelot = true
      v.ocelotProxy = component.getPrimary("ocelot")
      log(v.name, "Ocelot debugger connected at %s, integration enabled.", false, v.ocelotProxy.address)
      log(v.name, "Computer at %s connected via `logutil` version %s with name '%s'.", true, component.computer.address, version, v.name)
    end
  elseif(type == "component_removed" and name2 == "ocelot") then
    for _, v in pairs(runningLoggers) do
      if(component.isAvailable("ocelot") and component.isAvailable("ocelot").address ~= name--[[ for the address ]]) then
        v.ocelotProxy = component.getPrimary("ocelot")
        log(v.name, "Ocelot component swapped to %s.", false, v.ocelotProxy.address)
        log(v.name, "Computer at %s connected via `logutil` version %s with name '%s'.", true, component.computer.address, version, v.name)
      else
        v.hasOcelot = false
        v.ocelotProxy = nil
        log(v.name, "Ocelot component disconnected.", false)
      end
    end
  end
end

--- Grabs a table containing all running loggers.
--- @return table Table containing all loggers.
local function getRunningLoggers()
  return runningLoggers
end

local isInitialized = false;

local function initLoggerInternal(name, filePath)
  if(runningLoggers[name] ~= nil) then
    error(string.format("Logger already running with the same name (%s).", name))
  end
  if(require("filesystem").exists(filePath)) then
    require("filesystem").remove(filePath)
  end
  runningLoggers[name] = {
    name = name,
    filePath = filePath,
    closeTimer = require("computer").uptime() + 1,
    handle = io.open(filePath, "a")
  }
  if(not isInitialized) then
    log(name, "Logutil version %s initialized at %s.", false, version, runningLoggers[name].filePath)
    log(name, "Running ocelot check...", false)
    local hasOcelot, ocelotProxy = checkForOcelot()
    runningLoggers[name].hasOcelot = hasOcelot
    if(hasOcelot) then
      runningLoggers[name].ocelotProxy = ocelotProxy
      log(name, "Ocelot debugger found at %s, integration enabled.", false, ocelotProxy.address)
      log(name, "Computer at %s connected via `logutil` version %s with name '%s'.", true, component.computer.address, version, name)
    else
      log(name, "Ocelot not found, skipping.", false)
    end
  else
    log(name, "Initializing logger with name %s...", false, name)
    local hasOcelot, ocelotProxy = checkForOcelot()
    log(name, "Running ocelot check...", false)
    runningLoggers[name].hasOcelot = hasOcelot
    if(hasOcelot) then
      runningLoggers[name].ocelotProxy = ocelotProxy
      log(name, "Ocelot debugger found at %s, integration enabled.", false, ocelotProxy.address)
      log(name, "Computer at %s connected via `logutil` version %s with name '%s'.", true, component.computer.address, version, name)
    else
      log(name, "Ocelot not found, skipping.", false)
    end
  end
  log(name, "Logger with name %s started at file.", false, name)
  isInitialized = true;
  
  local isStopped = false;
  
  return {
    write = function(content)
      if(isStopped) then
        error("Attempted to write to a closed log handle.")
      end
      log(name, "%s", nil, tostring(content))
    end,
    closeLog = function()
      runningLoggers[name] = nil
      isStopped = true
    end,
    readFromConsole = function(timeout)
      if(isStopped) then
        error("Attempted to read from a closed log handle.")
      end
      if(not runningLoggers[name].hasOcelot) then
        return nil, "No ocelot component."
      end
      local _, _, content = event.pull(timeout or math.huge, "ocelot_message") -- Get message content.
      log(name, "Content read from ocelot console; ocelot address: %s; content: %s", false, runningLoggers[name].ocelotProxy.address, tostring(content))
      return tostring(content)
    end,
    isStopped = isStopped;
  }
end

local defaultLogPath = "/tmp/logutil.log"

--- Initializes a logger to a directory.
--- @param name string Name of the logger.
--- @param filePath string File to initialize logger to (global).
--- @return table Handle for the logger.
local function initLogger(name, filePath)
  -- Set up the primary logutil logger.
  -- /etc/logutil.log is the default log path.
  if(not isInitialized) then
    initLoggerInternal("logutil", defaultLogPath)
    log("logutil", "Starting event listeners... (1/2)")
    event.ignore("component_available", checkComponents)
    event.listen("component_available", checkComponents)
    log("logutil", "Starting event listeners... (2/2)")
    event.ignore("component_removed", checkComponents)
    event.listen("component_removed", checkComponents)
    log("logutil", "Starting event timer... (1/1)")
    event.timer(1, checkOpenHandles, math.huge)
  end
  return initLoggerInternal(name, filePath or defaultLogPath)
end

return {
  --- Initializes a logger to a directory.
  --- @param name string Name of the logger.
  --- @param filePath string File to initialize logger to (global).
  --- @return table Handle for the logger.
  initLogger = initLogger,
  --- Grabs a table containing all running loggers.
  --- @return table Table containing all loggers.
  getRunningLoggers = getRunningLoggers
}