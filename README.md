# Export-TextureAtlas
Turns Runtime-TextureAtlas love library into a compile time tool

# Arguments
`love . <inputDir> <outputDir> [<...>]`
## inputDir
Required argument. Directory must exist; containing all images to add to texture atlas

**Note**, directory can end with `\` or `/` or neither
### Example
`love . ./bin/in <outputDir>`

`love . ./assets/images/ <outputDir>`
## outputDir
Required argument. Directory doesn't need to exist, once ran it will overwrite files and (hopefully) output the files within as `atlas.png` and `quads.<template extension>`

**Note**, directory can end with `\` or `/` or neither
### Example
`love . <inputDir ./bin/out`

`love . <inputDir> ./assets/textureAtlas/`
## -padding <num>
Optional. Padding between images on the atlas, defaults to 1. Will throw a handled error if it cannot be converted to a number.

**Note**, cannot be a negative otherwise it will be mistaken as an argument
### Example
`love . <inputDir> <outputDir> -padding 1`

`love . <inputDir> <outputDir> -padding 12`
## -extrude <num>
Optional. Extrudes the given image on the atlas, defaults to 0. Will throw a handled error if it cannot be converted to a number.

**Note**, cannot be a negative otherwise it will be mistaken as an argument
### Example
`love . <inputDir> <outputDir> -extrude 1`

`love . <inputDir> <outputDir> -extrude 16`
## -fixedSize \<width> [\<height>]
Optional. Uses a fixed size atlas from [Runtime-TextureAtlas](https://github.com/EngineerSmith/Runtime-TextureAtlas). All given images in a directory must be the same size. `height` is an optional value and will default to the required `width` value.
### Example
`love . <inputDir> <outputDir> -fixedSize 16`

`love . <inputDir> <outputDir> -fixedSize 16 32`
## -throwUnsupportedImageExtensions
Optional. This argument will throw if it discovers an image within the input direcotry which isn't supported by love's `love.graphics.newImage` funciton.
### Example
`love . <inputDir> <outputDir> -throwUnsupportedImageExtensions`
## -removeFileExtension
Optional. This argument will remove image file extension for their given id. This could clash and overwrite other quads if you have the same image name with different extensions.
`foo/bar.png` becomes `foo/bar`
### Example
`love . <inputDir> <outputDir> -removeFileExtension`
## -template <filepath>
Optional. This overrides the default internal templated. See [Lustache](https://github.com/Olivine-Labs/lustache) for how to create a template.

The default is as followed:
```
local data = {
{{#quads}}
  ["{{{id}}}"] = {
    quad = {
      x = {{x}},
      y = {{y}},
      w = {{w}},
      h = {{h}},
    },
  },
{{/quads}}
  meta = {
    padding = {{meta.padding}},
  }
}
return data
```
**Note**, the file extension of the template is used to sign the file. E.g. `template.lua` -> `quads.lua`, `template.json` -> `quads.json`
### Example
`love . <inputDir> <outputDir> -template ./bin/in/template.lua`

`love . <inputDir> <outputDir> -template ./assets/textureAtlas/template.json`
# Libraries used
* [Runtime-TextureAtlas](https://github.com/EngineerSmith/Runtime-TextureAtlas)
* [Native FS](https://github.com/megagrump/nativefs)
* [Lustache](https://github.com/Olivine-Labs/lustache)