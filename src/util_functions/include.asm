; include.asm
;
; util functions to include


%strcat _printchar FUNCTIONS "print/printchar.asm"
%include _printchar
%strcat _printstring FUNCTIONS "print/printstring.asm"
%include _printstring
%strcat _printhex FUNCTIONS "print/printhex.asm"
%include _printhex
