love.conf = function(t)
  t.window.width = 1
  t.window.height = 1
  t.window.x = -5
  t.window.y = -5
  
  t.modules.event    = true
  t.modules.graphics = true
  t.modules.image    = true
  t.modules.window   = true
  
  t.modules.audio    = false
  t.modules.data     = false
  t.modules.font     = false
  t.modules.joystick = false
  t.modules.keyboard = false
  t.modules.math     = false
  t.modules.mouse    = false
  t.modules.physics  = false
  t.modules.sound    = false
  t.modules.system   = false
  t.modules.thread   = false
  t.modules.timer    = false
  t.modules.touch    = false
  t.modules.video    = false
end

love.run = function()
  if love._version_major == "11" and jit then
    -- Slime has confirmed that this will not work on all platforms in love12, and so it must be tested in the future
    local ffi = require("ffi") 
    ffi.cdef[[
      typedef void SDL_Window;
      SDL_Window* SDL_GL_GetCurrentWindow(void);
      void SDL_HideWindow(SDL_Window * window);
    ]]
    local SDL2 = ffi.load("SDL2")
    local window = SDL2.SDL_GL_GetCurrentWindow()
    SDL2.SDL_HideWindow(window)
  end
  return function()
    if love.event then
      love.event.pump()
      for name, a,b,c,d,e,f in love.event.poll() do
        if name == "quit" then
          return a or 0
        end
      end
    end
  end
end