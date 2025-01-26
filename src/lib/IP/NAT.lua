
local nat = {}

function nat.setup()
  if(not _G.NAT or not _G.NAT.isInitialized) then
    _G.NAT = {}
    do
      _G.NAT.connections = {}
    end
    _G.NAT.isInitialized = true
  end
end

function nat.mapToExternal()

end

function nat.mapToInternal()

end

function nat.updateConnection()

end

return nat