local event = require("event")

local isInitialized = false
local buttonTable = {}

local function makeButton(x, y, w, h, callback, condition, stopAfterExecuting)
  local uuid = require("uuid").next()
  buttonTable[uuid] = {i=#buttonTable+1, x=x, y=y, width=w, height=h, callback=callback, condition=condition, stopAfterExecuting=stopAfterExecuting}
  return uuid
end

local function removeButton(uuid)
  buttonTable[uuid] = nil
end

local function onClick(_, _, x, y, button)
  -- precompile the buttonTable
  local sortedButtonTable = {}
  for i, v in pairs(buttonTable) do
    table.insert(sortedButtonTable, v.i, buttonTable[i])
  end
  for _, v in pairs(sortedButtonTable) do
    if (x >= v.x and x < v.x + v.width) and (y >= v.y and y < v.y + v.height) then
      if v.condition == nil or v.condition(x, y, button) then
        v.callback(x, y, button)
        if v.stopAfterExecuting then break; end
      end
    end
  end
end

local function simulateClick(x, y, button)
  onClick(nil, nil, x, y, button)
end

local function start()
  if(isInitialized) then
    return false
  end
  event.listen("touch", onClick)
  return true
end

local function stop()
  if(isInitialized) then
    return false
  end
  event.ignore("touch", onClick)
  return true
end

return {makeButton = makeButton, removeButton = removeButton, start = start, stop = stop, simulateClick = simulateClick}