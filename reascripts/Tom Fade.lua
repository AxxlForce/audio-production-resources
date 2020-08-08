-- iterate through all selected items
for i=0, reaper.CountSelectedMediaItems(0)-1 do

  item = reaper.GetSelectedMediaItem(0, i)

  -- set item length
  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", 0.4)
  
  -- set fade in
  reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.01)
  reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", 1)
  
  -- set fade out
  reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.3)
  reaper.SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", 2)

end

reaper.UpdateArrange()

