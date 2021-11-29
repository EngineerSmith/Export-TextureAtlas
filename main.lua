love.event.quit()
local nfs = require("NFS.nativefs")
local lfs = love.filesystem
local args = require("args")

local inputDir = args[1]
assert(inputDir, "Requires inputDir arg")
assert(nfs.getInfo(inputDir, "directory"), "Given inputDir does not exist")

local outputDir = args[2]
assert(outputDir, "Requires outputDir arg")
assert(nfs.createDirectory(outputDir), "Could not make outputDir")

assert(nfs.mount(inputDir, "in", false), "Unable to mount inputDir: "..tostring(inputDir))

local lastChar = outputDir:sub(-1)
if lastChar == "/" or lastChar == "\\" then
  outputDir = outputDir:sub(1, #outputDir-1)
end

local padding = 1
if type(args["-padding"]) == "table" then
  padding = tonumber(args["-padding"][1])
  assert(padding ~= nil, "Given value to -padding <num> could not be converted to a number. Gave: \""..tostring(args["-padding"][1]).."\"")
end

local extrude = 0
if type(args["-extrude"]) == "table" then
  extrude = tonumber(args["-extrude"][1])
  assert(extrude ~= nil, "Given value to -extrude <num> could not be converted to a number. Gave:\""..tostring(args["-extrude"][1]).."\"")
end

local spacing = 0
if type(args["-spacing"]) == "table" then
  spacing = tonumber(args["-spacing"][1])
  assert(spacing ~= nil, "Given value to -spacing <num> could not be converted to a number. Gave:\""..tostring(args["-spacing"][1]).."\"")
end

local atlas
if args["-fixedSize"] then
  assert(type(args["-fixedSize"]) == "table", "Arg -fixedSize requires at least one dimension. If height isn't given, it will be the same as width. -fixedSize W <H>")
  atlas = require("RTA").newFixedSize(
    tonumber(args["-fixedSize"][1]),
    tonumber(args["-fixedSize"][2]) or tonumber(args["-fixedSize"][1]),
    padding, extrude, spacing)
else
  atlas = require("RTA").newDynamicSize(padding, extrude, spacing)
end

if args["-pow2"] then
  atlas:setBakeAsPow2(true)
end

local getExtension = function(path) return path:match("^.+%.(.+)$") end
local getFileName = function(path) return path:gsub("\\", "/"):match("([^/]+)%..+$") end

local processPaths = function(paths)
  for index, path in ipairs(paths) do
    local firstchar, lastchar = path:sub(1,1), path:sub(-1)
    local info = {
      raw = path,
      subDirSearch = firstchar ~= "."
    }
    info.type = (lastchar == "/" or lastchar == "\\") and "directory" or "file"
    if info.type == "directory" then
      local index = 1
      if info.subDirSearch and (firstchar == "/" or firstchar == "\\") then
        index = 2
      elseif not info.subDirSearch then
        index = 3
      end
      info.path = path:sub(index, #path-1)
        -- "./dir/" -> "dir", "/foo/bar/" -> "foo/bar", "foo/bar/" -> "foo/bar"
    else -- info.type == "file"
      info.extension = getExtension(path)
      info.fileName = getFileName(path:sub(info.subDirSearch and ((firstchar == "/" or firstchar == "\\") and 2 or 1) or 3))
      info.path = path:sub(info.subDirSearch and 1 or 3, #path):match("^(.+/)"..info.fileName.."."..info.extension.."$")
      if info.fileName == "*" and info.extension == "*" then
        error("Cannot process two wildcards for both fileName and extension. Have you tried just doing: [.]/"..tostring(info.path))
      elseif info.fileName == "*" then
        info.wildcard = "filename"
      elseif info.extension == "*" then
        info.wildcard = "extension"
      end
    end
    paths[index] = info
  end
end

if type(args["-ignore"]) == "table" then
  processPaths(args["-ignore"])
end

local checkDirectoryIgnore = function(path, directoryName)
  if args["-ignore"] then
    for _, info in ipairs(args["-ignore"]) do
      if info.type == "directory" then
        if info.subDirSearch then
          if directoryName == info.path then
            return false
          end
        elseif path == info.path then
          return false
        end
      end
    end
  end
  return true
end

local checkFileIgnore = function(path, fileName)
  if args["-ignore"] then
    for _, info in ipairs(args["-ignore"]) do
      if info.type == "file" then
        if info.wildcard == "extension" then
          if getFileName(fileName) == info.fileName then
            return false
          end
        elseif info.wildcard == "filename" then
          if path == info.path and getExtension(fileName) == info.extension then
            return false
          end
        elseif (info.raw):match(info.path .. fileName) then
          return false
        end
      end
    end
  end
  return true
end

local iterateDirectory 
iterateDirectory = function(dir, path, callback)
  local items = lfs.getDirectoryItems(dir)
  for _, item in ipairs(items) do
    local loc = dir.."/"..item
    local infoType = lfs.getInfo(loc).type
    if infoType  == "directory" and checkDirectoryIgnore(path..item, item) then
      iterateDirectory(loc, (path..item.."/"), callback)
    elseif infoType == "file" and checkFileIgnore(path, item) then
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

local loadImage = function(location)
  local extension = getExtension(location)
  if not extension or not supportedExtensions[extension:lower()] then
    return
  end
  local success, result = pcall(love.graphics.newImage, location)
  assert(success, "Unable to load image: "..tostring(location)..", Reason:"..tostring(result))
  return result
end

iterateDirectory("in", "", function(location, localPath)
  if args["-removeFileExtension"] then
    local extension = getExtension(location)
    localPath = localPath:sub(1, (#localPath)-(#extension+1))
  end
  local image = loadImage(location)
  if image then
    atlas:add(image, localPath)
  end
end)

if atlas.imagesSize < 1 then
  error("No images have been added to the atlas: "..tostring(atlas.imagesSize))
end

local _, imageData = atlas:hardBake()
assert(imageData, "Fatal error, atlas was baked before reaching this stage")

local fileData = imageData:encode("png") -- Could not use 2nd arg, probably due to mounting via nfs than lfs
local success, errorMessage = nfs.write(outputDir.."/atlas.png", fileData:getString())
assert(success, "Unable to write atlas.png, Reason: "..tostring(errorMessage))

local lustache = require("lustache.lustache")
local defaultTemplate = [[
return {
  quads = {
{{#quads}}
    ["{{{id}}}"] = {
      x = {{x}},
      y = {{y}},
      w = {{w}},
      h = {{h}}
    }{{^last}},{{/last}}
{{/quads}}
  },
  meta = {
    padding = {{meta.padding}},
    extrude = {{meta.extrude}},
    atlasWidth = {{meta.width}},
    atlasHeight = {{meta.height}},
    quadCount = {{meta.quadCount}}{{#meta.fixedSize}},
    fixedSize = {
      width = {{width}},
      height = {{height}},
    }
{{/meta.fixedSize}}
{{^meta.fixedSize}}

{{/meta.fixedSize}}
  }
}
]]

local template, extension = defaultTemplate, "lua"
if type(args["-template"]) == "table" then
  local contents, errorMessage = nfs.read(args["-template"][1])
  assert(contents, "Unable to read "..tostring(args["-template"][1])..", Reason: "..tostring(errorMessage))
  template = contents
  extension = getExtension(args["-template"][1])
end

local quads = {}
for id, lovequad in pairs(atlas.quads) do
  local quad = {}
  quad.id = id
  quad.x, quad.y, quad.w, quad.h = lovequad:getViewport()
  table.insert(quads, quad)
end
quads[#quads].last = true

local meta = {
  padding = atlas.padding,
  extrude = atlas.extrude,
  width = atlas.image:getWidth(),
  height = atlas.image:getHeight(),
  quadCount = #quads,
}

if args["-fixedSize"] then
  meta.fixedSize = {
    width = atlas.width,
    height = atlas.height,
  }
end

nfs.write(outputDir.."/quads."..extension, lustache:render(template, {
  quads = quads,
  meta = meta
}))
