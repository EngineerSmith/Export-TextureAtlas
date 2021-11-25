local args = love.arg.parseGameArguments(arg)

local processed, last = {}, nil
if i=1, #args do
  local notFirstChar = args[i]:sub(1,1) ~= "-"
  if last and notFirstChar then
    if type(processed[last]) ~= "table" then
      processed[last] = {args[i]}
    else
      processed[last][#processed[last]+1] = args[i]
    end
  elseif notFirstChar then
    processed[#processed+1] = args[i]
  else
    processed[args[i]] = true
    last = args[i]
  end
end

return {
  raw = args,
  processed = processed
}