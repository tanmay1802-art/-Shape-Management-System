; ============================================================
; PROGRAM      : Shape Generator with Color
; FILE         : main.asm
; LANGUAGE     : NASM x86 Assembly (32-bit, Linux)
;
; DESCRIPTION  :
;   Generates five shapes algorithmically using loops,
;   parameters, and logic-based rules. No shape is hard-coded.
;   Supports filled and hollow modes, three ANSI colors,
;   and a user-defined draw character.
;
;   SHAPES  : Circle, Square, Rectangle, Triangle, Diamond
;   COLORS  : Red, Green, Blue (via ANSI escape codes)
;   MODES   : Filled or Hollow
;   EXTRAS  : Custom draw character, Repeat after each shape
;
; SYSTEM CALLS USED:
;   sys_read  (eax=3) : read keyboard input from stdin
;   sys_write (eax=4) : write output to stdout
;   sys_exit  (eax=1) : terminate program
;
; BUILD:
;   nasm -f elf32 main.asm -o main.o
;   ld   -m elf_i386 main.o -o main
; RUN:
;   ./main
; ============================================================

BITS 32                             ; Tell NASM we are writing 32-bit code (affects instruction encoding)

; ============================================================
; DATA SECTION - all string constants and prompts
; ============================================================
section .data                       ; This section holds variables that are INITIALIZED (have a value from the start)

    ; ---------- Main Menu ----------
    s_menu      db 10,"============================================",10     ; 'db' = define byte(s); ASCII 10 = newline char; defines the menu banner string
                db "        SHAPE GENERATOR  (NASM x86)        ",10        ; second line of the banner
                db "============================================",10        ; divider line
                db "  1. Circle                                 ",10        ; menu option 1
                db "  2. Square                                 ",10        ; menu option 2
                db "  3. Rectangle                              ",10        ; menu option 3
                db "  4. Triangle  (Isosceles)                  ",10        ; menu option 4
                db "  5. Diamond                                ",10        ; menu option 5
                db "  6. Quit                                   ",10        ; menu option 6 (exit)
                db "============================================",10        ; closing divider
                db "  Your choice: "                                        ; prompt line (no newline - cursor stays on same line)
    s_menu_len  equ $ - s_menu                                             ; 'equ' = equate (constant); '$' = current address; subtract start = total byte length of s_menu

    ; ---------- Sub-menus ----------
    s_color     db 10,"  Color  : 1=Red  2=Green  3=Blue : "               ; prompt asking user to pick a color
    s_color_len equ $ - s_color                                            ; length of the color prompt string in bytes

    s_mode      db 10,"  Mode   : 1=Filled  2=Hollow    : "                ; prompt asking user to pick filled or hollow mode
    s_mode_len  equ $ - s_mode                                             ; length of the mode prompt string in bytes

    s_char      db 10,"  Draw char (press Enter for *) : "                 ; prompt asking user to type a custom character
    s_char_len  equ $ - s_char                                             ; length of the draw-char prompt string in bytes

    s_size      db 10,"  Size   (3-9) : "                                  ; prompt asking user to enter size (single dimension shapes)
    s_size_len  equ $ - s_size                                             ; length of the size prompt in bytes

    s_width     db 10,"  Width  (3-9) : "                                  ; prompt asking user to enter width (for rectangle)
    s_width_len equ $ - s_width                                            ; length of the width prompt in bytes

    s_height    db 10,"  Height (3-9) : "                                  ; prompt asking user to enter height (for rectangle)
    s_hgt_len   equ $ - s_height                                           ; length of the height prompt in bytes

    s_again     db 10,"  Draw again? (y/n) : "                             ; prompt asking if the user wants to redraw the same shape
    s_again_len equ $ - s_again                                            ; length of the repeat prompt in bytes

    ; ---------- System characters ----------
    c_nl        db 10           ; define 1 byte: ASCII 10 = newline character '\n' (moves cursor to next line)
    c_sp        db 32           ; define 1 byte: ASCII 32 = space character ' ' (used for padding/alignment)

    ; ---------- Messages ----------
    s_bye       db 10,"  Goodbye! Thank you.",10,10                        ; farewell message printed on program exit (two newlines for spacing)
    s_bye_len   equ $ - s_bye                                             ; length of the bye message in bytes

    s_err       db 10,"  [!] Invalid input. Please try again.",10          ; error message shown when user types an unexpected value
    s_err_len   equ $ - s_err                                             ; length of the error message in bytes

    ; ---------- ANSI Color Escape Codes ----------
    ; Format: ESC [ color_code m
    ; ESC = byte value 27
    a_red       db 27,"[31m"       ; byte 27 = ESC character; "[31m" = ANSI code for RED text color
    a_red_len   equ $ - a_red     ; length of the red escape sequence in bytes

    a_green     db 27,"[32m"       ; ESC + "[32m" = ANSI code for GREEN text color
    a_grn_len   equ $ - a_green   ; length of the green escape sequence in bytes

    a_blue      db 27,"[34m"       ; ESC + "[34m" = ANSI code for BLUE text color
    a_blu_len   equ $ - a_blue    ; length of the blue escape sequence in bytes

    a_reset     db 27,"[0m"        ; ESC + "[0m" = ANSI reset: turns off all color/formatting, restores terminal default
    a_rst_len   equ $ - a_reset   ; length of the reset escape sequence in bytes

; ============================================================
; BSS SECTION - uninitialized variables (runtime storage)
; ============================================================
section .bss                        ; BSS = Block Started by Symbol; holds variables with NO initial value (filled with zeros at runtime)

    v_ibuf      resb 4      ; 'resb 4' = reserve 4 bytes; input buffer to hold keypress + newline from the user
    v_color     resb 1      ; reserve 1 byte: stores chosen color (1=Red, 2=Green, 3=Blue)
    v_mode      resb 1      ; reserve 1 byte: stores draw mode (1=Filled, 2=Hollow)
    v_dchar     resb 1      ; reserve 1 byte: stores the draw character (user-picked or default '*')
    v_sw        resb 1      ; reserve 1 byte: stores shape width, radius, or general size (single-dimension)
    v_sh        resb 1      ; reserve 1 byte: stores shape height (only used for rectangle where height != width)
    v_sc        resw 1      ; 'resw 1' = reserve 1 word (2 bytes): star/char count per row; word size avoids ECX register conflict with sys_write

; ============================================================
; MACROS
; ============================================================

; sys_write(stdout, addr, len)
%macro PRINT 2              ; define a macro named PRINT that takes 2 arguments: address (%1) and length (%2)
    mov eax, 4              ; eax=4 means sys_write (Linux 32-bit system call number)
    mov ebx, 1              ; ebx=1 means file descriptor 1 = stdout (the terminal screen)
    mov ecx, %1             ; ecx = address of the string/data to print (first macro argument)
    mov edx, %2             ; edx = number of bytes to write (second macro argument)
    int 0x80                ; software interrupt 0x80 triggers the Linux kernel to execute the system call
%endmacro                   ; end of macro definition

; sys_write 1 byte at addr
%macro PRINTC 1             ; define a macro named PRINTC that takes 1 argument: address of a single character (%1)
    mov eax, 4              ; eax=4 = sys_write
    mov ebx, 1              ; ebx=1 = stdout
    mov ecx, %1             ; ecx = address of the single character to print
    mov edx, 1              ; edx=1 = write exactly 1 byte
    int 0x80                ; trigger the system call
%endmacro                   ; end of macro definition

; ============================================================
; TEXT SECTION - program logic
; ============================================================
section .text               ; This section holds the actual executable CPU instructions
global _start               ; 'global _start' exports the _start label so the Linux linker knows where the program begins

; ------------------------------------------------------------
; ENTRY POINT
; ------------------------------------------------------------
_start:                     ; _start is the very first instruction executed when the program runs

main_loop:                  ; label for the main menu loop; we jump back here after each shape is drawn
    PRINT s_menu, s_menu_len    ; call PRINT macro to display the full main menu to the user
    call  fn_read               ; call subroutine fn_read to read the user's menu choice into v_ibuf

    cmp   byte [v_ibuf], '1'    ; compare the first byte of v_ibuf with ASCII '1' (choice 1 = Circle)
    je    shape_circle          ; if equal (je = jump if equal), jump to shape_circle handler
    cmp   byte [v_ibuf], '2'    ; compare with '2' (choice 2 = Square)
    je    shape_square          ; jump to shape_square if user pressed 2
    cmp   byte [v_ibuf], '3'    ; compare with '3' (choice 3 = Rectangle)
    je    shape_rect            ; jump to shape_rect if user pressed 3
    cmp   byte [v_ibuf], '4'    ; compare with '4' (choice 4 = Triangle)
    je    shape_tri             ; jump to shape_tri if user pressed 4
    cmp   byte [v_ibuf], '5'    ; compare with '5' (choice 5 = Diamond)
    je    shape_diamond         ; jump to shape_diamond if user pressed 5
    cmp   byte [v_ibuf], '6'    ; compare with '6' (choice 6 = Quit)
    je    prog_quit             ; jump to prog_quit if user pressed 6
    cmp   byte [v_ibuf], 'q'    ; also accept lowercase 'q' as quit
    je    prog_quit             ; jump to prog_quit if user typed q

    ; invalid input: show error, loop
    PRINT s_err, s_err_len      ; none of the valid keys matched, so print the error message
    jmp   main_loop             ; jump unconditionally back to main_loop to show the menu again

; ------------------------------------------------------------
; EXIT
; ------------------------------------------------------------
prog_quit:                      ; label reached when the user chooses to quit
    PRINT s_bye, s_bye_len      ; print the goodbye message
    mov   eax, 1                ; eax=1 = sys_exit (Linux system call to terminate process)
    xor   ebx, ebx              ; xor ebx,ebx sets ebx=0; exit code 0 means "success" to the OS
    int   0x80                  ; trigger the exit system call; program ends here

; ============================================================
; SHAPE 1: CIRCLE
;
; Algorithm (filled disc):
;   For y = -r to +r  (rows)
;     For x = -r to +r  (columns)
;       if x^2 + y^2 <= r^2  -> print draw char
;       else                 -> print space
;     end for
;     print newline
;   end for
;
; Hollow mode:
;   Plot char only where (r-1)^2 <= x^2+y^2 <= r^2
;   This gives a one-pixel-wide ring border.
;
; Registers:
;   ESI = r  (constant, safe from sys_write which uses eax/ebx/ecx/edx)
;   EBP = y  (outer loop, -r to +r)
;   EDI = x  (inner loop, -r to +r)
; ============================================================
shape_circle:                       ; entry point for drawing a circle
    call  fn_ask_size               ; ask the user for color, mode, draw char, and size; results stored in v_color/v_mode/v_dchar/v_sw
    call  fn_color                  ; apply the chosen ANSI color escape code to stdout so text prints in color

    movzx esi, byte [v_sw]          ; movzx = move with zero-extension; load radius r from v_sw into full 32-bit ESI (upper bits cleared to 0)

    ; start outer loop: y = -r
    mov   ebp, esi                  ; copy r into EBP
    neg   ebp                       ; negate EBP so EBP = -r (starting value for y in the outer loop)

.row:                               ; local label for the outer (row / y) loop
    ; start inner loop: x = -r
    mov   edi, esi                  ; copy r into EDI
    neg   edi                       ; negate EDI so EDI = -r (starting value for x in the inner loop)

.col:                               ; local label for the inner (column / x) loop
    ; compute x^2 + y^2
    mov   eax, edi                  ; load current x value into EAX
    imul  eax, eax                  ; signed multiply EAX by itself: EAX = x^2
    mov   ecx, ebp                  ; load current y value into ECX
    imul  ecx, ecx                  ; ECX = y^2
    add   eax, ecx                  ; EAX = x^2 + y^2 (distance squared from center)

    ; compute r^2
    mov   ecx, esi                  ; load radius r into ECX
    imul  ecx, ecx                  ; ECX = r^2

    ; check mode
    cmp   byte [v_mode], 2          ; compare mode byte with 2 (hollow)
    je    .hollow                   ; if hollow mode selected, jump to hollow logic

    ; --- FILLED MODE ---
    cmp   eax, ecx                  ; compare x^2+y^2 with r^2
    jle   .draw_char                ; if x^2+y^2 <= r^2 the point is inside or on the circle, draw character
    jmp   .draw_space               ; otherwise the point is outside the circle, draw a space

.hollow:                            ; hollow circle logic
    ; --- HOLLOW MODE ---
    ; outside circle: space
    cmp   eax, ecx                  ; compare distance squared with r^2
    jg    .draw_space               ; if x^2+y^2 > r^2 the point is outside the circle, draw space
    ; inside hollow (less than (r-1)^2): space
    mov   ecx, esi                  ; reload r into ECX (it was overwritten above)
    dec   ecx                       ; ECX = r - 1
    imul  ecx, ecx                  ; ECX = (r-1)^2
    cmp   eax, ecx                  ; compare distance squared with (r-1)^2
    jge   .draw_char                ; if x^2+y^2 >= (r-1)^2 the point is on the ring border, draw character
    jmp   .draw_space               ; if x^2+y^2 < (r-1)^2 the point is deep inside the hollow, draw space

.draw_char:                         ; label: print the draw character at this position
    PRINTC v_dchar                  ; call PRINTC macro to print 1 byte (the draw character) stored at v_dchar
    jmp   .col_next                 ; skip over draw_space and go to column loop increment

.draw_space:                        ; label: print a space at this position
    PRINTC c_sp                     ; call PRINTC macro to print 1 byte (space) stored at c_sp

.col_next:                          ; label: bottom of the inner (column) loop
    inc   edi                       ; increment x (EDI++) to move to the next column
    cmp   edi, esi                  ; compare x with r
    jle   .col                      ; if x <= r we haven't passed the right edge yet, loop back to .col

    PRINTC c_nl                     ; x has passed r, so the row is done; print a newline to move to next row

    inc   ebp                       ; increment y (EBP++) to move to the next row
    cmp   ebp, esi                  ; compare y with r
    jle   .row                      ; if y <= r we haven't drawn the bottom row yet, loop back to .row

    call  fn_reset                  ; all rows drawn; reset the ANSI color back to terminal default
    call  fn_repeat                 ; ask the user "Draw again? (y/n)"; result returned in AL
    cmp   al, 1                     ; check if AL == 1 (user said yes)
    je    shape_circle              ; if yes, jump back to shape_circle to draw again
    jmp   main_loop                 ; if no, jump back to main menu

; ============================================================
; SHAPE 2: SQUARE
;
; Algorithm:
;   For row = 1 to size:
;     For col = 1 to size:
;       if filled: print char
;       if hollow: print char only if on border row or border col
;       else: print space
;     end for
;     print newline
;   end for
;
; Registers:
;   ESI = size  EBP = row  EDI = col
; ============================================================
shape_square:                       ; entry point for drawing a square
    call  fn_ask_size               ; ask for color, mode, draw char, and size; results stored in v_* variables
    call  fn_color                  ; apply the chosen ANSI color to the terminal output

    movzx esi, byte [v_sw]          ; load side length (size) into ESI with zero-extension
    xor   ebp, ebp                  ; xor ebp,ebp sets EBP = 0; used as row counter (will be incremented to 1 on first iteration)

.row:                               ; outer loop label (iterates over rows)
    inc   ebp                       ; row++; rows go from 1 to size
    xor   edi, edi                  ; reset column counter EDI = 0 at the start of every new row

.col:                               ; inner loop label (iterates over columns)
    inc   edi                       ; col++; columns go from 1 to size

    cmp   byte [v_mode], 2          ; check if hollow mode is selected
    je    .hollow                   ; if yes, jump to hollow logic

    ; --- FILLED ---
    PRINTC v_dchar                  ; filled mode: always print the draw character regardless of position
    jmp   .col_next                 ; skip hollow logic and go to column loop increment

.hollow:                            ; hollow mode: only draw character on the border edges
    ; border = first/last row OR first/last col
    cmp   ebp, 1                    ; is this the first row?
    je    .border                   ; yes -> it is a border row, draw character
    cmp   ebp, esi                  ; is this the last row (row == size)?
    je    .border                   ; yes -> border row, draw character
    cmp   edi, 1                    ; is this the first column?
    je    .border                   ; yes -> border column, draw character
    cmp   edi, esi                  ; is this the last column (col == size)?
    je    .border                   ; yes -> border column, draw character
    PRINTC c_sp                     ; none of the border conditions matched, so this is an interior cell; print space
    jmp   .col_next                 ; skip the border draw and go to column increment

.border:                            ; label: this cell is on the border of the square
    PRINTC v_dchar                  ; print the draw character on the border

.col_next:                          ; bottom of inner loop
    cmp   edi, esi                  ; compare current column (EDI) with size (ESI)
    jl    .col                      ; if col < size, there are more columns to draw; loop back

    PRINTC c_nl                     ; all columns for this row are done; print a newline

    cmp   ebp, esi                  ; compare current row (EBP) with size (ESI)
    jl    .row                      ; if row < size, there are more rows to draw; loop back

    call  fn_reset                  ; all rows done; reset ANSI color
    call  fn_repeat                 ; ask "Draw again?"
    cmp   al, 1                     ; check if user said yes (AL == 1)
    je    shape_square              ; if yes, redraw the square
    jmp   main_loop                 ; if no, return to main menu

; ============================================================
; SHAPE 3: RECTANGLE
;
; Algorithm:
;   Same as Square but width (v_sw) != height (v_sh).
;   Border detection uses width for col and height for row.
;
; Registers:
;   ESI = width   EBP = row
;   EDI = col     [v_sh] = height (reloaded from memory)
; ============================================================
shape_rect:                         ; entry point for drawing a rectangle
    call  fn_ask_wh                 ; ask for color, mode, draw char, width (v_sw), and height (v_sh) separately
    call  fn_color                  ; apply the chosen ANSI color

    movzx esi, byte [v_sw]          ; load width from v_sw into ESI (zero-extended to 32 bits)
    xor   ebp, ebp                  ; EBP = 0; row counter starts at 0 and is incremented inside the loop

.row:                               ; outer loop: iterates over each row from 1 to height
    inc   ebp                       ; row++
    xor   edi, edi                  ; reset column counter EDI = 0 for each new row

    ; load height into eax for border comparison
    movzx eax, byte [v_sh]          ; load height value from v_sh into EAX; needed to compare against last row

.col:                               ; inner loop: iterates over each column from 1 to width
    inc   edi                       ; col++

    cmp   byte [v_mode], 2          ; check if hollow mode
    je    .hollow                   ; jump to hollow logic if mode == 2

    ; --- FILLED ---
    PRINTC v_dchar                  ; filled mode: print draw character for every cell
    jmp   .col_next                 ; go to column loop increment

.hollow:                            ; hollow mode for rectangle
    movzx eax, byte [v_sh]          ; reload height into EAX (EAX may have been changed by PRINTC's sys_write)
    cmp   ebp, 1                    ; is this the first row?
    je    .border                   ; yes -> border, draw character
    cmp   ebp, eax                  ; is this the last row (row == height)?
    je    .border                   ; yes -> border, draw character
    cmp   edi, 1                    ; is this the first column?
    je    .border                   ; yes -> border, draw character
    cmp   edi, esi                  ; is this the last column (col == width)?
    je    .border                   ; yes -> border, draw character
    PRINTC c_sp                     ; interior cell: print space
    jmp   .col_next                 ; skip to column increment

.border:                            ; this cell is on the rectangle border
    PRINTC v_dchar                  ; print the draw character

.col_next:                          ; bottom of column loop
    cmp   edi, esi                  ; compare col with width
    jl    .col                      ; if col < width, loop back for more columns

    PRINTC c_nl                     ; row is complete; print newline

    movzx eax, byte [v_sh]          ; reload height (needed after PRINTC which changes EAX)
    cmp   ebp, eax                  ; compare row with height
    jl    .row                      ; if row < height, loop back for more rows

    call  fn_reset                  ; shape complete; reset ANSI color
    call  fn_repeat                 ; ask "Draw again?"
    cmp   al, 1                     ; check if user wants to repeat
    je    shape_rect                ; yes -> redraw rectangle
    jmp   main_loop                 ; no -> return to main menu

; ============================================================
; SHAPE 4: ISOSCELES TRIANGLE (tip at top)
;
; Algorithm:
;   For row = 1 to size:
;     print (size - row) leading spaces
;     print (2 * row - 1) chars
;     print newline
;
; Hollow mode:
;   On interior rows: print char only at col index 0 (left edge)
;   and col index (count-1) (right edge). All others: space.
;   Tip row (row=1) and base row (row=size): all chars.
;
; Registers:
;   ESI = size     EBP = row
;   EDI = counter  [v_sc] = star count (word var, avoids ECX clash)
; ============================================================
shape_tri:                          ; entry point for drawing an isosceles triangle (tip pointing up)
    call  fn_ask_size               ; ask for color, mode, draw char, and size (number of rows)
    call  fn_color                  ; apply the chosen ANSI color

    movzx esi, byte [v_sw]          ; load total number of rows (size) into ESI
    xor   ebp, ebp                  ; EBP = 0; row counter (incremented to 1 on first use)

.row:                               ; outer loop: one iteration per row of the triangle
    inc   ebp                       ; row++; goes from 1 to size

    ; --- print leading spaces: (size - row) ---
    mov   edi, esi                  ; EDI = size (number of leading spaces to print = size - row)
    sub   edi, ebp                  ; EDI = size - row (the number of spaces needed before the characters on this row)

.lead_sp:                           ; loop to print the required leading spaces
    cmp   edi, 0                    ; have we printed all required leading spaces?
    jle   .stars                    ; if EDI <= 0 we are done with spaces, jump to print the characters
    PRINTC c_sp                     ; print one space character
    dec   edi                       ; decrement space counter
    jmp   .lead_sp                  ; loop back to print next space

.stars:                             ; done with spaces; now print the draw characters for this row
    ; star count = 2 * row - 1  -> stored in v_sc (word)
    mov   eax, ebp                  ; EAX = current row number
    imul  eax, 2                    ; EAX = 2 * row
    dec   eax                       ; EAX = 2 * row - 1 (number of draw characters on this row; row 1=1 char, row 2=3 chars, etc.)
    mov   word [v_sc], ax           ; store the character count in memory variable v_sc (word); ECX must remain free for sys_write
    xor   edi, edi                  ; EDI = 0; column index (0 to count-1)

.col:                               ; inner loop: print each character on this row
    cmp   byte [v_mode], 2          ; check if hollow mode
    je    .hollow                   ; jump to hollow logic if yes

    ; --- FILLED ---
    PRINTC v_dchar                  ; filled mode: print draw character at every column position
    jmp   .col_next                 ; go to column increment

.hollow:                            ; hollow triangle logic
    ; tip or base row: always draw char
    cmp   ebp, 1                    ; is this the tip row (row == 1)?
    je    .draw_c                   ; yes -> always draw character on the tip row (only 1 char anyway)
    cmp   ebp, esi                  ; is this the base row (row == size)?
    je    .draw_c                   ; yes -> always draw all characters on the base row (bottom edge)
    ; left edge: col index 0
    cmp   edi, 0                    ; is this the leftmost column on this row (index 0)?
    je    .draw_c                   ; yes -> draw the left edge character
    ; right edge: col index = count - 1
    movzx eax, word [v_sc]          ; load total character count for this row from v_sc
    dec   eax                       ; EAX = count - 1 (index of the rightmost character)
    cmp   edi, eax                  ; is current column index == rightmost index?
    je    .draw_c                   ; yes -> draw the right edge character
    PRINTC c_sp                     ; interior cell (not tip, base, left, or right edge): print space
    jmp   .col_next                 ; skip draw and go to column increment

.draw_c:                            ; label: this column should show the draw character
    PRINTC v_dchar                  ; print the draw character

.col_next:                          ; bottom of the inner column loop
    inc   edi                       ; col++ (advance column index)
    movzx eax, word [v_sc]          ; reload character count for this row from v_sc
    cmp   edi, eax                  ; compare column index with count
    jl    .col                      ; if col < count, more characters to print on this row; loop back

    PRINTC c_nl                     ; row is complete; print newline

    cmp   ebp, esi                  ; compare current row with total rows (size)
    jl    .row                      ; if row < size, more rows to draw; loop back

    call  fn_reset                  ; triangle done; reset ANSI color
    call  fn_repeat                 ; ask "Draw again?"
    cmp   al, 1                     ; check repeat answer
    je    shape_tri                 ; yes -> redraw triangle
    jmp   main_loop                 ; no -> return to main menu

; ============================================================
; SHAPE 5: DIAMOND
;
; Algorithm:
;   Top half (row = 1 to size):
;     spaces = size - row
;     chars  = 2 * row - 1
;   Bottom half (row = size-1 down to 1):
;     same formula (mirror)
;
;   Hollow mode: draw char only at col 0 and col (count-1)
;   except on widest row (row=size) where all chars drawn.
;
; Registers:
;   ESI = size    EBP = row
;   EDI = counter [v_sc] = char count per row
; ============================================================
shape_diamond:                      ; entry point for drawing a diamond shape
    call  fn_ask_size               ; ask for color, mode, draw char, and size (half-height of the diamond)
    call  fn_color                  ; apply the chosen ANSI color

    movzx esi, byte [v_sw]          ; load size (half-height) into ESI

    ; --- TOP HALF: row 1 to size ---
    xor   ebp, ebp                  ; EBP = 0; row counter for the top half

.top_row:                           ; loop for each row of the top half of the diamond
    inc   ebp                       ; row++; goes from 1 to size
    call  fn_dia_row                ; call helper subroutine to print one row of the diamond (uses EBP=row, ESI=size)
    cmp   ebp, esi                  ; compare current row with size (widest row)
    jl    .top_row                  ; if row < size, more top half rows to draw; loop back

    ; --- BOTTOM HALF: row size-1 down to 1 ---
    mov   ebp, esi                  ; EBP = size (start from the row just below the widest row)
    dec   ebp                       ; EBP = size - 1 (first row of the bottom half)

.bot_row:                           ; loop for each row of the bottom half (mirror of top half)
    cmp   ebp, 0                    ; have we gone below row 1?
    jle   .done                     ; if EBP <= 0, bottom half is complete; jump to done
    call  fn_dia_row                ; print one row of the bottom half
    dec   ebp                       ; row-- (bottom half goes from size-1 down to 1)
    jmp   .bot_row                  ; loop back for next bottom half row

.done:                              ; diamond fully drawn
    call  fn_reset                  ; reset ANSI color
    call  fn_repeat                 ; ask "Draw again?"
    cmp   al, 1                     ; check repeat answer
    je    shape_diamond             ; yes -> redraw diamond
    jmp   main_loop                 ; no -> return to main menu

; ============================================================
; HELPER: fn_dia_row
;   Prints one row of the diamond.
;   ESI = size (half-height, constant)
;   EBP = current row number
;   Uses EDI as column counter, v_sc as char count.
;   All registers preserved with push/pop.
; ============================================================
fn_dia_row:                         ; subroutine: prints a single row of the diamond shape
    push  edi                       ; save EDI on the stack because we will use it as a local counter (caller may need its value)

    ; --- leading spaces: size - row ---
    mov   edi, esi                  ; EDI = size
    sub   edi, ebp                  ; EDI = size - row (number of leading spaces for this row)

.sp:                                ; loop to print leading spaces
    cmp   edi, 0                    ; are there more spaces to print?
    jle   .ch                       ; if EDI <= 0, done with spaces; jump to character printing
    PRINTC c_sp                     ; print one space
    dec   edi                       ; spaces remaining--
    jmp   .sp                       ; loop back

.ch:                                ; done with spaces; now print draw characters
    ; char count = 2 * row - 1
    mov   eax, ebp                  ; EAX = current row number
    imul  eax, 2                    ; EAX = 2 * row
    dec   eax                       ; EAX = 2 * row - 1 (number of characters on this row)
    mov   word [v_sc], ax           ; store character count in v_sc (word) to keep ECX free for sys_write
    xor   edi, edi                  ; EDI = 0; column index

.col:                               ; inner loop: print each character on this row
    cmp   byte [v_mode], 2          ; check for hollow mode
    je    .hollow                   ; if hollow, jump to hollow logic

    PRINTC v_dchar                  ; filled mode: print draw character at every position
    jmp   .cnext                    ; jump to column increment

.hollow:                            ; hollow diamond logic for this row
    ; widest row (ebp == esi): all chars
    cmp   ebp, esi                  ; is this the widest row (row == size)?
    je    .dc                       ; yes -> draw character at every position on the widest row
    ; left edge
    cmp   edi, 0                    ; is this the leftmost position (col index 0)?
    je    .dc                       ; yes -> draw left edge character
    ; right edge
    movzx eax, word [v_sc]          ; load total character count for this row from v_sc
    dec   eax                       ; EAX = count - 1 (index of the rightmost character)
    cmp   edi, eax                  ; is current column the rightmost position?
    je    .dc                       ; yes -> draw right edge character
    PRINTC c_sp                     ; interior of hollow diamond: print space
    jmp   .cnext                    ; skip to column increment

.dc:                                ; label: draw the character at this position
    PRINTC v_dchar                  ; print the draw character

.cnext:                             ; bottom of the column loop
    inc   edi                       ; col++
    movzx eax, word [v_sc]          ; reload character count for this row
    cmp   edi, eax                  ; compare col index with count
    jl    .col                      ; if col < count, more characters to print; loop back

    PRINTC c_nl                     ; row complete; print newline

    pop   edi                       ; restore EDI to its original value (from the push at the start of this function)
    ret                             ; return to the caller (back to shape_diamond's top or bottom half loop)

; ============================================================
; SUBROUTINE: fn_ask_size
;   Asks: color, mode, draw char, and a single size (3-9).
;   Stores results in v_color, v_mode, v_dchar, v_sw.
;   All general registers preserved.
; ============================================================
fn_ask_size:                        ; subroutine: gathers all user inputs needed before drawing a single-dimension shape
    push  eax                       ; save EAX on stack (we will use EAX internally; must restore before return)
    push  ebx                       ; save EBX
    push  ecx                       ; save ECX
    push  edx                       ; save EDX

    call  fn_ask_color              ; call sub-subroutine to ask for color and store result in v_color
    call  fn_ask_mode               ; call sub-subroutine to ask for filled/hollow mode and store in v_mode
    call  fn_ask_char               ; call sub-subroutine to ask for draw character and store in v_dchar

.sz:                                ; loop label: retry asking for size if invalid input
    PRINT s_size, s_size_len        ; print the size prompt ("  Size (3-9): ")
    call  fn_read                   ; read user's size input into v_ibuf

    movzx eax, byte [v_ibuf]        ; load the ASCII character typed by user into EAX (zero-extended)
    sub   eax, '0'                  ; convert ASCII digit to numeric value (e.g., '5' - '0' = 5)
    cmp   eax, 3                    ; is the number less than 3?
    jl    .bad                      ; if yes, it is out of allowed range; jump to error handler
    cmp   eax, 9                    ; is the number greater than 9?
    jg    .bad                      ; if yes, out of range; jump to error handler
    mov   [v_sw], al                ; valid size: store the numeric value (low byte of EAX) into v_sw
    jmp   .done                     ; jump past error handler to exit subroutine

.bad:                               ; label: invalid size entered
    PRINT s_err, s_err_len          ; print error message
    jmp   .sz                       ; loop back to ask for size again

.done:                              ; label: valid input obtained
    pop   edx                       ; restore EDX (LIFO order: last pushed = first popped)
    pop   ecx                       ; restore ECX
    pop   ebx                       ; restore EBX
    pop   eax                       ; restore EAX
    ret                             ; return to the caller

; ============================================================
; SUBROUTINE: fn_ask_wh
;   Like fn_ask_size but asks width and height separately.
; ============================================================
fn_ask_wh:                          ; subroutine: gathers inputs for a two-dimension shape (rectangle)
    push  eax                       ; preserve EAX
    push  ebx                       ; preserve EBX
    push  ecx                       ; preserve ECX
    push  edx                       ; preserve EDX

    call  fn_ask_color              ; ask for color; result stored in v_color
    call  fn_ask_mode               ; ask for mode; result stored in v_mode
    call  fn_ask_char               ; ask for draw character; result stored in v_dchar

.aw:                                ; loop label: retry asking for width if invalid
    PRINT s_width, s_width_len      ; print the width prompt
    call  fn_read                   ; read user's width input

    movzx eax, byte [v_ibuf]        ; load typed character into EAX (zero-extended)
    sub   eax, '0'                  ; convert ASCII to numeric value
    cmp   eax, 3                    ; check lower bound
    jl    .bw                       ; too small -> jump to width error
    cmp   eax, 9                    ; check upper bound
    jg    .bw                       ; too large -> jump to width error
    mov   [v_sw], al                ; valid width: store in v_sw
    jmp   .ah                       ; proceed to ask for height

.bw:                                ; label: invalid width
    PRINT s_err, s_err_len          ; print error message
    jmp   .aw                       ; loop back to ask for width again

.ah:                                ; loop label: retry asking for height if invalid
    PRINT s_height, s_hgt_len       ; print the height prompt
    call  fn_read                   ; read user's height input

    movzx eax, byte [v_ibuf]        ; load typed character into EAX
    sub   eax, '0'                  ; convert ASCII to numeric
    cmp   eax, 3                    ; check lower bound
    jl    .bh                       ; too small -> jump to height error
    cmp   eax, 9                    ; check upper bound
    jg    .bh                       ; too large -> jump to height error
    mov   [v_sh], al                ; valid height: store in v_sh
    jmp   .done                     ; exit subroutine

.bh:                                ; label: invalid height
    PRINT s_err, s_err_len          ; print error message
    jmp   .ah                       ; loop back to ask for height again

.done:                              ; both width and height successfully read
    pop   edx                       ; restore EDX
    pop   ecx                       ; restore ECX
    pop   ebx                       ; restore EBX
    pop   eax                       ; restore EAX
    ret                             ; return to caller

; ============================================================
; SUBROUTINE: fn_ask_color
;   Shows color menu, reads 1-3, stores in v_color.
;   All registers preserved.
; ============================================================
fn_ask_color:                       ; subroutine: asks user to pick a color (1=Red, 2=Green, 3=Blue)
    push  eax                       ; preserve EAX
    push  ebx                       ; preserve EBX
    push  ecx                       ; preserve ECX
    push  edx                       ; preserve EDX

.lp:                                ; loop label: retry if invalid color entered
    PRINT s_color, s_color_len      ; print the color selection prompt
    call  fn_read                   ; read user input into v_ibuf

    mov   al, [v_ibuf]              ; load the first byte of input (the character typed) into AL
    cmp   al, '1'                   ; is it less than '1'?
    jl    .bad                      ; if yes, invalid input
    cmp   al, '3'                   ; is it greater than '3'?
    jg    .bad                      ; if yes, invalid input
    sub   al, '0'                   ; convert ASCII character to numeric value (1, 2, or 3)
    mov   [v_color], al             ; store the numeric color choice in v_color
    jmp   .done                     ; exit loop

.bad:                               ; label: invalid color choice
    PRINT s_err, s_err_len          ; print error message
    jmp   .lp                       ; loop back to prompt again

.done:                              ; valid color stored
    pop   edx                       ; restore EDX
    pop   ecx                       ; restore ECX
    pop   ebx                       ; restore EBX
    pop   eax                       ; restore EAX
    ret                             ; return to caller

; ============================================================
; SUBROUTINE: fn_ask_mode
;   Shows mode menu (1=Filled, 2=Hollow), stores in v_mode.
;   All registers preserved.
; ============================================================
fn_ask_mode:                        ; subroutine: asks user to pick filled or hollow mode
    push  eax                       ; preserve EAX
    push  ebx                       ; preserve EBX
    push  ecx                       ; preserve ECX
    push  edx                       ; preserve EDX

.lp:                                ; loop label: retry if invalid mode entered
    PRINT s_mode, s_mode_len        ; print the mode selection prompt
    call  fn_read                   ; read user input

    mov   al, [v_ibuf]              ; load first byte of input into AL
    cmp   al, '1'                   ; is it '1' (filled)?
    je    .ok                       ; yes -> valid input
    cmp   al, '2'                   ; is it '2' (hollow)?
    je    .ok                       ; yes -> valid input
    PRINT s_err, s_err_len          ; neither '1' nor '2' -> print error
    jmp   .lp                       ; loop back to prompt again

.ok:                                ; valid mode character in AL
    sub   al, '0'                   ; convert ASCII '1' or '2' to numeric 1 or 2
    mov   [v_mode], al              ; store the mode value in v_mode

    pop   edx                       ; restore EDX
    pop   ecx                       ; restore ECX
    pop   ebx                       ; restore EBX
    pop   eax                       ; restore EAX
    ret                             ; return to caller

; ============================================================
; SUBROUTINE: fn_ask_char
;   Prompts for a custom draw character.
;   If user presses Enter, defaults to '*'.
;   All registers preserved.
; ============================================================
fn_ask_char:                        ; subroutine: asks user for a custom draw character; defaults to '*' if Enter is pressed
    push  eax                       ; preserve EAX
    push  ebx                       ; preserve EBX
    push  ecx                       ; preserve ECX
    push  edx                       ; preserve EDX

    PRINT s_char, s_char_len        ; print the draw character prompt
    call  fn_read                   ; read user input into v_ibuf

    mov   al, [v_ibuf]              ; load first byte of input into AL
    cmp   al, 10                    ; is it ASCII 10 (LF = Enter on Linux)?
    je    .def                      ; yes -> user pressed Enter; use default '*'
    cmp   al, 13                    ; is it ASCII 13 (CR = Enter on Windows/some terminals)?
    je    .def                      ; yes -> treat as Enter; use default
    cmp   al, 0                     ; is it a null byte (empty / no input)?
    je    .def                      ; yes -> use default '*'
    mov   [v_dchar], al             ; store the typed character as the draw character

    jmp   .done                     ; skip the default assignment

.def:                               ; label: user pressed Enter (or gave empty input)
    mov   byte [v_dchar], '*'       ; set draw character to default '*'

.done:                              ; draw character is set
    pop   edx                       ; restore EDX
    pop   ecx                       ; restore ECX
    pop   ebx                       ; restore EBX
    pop   eax                       ; restore EAX
    ret                             ; return to caller

; ============================================================
; SUBROUTINE: fn_color
;   Writes ANSI escape code for v_color to stdout.
;   All registers preserved.
; ============================================================
fn_color:                           ; subroutine: outputs the ANSI escape code matching the color stored in v_color
    push  eax                       ; preserve EAX
    push  ebx                       ; preserve EBX
    push  ecx                       ; preserve ECX
    push  edx                       ; preserve EDX

    movzx eax, byte [v_color]       ; load color choice (1, 2, or 3) from v_color into EAX (zero-extended)
    cmp   eax, 1                    ; is the color red?
    je    .red                      ; yes -> jump to print red escape code
    cmp   eax, 2                    ; is the color green?
    je    .grn                      ; yes -> jump to print green escape code

    ; default: blue
    PRINT a_blue, a_blu_len         ; color is neither 1 nor 2, so default to blue ANSI escape code
    jmp   .done                     ; skip red/green labels

.red:                               ; label: print red color escape code
    PRINT a_red, a_red_len          ; output ESC[31m to terminal (switches text to red)
    jmp   .done                     ; exit

.grn:                               ; label: print green color escape code
    PRINT a_green, a_grn_len        ; output ESC[32m to terminal (switches text to green)

.done:                              ; color escape code has been sent
    pop   edx                       ; restore EDX
    pop   ecx                       ; restore ECX
    pop   ebx                       ; restore EBX
    pop   eax                       ; restore EAX
    ret                             ; return to caller

; ============================================================
; SUBROUTINE: fn_reset
;   Writes ANSI reset code + newline.
;   All registers preserved.
; ============================================================
fn_reset:                           ; subroutine: resets terminal color to default and prints a newline
    push  eax                       ; preserve EAX
    push  ebx                       ; preserve EBX
    push  ecx                       ; preserve ECX
    push  edx                       ; preserve EDX

    PRINT a_reset, a_rst_len        ; output ESC[0m to terminal to cancel any active color/formatting
    PRINTC c_nl                     ; print a newline for spacing after the shape

    pop   edx                       ; restore EDX
    pop   ecx                       ; restore ECX
    pop   ebx                       ; restore EBX
    pop   eax                       ; restore EAX
    ret                             ; return to caller

; ============================================================
; SUBROUTINE: fn_repeat
;   Asks "Draw again? (y/n)".
;   Returns: AL = 1 if 'y'/'Y', AL = 0 if 'n'/'N'.
;   Note: EAX not pushed so AL is the return value.
; ============================================================
fn_repeat:                          ; subroutine: asks user if they want to draw the same shape again; returns result in AL
    push  ebx                       ; preserve EBX (EAX is intentionally NOT pushed so AL can carry the return value)
    push  ecx                       ; preserve ECX
    push  edx                       ; preserve EDX

.lp:                                ; loop label: retry if invalid answer entered
    PRINT s_again, s_again_len      ; print "Draw again? (y/n):" prompt
    call  fn_read                   ; read the user's answer into v_ibuf

    mov   al, [v_ibuf]              ; load first byte of user's answer into AL
    cmp   al, 'y'                   ; is it lowercase 'y'?
    je    .yes                      ; yes -> user wants to repeat
    cmp   al, 'Y'                   ; is it uppercase 'Y'?
    je    .yes                      ; yes -> also treat as yes
    cmp   al, 'n'                   ; is it lowercase 'n'?
    je    .no                       ; yes -> user does not want to repeat
    cmp   al, 'N'                   ; is it uppercase 'N'?
    je    .no                       ; yes -> also treat as no
    PRINT s_err, s_err_len          ; not y/Y/n/N -> print error message
    jmp   .lp                       ; loop back to ask again

.yes:                               ; user wants to draw again
    mov   al, 1                     ; set return value AL = 1 (means YES)
    jmp   .done                     ; jump to return

.no:                                ; user does not want to draw again
    xor   al, al                    ; set return value AL = 0 (xor with itself always gives 0; means NO)

.done:                              ; answer is in AL
    pop   edx                       ; restore EDX
    pop   ecx                       ; restore ECX
    pop   ebx                       ; restore EBX
    ret                             ; it will return to caller; AL holds 1 (yes) or 0 (no)

; ============================================================
; SUBROUTINE: fn_read
;   sys_read(stdin, v_ibuf, 4)
;   Reads up to 4 bytes from stdin into v_ibuf.
;   All registers preserved here.
; ============================================================
fn_read:                            ; it will subroutine: reads up to 4 bytes of keyboard input from the user
    push  eax                       ; this preserve EAX (will be overwritten by sys_read)
    push  ebx                       ; this preserve EBX
    push  ecx                       ; it preserve ECX
    push  edx                       ; this preserve EDX

    mov   eax, 3                    ; so , eax=3 = sys_read (Linux 32-bit system call number for reading input)
    mov   ebx, 0                    ; this  ebx=0 = file descriptor 0 = stdin (keyboard input)
    mov   ecx, v_ibuf               ; it will , ecx = address of v_ibuf buffer where the input bytes will be stored
    mov   edx, 4                    ; so , edx=4 = maximum number of bytes to read (1 char + newline + possible CR + null)
    int   0x80                      ; it will trigger the Linux kernel system call; typed characters are stored in v_ibuf

    pop   edx                       ; restore  the EDX
    pop   ecx                       ; will restore the ECX
    pop   ebx                       ; restores the EBX
    pop   eax                       ; it restore the EAX
    ret                             ; return to caller; v_ibuf now contains what the user typed

