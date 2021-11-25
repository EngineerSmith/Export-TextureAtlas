local nfs = require("nfs.nativefs")
local lfs = love.filesystem
local args = require("args")

local inputDir = args.processed[1]
assert(inputDir, "Requires inputDir arg")
assert(nfs.getInfo(inputDir, "directory"), "Given inputDir does not exist")

local outputDir = args.processed[2]
assert(outputDir, "Requires outputDir arg")
assert(nfs.createDirectory(outputDir), "Could not make outputDir")

assert(nfs.mount(inputDir, "in", false), "Unable to mount inputDir: "..tostring(inputDir))

local lastChar = outputDir:sub(-1)
if lastChar == "/" or lastChar == "\\" then
  outputDir = outputDir:sub(1, #outputDir-1)
end

local padding = 1
if args.processed["-padding"] then
  padding = tonumber(args.processed["-padding"][1])
  assert(padding ~= nil, "Given value to -padding <num> could not be converted to a number. Gave: \""..tostring(args.processed["-padding"][1]).."\"")
end

local extrude = 0
if args.processed["-extrude"] then
  extrude = tonumber(args.processed["-extrude"][1])
  assert(extrude ~= nil, "Given value to -extrude <num> could not be converted to a number. Gave:\""..tostring(args.processed["-extrude"][1]).."\"")
end

local atlas
if args.processed["-fixedSize"] then
  assert(type(args.processed["-fixedSize"]) == "table", "Arg -fixedSize requires at least one dimension. If height isn't given, it will be the same as width. -fixedSize W <H>")
  atlas = require("RTA").newFixedSize(
    tonumber(args.processed["-fixedSize"][1]),
    tonumber(args.processed["-fixedSize"][2]) or tonumber(args.processed["-fixedSize"][1]),
    padding, extrude)
else
  atlas = require("RTA").newDynamicSize(padding, extrude)
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
  if not extension or not supportedExtensions[extension:lower()] then
    if args.processed["-throwUnsupportedImageExtensions"] then
      error("Tried to load unsupported image extension: "..tostring(extension))
    end
    return
  end
  local success, result = pcall(love.graphics.newImage, location)
  assert(success, "Unable to load image: "..tostring(location)..", Reason:"..tostring(result))
  return result
end

iterateDirectory("in", "", function(location, localPath)
  if args.processed["-removeFileExtension"] then
    local extension = getExtension(location)
    localPath = localPath:sub(1, (#localPath)-(#extension+1))
  end
  local image = loadImage(location)
  return image and atlas:add(image, localPath)
end)

local _, imageData = atlas:hardBake()
assert(imageData, "Fatal error, atlas was baked before reaching this stage")

local fileData = imageData:encode("png") -- Could not use 2nd arg, probably due to mounting via nfs than lfs
local success, errorMessage = nfs.write(outputDir.."/atlas.png", fileData:getString())
assert(success, "Unable to write atlas.png, Reason: "..tostring(errorMessage))

local lustache = require("lustache.lustache")
local defaultTemplate = [[
local data = {
{{#quads}}
  ["{{{id}}}"] = {
    x = {{x}},
    y = {{y}},
    w = {{w}},
    h = {{h}},
  },
{{/quads}}
  meta = {
    padding = {{meta.padding}},
    extrude = {{meta.extrude}},
  }
}
return data
]]

local template, extension = defaultTemplate, "lua"
if type(args.processed["-template"]) == "table" then
  local contents, errorMessage = nfs.read(args.processed["-template"][1])
  assert(contents, "Unable to read "..tostring(args.processed["-template"][1])..", Reason: "..tostring(errorMessage))
  template = contents
  extension = getExtension(args.processed["-template"][1])
end

local quads = {}
for id, lovequad in pairs(atlas.quads) do
  local quad = {}
  quad.id = id
  quad.x, quad.y, quad.w, quad.h = lovequad:getViewport()
  table.insert(quads, quad)
end

local meta = {
  padding = atlas.padding,
  extrude = atlas.extrude,
}

nfs.write(outputDir.."/quads."..extension, lustache:render(template, {
  quads = quads,
  meta = meta
}))

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
