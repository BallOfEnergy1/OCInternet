
local tableUtil = {}

function tableUtil.tableContainsItem(table1, item)
  for i, v in pairs(table1) do
    if(v == item) then
      return true, i
    end
  end
  return false
end

return tableUtil