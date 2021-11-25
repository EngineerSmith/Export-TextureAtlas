local nfs = require("nfs.nativefs")
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
