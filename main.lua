love.event.quit()
local nfs = require("NFS.nativefs")
local lfs = love.filesystem
local args = require("args")

local getExtension = function(path) return path:match("^.+%.(.+)$") end
local getFileName = function(path) return path:gsub("\\", "/"):match("([^/]+)%..+$") end
local getFullFile = function(path) return path:gsub("\\", "/"):match("([^/]+)$") end

local inputDirs = { args[1] }
if args[1] then
  assert(nfs.getInfo(args[1], "directory"), "Given input directory does not exist: "..args[1])
end
if type(args["-input"]) == "table" then
  for index, path in ipairs(args["-input"]) do
    table.insert(inputDirs, path)
    assert(nfs.getInfo(path, "directory"), "Given input directory at "..tostring(index).." does not exist: "..path)
  end
end
assert(#inputDirs > 0, "Requires input directory paths either as the first parameter, or using the -input flag")

local outputDirs = {}
if args[2] then
  local path, info = args[2], {}
  local lastChar, extension = path:sub(-1), getExtension(path)
  if not extension then
    if lastChar == "/" or lastChar == "\\" then
      path = path:sub(1, #path-1)
    end
    info.path = path
    info.type = "directory"
    assert(nfs.createDirectory(path), "Could not make output directory at 2nd parameter: "..path)
  else
    info.path = path
    local fileName = getFileName(path) or getFullFile(path)
    info.addExtension = extension == nil
    local chars = #fileName + (extension and #extension+1 or 0)
    info.directory = path:sub(1, #path-chars-1)
    info.type = "file"
  end
  outputDirs[1] = info
end
if type(args["-output"]) == "table" then
  for index, path in ipairs(args["-output"]) do
    local info = {}
    local lastChar, extension = path:sub(-1), getExtension(path)
    if not extension then
      if lastChar == "/" or lastChar == "\\" then
        path = path:sub(1, #path-1)
      end
      info.path = path
      info.type = "directory"
      assert(nfs.createDirectory(path), "Could not make output directory at 2nd parameter: "..path)
    else
      info.path = path
      local fileName = getFileName(path) or getFullFile(path)
      info.addExtension = extension == nil
      local chars = #fileName + (extension and #extension+1 or 0)
      info.directory = path:sub(1, #path-chars-1)
      info.type = "file"
    end
    table.insert(outputDirs, info)
  end
end
assert(#outputDirs > 0, "Requires output directory paths as the second parameter, or using the -output flag")

if #outputDirs == 1 then
  outputDirs = outputDirs[1]
  if #inputDirs > 1 then
    assert(outputDirs.type == "directory", "As there are multiple defined input directories, you cannot have a file path as the single output directory")
  end
else
  assert(#outputDirs == #inputDirs, "Mismatched number of input and output directories given. Input: "..#inputDirs..", Output: "..#outputDirs)
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

for inputIndex, inputDir in ipairs(inputDirs) do
  assert(nfs.mount(inputDir, "in", false), "Unable to mount input directory: "..tostring(inputDir))
  
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
  
  assert(nfs.unmount(inputDir), "Unable to unmount input directory: "..tostring(inputDir))
  
  if atlas.imagesSize < 1 then
    error("No images have been added to the atlas: "..tostring(atlas.imagesSize))
  end
  
  local _, imageData = atlas:hardBake()
  assert(imageData, "Fatal error, atlas was baked before reaching this stage")
  
  local output = type(outputDirs) == "table" and outputDirs[inputIndex] or outputDirs
  
  local atlasPath
  if output.type == "file" then
    atlasPath = output.path..(output.addExtension and ".png" or "")
  else
    atlasPath = output.path.."/atlas"..(#inputDirs > 1 and tostring(inputIndex) or "")..".png"
  end
  
  local fileData = imageData:encode("png") -- Could not use 2nd arg, probably due to mounting via nfs than lfs
  local success, errorMessage = nfs.write(atlasPath, fileData:getString())
  assert(success, "Unable to write atlas.png, Reason: "..tostring(errorMessage))
  
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
  
  local dataPath = output.path
  if output.type == "file" then
    dataPath = output.directory
  end
  dataPath = dataPath.."/data"..(#inputDirs > 1 and tostring(inputIndex) or "").."."..extension
  
  local success, errorMessage = nfs.write(dataPath, lustache:render(template, {
    quads = quads,
    meta = meta,
  }))
  assert(success, "Could not write data file out: "..tostring(errorMessage))
end