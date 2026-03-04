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

BITS 32

; ============================================================
; DATA SECTION - all string constants and prompts
; ============================================================
section .data

    ; ---------- Main Menu ----------
    s_menu      db 10,"============================================",10
                db "        SHAPE GENERATOR  (NASM x86)        ",10
                db "============================================",10
                db "  1. Circle                                 ",10
                db "  2. Square                                 ",10
                db "  3. Rectangle                              ",10
                db "  4. Triangle  (Isosceles)                  ",10
                db "  5. Diamond                                ",10
                db "  6. Quit                                   ",10
                db "============================================",10
                db "  Your choice: "
    s_menu_len  equ $ - s_menu

    ; ---------- Sub-menus ----------
    s_color     db 10,"  Color  : 1=Red  2=Green  3=Blue : "
    s_color_len equ $ - s_color

    s_mode      db 10,"  Mode   : 1=Filled  2=Hollow    : "
    s_mode_len  equ $ - s_mode

    s_char      db 10,"  Draw char (press Enter for *) : "
    s_char_len  equ $ - s_char

    s_size      db 10,"  Size   (3-9) : "
    s_size_len  equ $ - s_size

    s_width     db 10,"  Width  (3-9) : "
    s_width_len equ $ - s_width

    s_height    db 10,"  Height (3-9) : "
    s_hgt_len   equ $ - s_height

    s_again     db 10,"  Draw again? (y/n) : "
    s_again_len equ $ - s_again

    ; ---------- System characters ----------
    c_nl        db 10           ; newline  (ASCII 10)
    c_sp        db 32           ; space    (ASCII 32)

    ; ---------- Messages ----------
    s_bye       db 10,"  Goodbye! Thank you.",10,10
    s_bye_len   equ $ - s_bye

    s_err       db 10,"  [!] Invalid input. Please try again.",10
    s_err_len   equ $ - s_err

    ; ---------- ANSI Color Escape Codes ----------
    ; Format: ESC [ color_code m
    ; ESC = byte value 27
    a_red       db 27,"[31m"       ; red text
    a_red_len   equ $ - a_red

    a_green     db 27,"[32m"       ; green text
    a_grn_len   equ $ - a_green

    a_blue      db 27,"[34m"       ; blue text
    a_blu_len   equ $ - a_blue

    a_reset     db 27,"[0m"        ; reset to default color
    a_rst_len   equ $ - a_reset

; ============================================================
; BSS SECTION - uninitialized variables (runtime storage)
; ============================================================
section .bss

    v_ibuf      resb 4      ; input buffer: holds keypress + newline
    v_color     resb 1      ; chosen color  : 1=Red, 2=Green, 3=Blue
    v_mode      resb 1      ; draw mode     : 1=Filled, 2=Hollow
    v_dchar     resb 1      ; draw character: user-defined or '*'
    v_sw        resb 1      ; shape width  / radius / size
    v_sh        resb 1      ; shape height (rectangle only)
    v_sc        resw 1      ; star count per row (word, avoids ECX conflict)

; ============================================================
; MACROS
; ============================================================

; sys_write(stdout, addr, len)
%macro PRINT 2
    mov eax, 4
    mov ebx, 1
    mov ecx, %1
    mov edx, %2
    int 0x80
%endmacro

; sys_write 1 byte at addr
%macro PRINTC 1
    mov eax, 4
    mov ebx, 1
    mov ecx, %1
    mov edx, 1
    int 0x80
%endmacro

; ============================================================
; TEXT SECTION - program logic
; ============================================================
section .text
global _start

; ------------------------------------------------------------
; ENTRY POINT
; ------------------------------------------------------------
_start:

main_loop:
    PRINT s_menu, s_menu_len
    call  fn_read

    cmp   byte [v_ibuf], '1'
    je    shape_circle
    cmp   byte [v_ibuf], '2'
    je    shape_square
    cmp   byte [v_ibuf], '3'
    je    shape_rect
    cmp   byte [v_ibuf], '4'
    je    shape_tri
    cmp   byte [v_ibuf], '5'
    je    shape_diamond
    cmp   byte [v_ibuf], '6'
    je    prog_quit
    cmp   byte [v_ibuf], 'q'
    je    prog_quit

    ; invalid input: show error, loop
    PRINT s_err, s_err_len
    jmp   main_loop

; ------------------------------------------------------------
; EXIT
; ------------------------------------------------------------
prog_quit:
    PRINT s_bye, s_bye_len
    mov   eax, 1
    xor   ebx, ebx
    int   0x80

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
shape_circle:
    call  fn_ask_size       ; sets v_color, v_mode, v_dchar, v_sw
    call  fn_color          ; apply ANSI color

    movzx esi, byte [v_sw]  ; esi = r

    ; start outer loop: y = -r
    mov   ebp, esi
    neg   ebp

.row:
    ; start inner loop: x = -r
    mov   edi, esi
    neg   edi

.col:
    ; compute x^2 + y^2
    mov   eax, edi
    imul  eax, eax          ; eax = x^2
    mov   ecx, ebp
    imul  ecx, ecx          ; ecx = y^2
    add   eax, ecx          ; eax = x^2 + y^2

    ; compute r^2
    mov   ecx, esi
    imul  ecx, ecx          ; ecx = r^2

    ; check mode
    cmp   byte [v_mode], 2
    je    .hollow

    ; --- FILLED MODE ---
    cmp   eax, ecx
    jle   .draw_char
    jmp   .draw_space

.hollow:
    ; --- HOLLOW MODE ---
    ; outside circle: space
    cmp   eax, ecx
    jg    .draw_space
    ; inside hollow (less than (r-1)^2): space
    mov   ecx, esi
    dec   ecx
    imul  ecx, ecx          ; (r-1)^2
    cmp   eax, ecx
    jge   .draw_char        ; on the ring border
    jmp   .draw_space

.draw_char:
    PRINTC v_dchar
    jmp   .col_next

.draw_space:
    PRINTC c_sp

.col_next:
    inc   edi
    cmp   edi, esi
    jle   .col              ; loop while x <= r

    PRINTC c_nl             ; newline after each row

    inc   ebp
    cmp   ebp, esi
    jle   .row              ; loop while y <= r

    call  fn_reset          ; reset ANSI color
    call  fn_repeat         ; ask to repeat
    cmp   al, 1
    je    shape_circle
    jmp   main_loop

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
shape_square:
    call  fn_ask_size
    call  fn_color

    movzx esi, byte [v_sw]  ; esi = size
    xor   ebp, ebp          ; row = 0

.row:
    inc   ebp               ; row: 1 to size
    xor   edi, edi          ; col = 0

.col:
    inc   edi               ; col: 1 to size

    cmp   byte [v_mode], 2
    je    .hollow

    ; --- FILLED ---
    PRINTC v_dchar
    jmp   .col_next

.hollow:
    ; border = first/last row OR first/last col
    cmp   ebp, 1
    je    .border
    cmp   ebp, esi
    je    .border
    cmp   edi, 1
    je    .border
    cmp   edi, esi
    je    .border
    PRINTC c_sp             ; interior: space
    jmp   .col_next

.border:
    PRINTC v_dchar

.col_next:
    cmp   edi, esi
    jl    .col              ; loop while col < size

    PRINTC c_nl

    cmp   ebp, esi
    jl    .row              ; loop while row < size

    call  fn_reset
    call  fn_repeat
    cmp   al, 1
    je    shape_square
    jmp   main_loop

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
shape_rect:
    call  fn_ask_wh         ; asks width AND height separately
    call  fn_color

    movzx esi, byte [v_sw]  ; esi = width
    xor   ebp, ebp          ; row = 0

.row:
    inc   ebp
    xor   edi, edi

    ; load height into eax for border comparison
    movzx eax, byte [v_sh]

.col:
    inc   edi

    cmp   byte [v_mode], 2
    je    .hollow

    ; --- FILLED ---
    PRINTC v_dchar
    jmp   .col_next

.hollow:
    movzx eax, byte [v_sh]  ; reload height (eax safe after PRINTC)
    cmp   ebp, 1
    je    .border
    cmp   ebp, eax          ; last row?
    je    .border
    cmp   edi, 1
    je    .border
    cmp   edi, esi          ; last col?
    je    .border
    PRINTC c_sp
    jmp   .col_next

.border:
    PRINTC v_dchar

.col_next:
    cmp   edi, esi
    jl    .col

    PRINTC c_nl

    movzx eax, byte [v_sh]
    cmp   ebp, eax
    jl    .row

    call  fn_reset
    call  fn_repeat
    cmp   al, 1
    je    shape_rect
    jmp   main_loop

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
shape_tri:
    call  fn_ask_size
    call  fn_color

    movzx esi, byte [v_sw]  ; esi = number of rows
    xor   ebp, ebp          ; row = 0

.row:
    inc   ebp               ; row: 1 to size

    ; --- print leading spaces: (size - row) ---
    mov   edi, esi
    sub   edi, ebp          ; edi = space count

.lead_sp:
    cmp   edi, 0
    jle   .stars
    PRINTC c_sp
    dec   edi
    jmp   .lead_sp

.stars:
    ; star count = 2 * row - 1  -> stored in v_sc (word)
    mov   eax, ebp
    imul  eax, 2
    dec   eax
    mov   word [v_sc], ax   ; save to memory so ECX stays free
    xor   edi, edi          ; edi = column index 0 to count-1

.col:
    cmp   byte [v_mode], 2
    je    .hollow

    ; --- FILLED ---
    PRINTC v_dchar
    jmp   .col_next

.hollow:
    ; tip or base row: always draw char
    cmp   ebp, 1
    je    .draw_c
    cmp   ebp, esi
    je    .draw_c
    ; left edge: col index 0
    cmp   edi, 0
    je    .draw_c
    ; right edge: col index = count - 1
    movzx eax, word [v_sc]
    dec   eax
    cmp   edi, eax
    je    .draw_c
    PRINTC c_sp
    jmp   .col_next

.draw_c:
    PRINTC v_dchar

.col_next:
    inc   edi
    movzx eax, word [v_sc]
    cmp   edi, eax
    jl    .col              ; loop while col < count

    PRINTC c_nl

    cmp   ebp, esi
    jl    .row

    call  fn_reset
    call  fn_repeat
    cmp   al, 1
    je    shape_tri
    jmp   main_loop

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
shape_diamond:
    call  fn_ask_size
    call  fn_color

    movzx esi, byte [v_sw]

    ; --- TOP HALF: row 1 to size ---
    xor   ebp, ebp

.top_row:
    inc   ebp
    call  fn_dia_row
    cmp   ebp, esi
    jl    .top_row

    ; --- BOTTOM HALF: row size-1 down to 1 ---
    mov   ebp, esi
    dec   ebp

.bot_row:
    cmp   ebp, 0
    jle   .done
    call  fn_dia_row
    dec   ebp
    jmp   .bot_row

.done:
    call  fn_reset
    call  fn_repeat
    cmp   al, 1
    je    shape_diamond
    jmp   main_loop

; ============================================================
; HELPER: fn_dia_row
;   Prints one row of the diamond.
;   ESI = size (half-height, constant)
;   EBP = current row number
;   Uses EDI as column counter, v_sc as char count.
;   All registers preserved with push/pop.
; ============================================================
fn_dia_row:
    push  edi

    ; --- leading spaces: size - row ---
    mov   edi, esi
    sub   edi, ebp

.sp:
    cmp   edi, 0
    jle   .ch
    PRINTC c_sp
    dec   edi
    jmp   .sp

.ch:
    ; char count = 2 * row - 1
    mov   eax, ebp
    imul  eax, 2
    dec   eax
    mov   word [v_sc], ax
    xor   edi, edi

.col:
    cmp   byte [v_mode], 2
    je    .hollow

    PRINTC v_dchar
    jmp   .cnext

.hollow:
    ; widest row (ebp == esi): all chars
    cmp   ebp, esi
    je    .dc
    ; left edge
    cmp   edi, 0
    je    .dc
    ; right edge
    movzx eax, word [v_sc]
    dec   eax
    cmp   edi, eax
    je    .dc
    PRINTC c_sp
    jmp   .cnext

.dc:
    PRINTC v_dchar

.cnext:
    inc   edi
    movzx eax, word [v_sc]
    cmp   edi, eax
    jl    .col

    PRINTC c_nl

    pop   edi
    ret

; ============================================================
; SUBROUTINE: fn_ask_size
;   Asks: color, mode, draw char, and a single size (3-9).
;   Stores results in v_color, v_mode, v_dchar, v_sw.
;   All general registers preserved.
; ============================================================
fn_ask_size:
    push  eax
    push  ebx
    push  ecx
    push  edx

    call  fn_ask_color
    call  fn_ask_mode
    call  fn_ask_char

.sz:
    PRINT s_size, s_size_len
    call  fn_read

    movzx eax, byte [v_ibuf]
    sub   eax, '0'
    cmp   eax, 3
    jl    .bad
    cmp   eax, 9
    jg    .bad
    mov   [v_sw], al
    jmp   .done

.bad:
    PRINT s_err, s_err_len
    jmp   .sz

.done:
    pop   edx
    pop   ecx
    pop   ebx
    pop   eax
    ret

; ============================================================
; SUBROUTINE: fn_ask_wh
;   Like fn_ask_size but asks width and height separately.
; ============================================================
fn_ask_wh:
    push  eax
    push  ebx
    push  ecx
    push  edx

    call  fn_ask_color
    call  fn_ask_mode
    call  fn_ask_char

.aw:
    PRINT s_width, s_width_len
    call  fn_read

    movzx eax, byte [v_ibuf]
    sub   eax, '0'
    cmp   eax, 3
    jl    .bw
    cmp   eax, 9
    jg    .bw
    mov   [v_sw], al
    jmp   .ah

.bw:
    PRINT s_err, s_err_len
    jmp   .aw

.ah:
    PRINT s_height, s_hgt_len
    call  fn_read

    movzx eax, byte [v_ibuf]
    sub   eax, '0'
    cmp   eax, 3
    jl    .bh
    cmp   eax, 9
    jg    .bh
    mov   [v_sh], al
    jmp   .done

.bh:
    PRINT s_err, s_err_len
    jmp   .ah

.done:
    pop   edx
    pop   ecx
    pop   ebx
    pop   eax
    ret

; ============================================================
; SUBROUTINE: fn_ask_color
;   Shows color menu, reads 1-3, stores in v_color.
;   All registers preserved.
; ============================================================
fn_ask_color:
    push  eax
    push  ebx
    push  ecx
    push  edx

.lp:
    PRINT s_color, s_color_len
    call  fn_read

    mov   al, [v_ibuf]
    cmp   al, '1'
    jl    .bad
    cmp   al, '3'
    jg    .bad
    sub   al, '0'
    mov   [v_color], al
    jmp   .done

.bad:
    PRINT s_err, s_err_len
    jmp   .lp

.done:
    pop   edx
    pop   ecx
    pop   ebx
    pop   eax
    ret

; ============================================================
; SUBROUTINE: fn_ask_mode
;   Shows mode menu (1=Filled, 2=Hollow), stores in v_mode.
;   All registers preserved.
; ============================================================
fn_ask_mode:
    push  eax
    push  ebx
    push  ecx
    push  edx

.lp:
    PRINT s_mode, s_mode_len
    call  fn_read

    mov   al, [v_ibuf]
    cmp   al, '1'
    je    .ok
    cmp   al, '2'
    je    .ok
    PRINT s_err, s_err_len
    jmp   .lp

.ok:
    sub   al, '0'
    mov   [v_mode], al

    pop   edx
    pop   ecx
    pop   ebx
    pop   eax
    ret

; ============================================================
; SUBROUTINE: fn_ask_char
;   Prompts for a custom draw character.
;   If user presses Enter, defaults to '*'.
;   All registers preserved.
; ============================================================
fn_ask_char:
    push  eax
    push  ebx
    push  ecx
    push  edx

    PRINT s_char, s_char_len
    call  fn_read

    mov   al, [v_ibuf]
    cmp   al, 10            ; Enter key (LF)
    je    .def
    cmp   al, 13            ; carriage return
    je    .def
    cmp   al, 0
    je    .def
    mov   [v_dchar], al     ; store user character
    jmp   .done

.def:
    mov   byte [v_dchar], '*'

.done:
    pop   edx
    pop   ecx
    pop   ebx
    pop   eax
    ret

; ============================================================
; SUBROUTINE: fn_color
;   Writes ANSI escape code for v_color to stdout.
;   All registers preserved.
; ============================================================
fn_color:
    push  eax
    push  ebx
    push  ecx
    push  edx

    movzx eax, byte [v_color]
    cmp   eax, 1
    je    .red
    cmp   eax, 2
    je    .grn

    ; default: blue
    PRINT a_blue, a_blu_len
    jmp   .done

.red:
    PRINT a_red, a_red_len
    jmp   .done

.grn:
    PRINT a_green, a_grn_len

.done:
    pop   edx
    pop   ecx
    pop   ebx
    pop   eax
    ret

; ============================================================
; SUBROUTINE: fn_reset
;   Writes ANSI reset code + newline.
;   All registers preserved.
; ============================================================
fn_reset:
    push  eax
    push  ebx
    push  ecx
    push  edx

    PRINT a_reset, a_rst_len
    PRINTC c_nl

    pop   edx
    pop   ecx
    pop   ebx
    pop   eax
    ret

; ============================================================
; SUBROUTINE: fn_repeat
;   Asks "Draw again? (y/n)".
;   Returns: AL = 1 if 'y'/'Y', AL = 0 if 'n'/'N'.
;   Note: EAX not pushed so AL is the return value.
; ============================================================
fn_repeat:
    push  ebx
    push  ecx
    push  edx

.lp:
    PRINT s_again, s_again_len
    call  fn_read

    mov   al, [v_ibuf]
    cmp   al, 'y'
    je    .yes
    cmp   al, 'Y'
    je    .yes
    cmp   al, 'n'
    je    .no
    cmp   al, 'N'
    je    .no
    PRINT s_err, s_err_len
    jmp   .lp

.yes:
    mov   al, 1
    jmp   .done

.no:
    xor   al, al

.done:
    pop   edx
    pop   ecx
    pop   ebx
    ret

; ============================================================
; SUBROUTINE: fn_read
;   sys_read(stdin, v_ibuf, 4)
;   Reads up to 4 bytes from stdin into v_ibuf.
;   All registers preserved.
; ============================================================
fn_read:
    push  eax
    push  ebx
    push  ecx
    push  edx

    mov   eax, 3            ; sys_read
    mov   ebx, 0            ; fd = stdin
    mov   ecx, v_ibuf       ; buffer address
    mov   edx, 4            ; max bytes to read
    int   0x80

    pop   edx
    pop   ecx
    pop   ebx
    pop   eax
    ret

