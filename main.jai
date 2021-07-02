#import "SDL";
#import "GL";

width : s32 = 640;
height: s32 = 480;

main :: () {
  SDL_Init(SDL_INIT_VIDEO);
  window := SDL_CreateWindow("chess-jai", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, width, height, SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);
  if window == null {
    return;
  }
  defer {
    // Close and destroy the window
    SDL_DestroyWindow(window);
    SDL_Quit();
  }
  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "linear");
  renderer := SDL_CreateRenderer(window, -1, SDL_RendererFlags.ACCELERATED);
  if renderer == null {
    return;
  }

  exit := false;
  while !exit {

    // prepare scene
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    SDL_RenderClear(renderer);

    // do input:
    event : SDL_Event;
    while SDL_PollEvent(*event) {
      if event.type == {
      case SDL_QUIT;
        exit = true;
      case SDL_WINDOWEVENT;
        if event.window.event == SDL_WINDOWEVENT_SIZE_CHANGED {
          width  = event.window.data1;
          height = event.window.data2;
        }
      }
    }

    // present scene
    SDL_RenderPresent(renderer);



    SDL_GL_SwapWindow(window);
    SDL_Delay(1);
  }
}












