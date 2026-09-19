#ifndef VGA_H
#define VGA_H

//VGA X86
#define VGA_ADDRESS 0xB8000

//screen 
#define VGA_WIDTH   80
#define VGA_HEIGHT  25

//colors 
#define BLACK   0
#define BLUE    1
#define GREEN   2
#define CYAN    3
#define RED     4
#define MAGENTA 5
#define BROWN   6
#define LGRAY   7
#define DGRAY   8
#define LBLUE   9
#define LGREEN  10
#define LCYAN   11
#define LRED    12
#define LMAGENTA 13
#define YELLOW  14
#define WHITE   15

//color background + Text in bit
#define COLOR(bg, fg) (((bg) << 4) | (fg))

#endif
