local nfs = require("nfs.nativefs")
local lfs = love.filesystem
local args = require("args")

local inputDir = args.processed[1]
assert(inputDir, "Requires inputDir arg")
assert(nfs.getInfo(inputDir, "directory"), "Given inputDir does not exist")

local outputDir = args.processed[2]
assert(outputDir, "Requires outputDir arg")
if nfs.getInfo(outputDir, "directory") then
  assert(nfs.remove(outputDir), "Could not remove outputDir")
end
assert(nfs.createDirectory(outputDir), "Could not make outputDir")

assert(nfs.mount(inputDir, "in", false), "Unable to mount inputDir: "..tostring(inputDir))
assert(nfs.mount(outputDir, "out", false), "Unable to mount outputDir: "..tostring(outputDir))

local padding = 0
if args.processed["-padding"] then
  padding = tonumber(args.processed["-padding"][1])
  assert(padding ~= nil, "Given value to -padding <pad> could not be converted to a number. Gave: \""..tostring(args.processed["-padding"][1]).."\"")
end

local atlas
if args.processed["-fixedSize"] then
  assert(type(args.processed["-fixedSize"]) == "table", "Arg -fixedSize requires at least one dimension. If height isn't given, it will be the same as width. -fixedSize W <H>")
  atlas = require("RTA").newFixedSize(
    args.processed["-fixedSize"][1], 
    args.processed["-fixedSize"][2] or args.processed["-fixedSize"][1],
    padding)
else
  atlas = require("RTA").newDynamicSize(padding)
end

local iterateDirectory 
iterateDirectory = function(dir, path, callback)
  local items = lfs.getDirectoryItems(dir)
  for _, item in ipairs(items) do
    local loc = dir.."/"..item
    local infoType = lfs.getInfo(loc).type
    if infoType  == "directory" then
      iterateDirectory(loc, (path..item.."/"), callback)
    elseif infoType == "file" then
      callback(loc, path..item)
    end
  end
end

local supportedExtensions = {
  ["jpeg"] = true,
  ["jpg"] = true,
  ["png"] = true,
  ["bmp"] = true, 
  ["tga"] = true,
  ["hdr"] = true,
  ["pic"] = true,
  ["exr"] = true,
}

local getExtension = function(path) return path:match("^.+%.(.+)$") end

local loadImage = function(location)
  local extension = getExtension(location)
  assert(extension and supportedExtensions[extension:lower()], "Tried to load unsupported image extension: "..tostring(extension))
  local success, result = pcall(love.graphics.newImage, location)
  assert(success, "Unable to load image: "..tostring(location)..", Reason:"..tostring(result))
  return result
end

iterateDirectory("in", "", function(location, localPath)
  if args.processed["-removeFileExtension"] then
    local extension = getExtension(location)
    localPath = localPath:sub(1, (#localPath)-(#extension+1))
  end
  atlas:add(loadImage(location), localPath)
end)

atlas:hardBake()

love.draw = function()
  if atlas.image then
    love.graphics.print(atlas.image:getWidth()..":"..atlas.image:getHeight())
--    local n = 30
--    for k, _ in pairs(atlas.quads) do
--      love.graphics.print(tostring(k), 10, n)
--      n = n + 20
--    end
    love.graphics.draw(atlas.image, 0, 50)
  end
end
