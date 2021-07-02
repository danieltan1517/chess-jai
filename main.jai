#import "Basic";
#import "Math";
#import "Render";
#import "glfw";
#import "GL";

main :: () {
  if !glfwInit() then return;
  defer glfwTerminate();
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  window := glfwCreateWindow(640, 480, "Jai Chess", null, null);
  if !window then return;
  defer glfwDestroyWindow(window);

  glfwMakeContextCurrent(window);
  gl_load(*gl, glfwGetProcAddress);
  im_init_gl();

  while !glfwWindowShouldClose(window) {
    width, height : s32;
    glfwGetFramebufferSize(window, *width, *height);
    glViewport(0, 0, xx width, xx height);
    glClear(GL_COLOR_BUFFER_BIT);

    im_draw_setup_gl();
    im_set_viewport_transform(2.0/width, 2.0/height, -1, -1);
    draw_chessboard(xx width, xx height);
    im_flush();

    glfwSwapBuffers(window);
    glfwPollEvents();
  }
}

draw_chessboard :: (width: float, height: float, white_side := true) {
  cen_x := width * 0.5; 
  cen_y := height * 0.5;

  len := min(width, height) * 0.8;
  square_len := len / 8.0;

  x := cen_x - len*.5;
  y := cen_y - len*.5;

  white_color :: Vector4.{238.0/255.0, 238.0/255.0, 210.0/255.0, 1.0};
  black_color :: Vector4.{118.0/255.0, 150.0/255.0,  86.0/255.0, 1.0};

  TF := ifx white_side false else true;
  for i: 0..7 {
    for j: 0..7 {
      posx := x + i*square_len;
      posy := y + j*square_len;
      if TF {
        im_draw_rect(posx, posy, posx + square_len, posy + square_len, c=white_color);
      } else {
        im_draw_rect(posx, posy, posx + square_len, posy + square_len, c=black_color);
      }
      TF = TF ^ true;
    }
    TF = TF ^ true;
  }
}





