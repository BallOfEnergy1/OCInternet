
--- General purpose table utility library.
local tableUtil = {}

--- Check if a table contains an item via iteration.
---
--- @param targetTable table Table to check.
--- @param item any Item to check for in table.
--- @return boolean, number If item was found in the table. If it was found, also returns the index of the item.
function tableUtil.tableContainsItem(targetTable, item)
  for i, v in pairs(targetTable) do
    if(v == item) then
      return true, i
    end
  end
  return false
end

return tableUtil