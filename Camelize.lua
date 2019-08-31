local function camelize_(label) 
  if string.len(label) == 0 then
    return label
  end

  local words = {}
  for w in string.gmatch(label,"(%w+)_*") do
    table.insert(words, w)
  end
   -- single word with first character already lowercase, return untouched
  if #words == 1 then 
    local ch = string.sub(words[1],1,1)
    if ch == string.lower(ch) then
      return label
    end
  end

  local result = string.lower(words[1])
  for n=2,#words do
    result = result .. string.upper(string.sub(words[n],1,1)) .. string.lower(string.sub(words[n],2,-1))
  end
  return result
end

local function prepended_(prepend, label) 
  label = camelize_(label)
  return prepend .. string.upper(string.sub(label,1,1)) .. string.sub(label,2,-1)
end

return {
  camelize = camelize_,
  prepended = prepended_,
}