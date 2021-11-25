# Export-TextureAtlas (ETA)
Extends the [Runtime-TextureAtlas library](https://github.com/EngineerSmith/Runtime-TextureAtlas) and allows it to be exported as a file. This tool requires [Love2d](https://love2d.org/) to work, but the resulting files are not tied to Love2D. Use a custom template to change the format of the quads file to how you want it. See `-template <filepath>` argument on how to create your own export template, or just use the default one provided.

This tool can be fused similarly to any other love project. Follow these [instructions](https://love2d.org/wiki/Game_Distribution) for your platform. Note, all arguments will work the same, but `love . <args>`/`love <ETA dir> <args>` will become `fused.exe <args>`, etc.
## Clone
`git clone https://github.com/EngineerSmith/Export-TextureAtlas --recurse-submodules`
## Example use
`love . ./bin/in/ ./bin/out/ -removeFileExtension -throwUnsupportedImageExtensions -extrude 1 -padding 1`

`love . ./bin/in/ ./bin/out/ -removeFileExtension -extrude 1 -padding 1 -fixedSize 16 16 -template ./bin/template.lua`

`love . ./bin/in/ ./bin/out/ -removeFileExtension -padding 2 -template ./bin/template.json`
# Arguments
`love . <inputDir> <outputDir> [<...>]`
## inputDir
Required argument. Directory must exist; containing all images to add to texture atlas.

**Note**, directory can end with `\` or `/` or neither.
### Example
`love . ./bin/in <outputDir>`

`love . ./assets/images/ <outputDir>`

`love . C:\user\Santa\game\assets\images\ <outputDir>`
## outputDir
Required argument. The directory doesn't need to exist, once ran it will overwrite files and (hopefully) output the files within as `atlas.png` and `quads.<template extension>`.

**Note**, directory can end with `\` or `/` or neither.
### Example
`love . <inputDir ./bin/out`

`love . <inputDir> ./assets/textureAtlas/`

`love . <inputDir> C:\user\Santa\game\assets\textureAtlas\`
## -padding \<num>
Optional. Padding between images on the atlas, defaults to 1. Will throw a handled error if it cannot be converted to a number.

**Note**, it cannot be a negative, otherwise it will be mistaken as an argument. This value does not get added onto the exported quad, but does shift its location on the atlas.
### Example
`love . <inputDir> <outputDir> -padding 1`

`love . <inputDir> <outputDir> -padding 12`
## -extrude \<num>
Optional. Extrudes the given image on the atlas, defaults to 0. Will throw a handled error if it cannot be converted to a number. It will use the [clamp warp mode](https://love2d.org/wiki/WrapMode).

**Note**, it cannot be a negative, otherwise it will be mistaken as an argument. This value does not get added onto the exported quad, but does shift its location on the atlas.
### Example
`love . <inputDir> <outputDir> -extrude 1`

`love . <inputDir> <outputDir> -extrude 16`
## -fixedSize \<width> [\<height>]
Optional. Uses a fixed size atlas from [Runtime-TextureAtlas](https://github.com/EngineerSmith/Runtime-TextureAtlas). All given images in a directory must be the same size. `height` is an optional value and will default to the required `width` value.
### Example
`love . <inputDir> <outputDir> -fixedSize 16`

`love . <inputDir> <outputDir> -fixedSize 16 32`
## -throwUnsupportedImageExtensions
Optional. This argument will throw if it discovers an image within the input directory which isn't supported by love's `love.graphics.newImage` function.
### Example
`love . <inputDir> <outputDir> -throwUnsupportedImageExtensions`
## -removeFileExtension
Optional. This argument will remove image file extension for their given id. This could clash and overwrite other quads if you have the same image name with different extensions.
`foo/bar.png` becomes `foo/bar`
### Example
`love . <inputDir> <outputDir> -removeFileExtension`
## -template \<filepath>
Optional. This overrides the default internal templated. See [Lustache](https://github.com/Olivine-Labs/lustache) for how to create a template.

**Note**, the file extension of the template is used to sign the file. E.g. `template.lua` -> `quads.lua`, `template.json` -> `quads.json`

The default(lua table) is as followed, and contains all available variables:
```
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
```
Formatted JSON example:
```
{
  "quads": {
{{#quads}}
    "{{{id}}}": {
      "x": {{x}},
      "y": {{y}},
      "w": {{w}},
      "h": {{h}}
    }{{^last}},{{/last}}
{{/quads}}
  },
  "meta" = {
    "padding": {{meta.padding}},
    "extrude": {{meta.extrude}},
    "atlasWidth": {{meta.width}},
    "atlasHeight": {{meta.height}},
    "quadCount": {{meta.quadCount}}{{#meta.fixedSize}},
    "fixedSize": {
      "width": {{width}},
      "height": {{height}}
    }
{{/meta.fixedSize}}
{{^meta.fixedSize}}

{{/meta.fixedSize}}
  }
}
```
### Example
`love . <inputDir> <outputDir> -template ./bin/in/template.lua`

`love . <inputDir> <outputDir> -template ./assets/textureAtlas/template.json`
# Libraries used
* [Runtime-TextureAtlas](https://github.com/EngineerSmith/Runtime-TextureAtlas)
* [Native FS](https://github.com/megagrump/nativefs)
* [Lustache](https://github.com/Olivine-Labs/lustache)
