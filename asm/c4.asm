; "Connect Four" search program for ENIAC chess VM
  .isa v4
  .org 100

; The board is stored as a matrix in row major order in 42 (6x7) words in
; accs 0-8.  NB the board is assumed in many places to begin at address 0.
; TODO Investigate packing the board into 21 words by using one digit per
; piece instead.
;board      .equ 0   ; 42 words, 0=none, 1=player1, 2=player2
boardsize  .equ 42
dboardsize .equ 58  ; 100-boardsize
; Locations 42, 43, and 44 are used as auxiliary storage
winner     .equ 42  ; 0=no winner, 1=player1, 2=player2, 3=draw
tmpcol     .equ 42  ; winner doubles up as a tmp for column in win routine
tmp        .equ 43  ; generic spill
sp         .equ 44  ; reserved to spill sp
; Accs 9-14 are used as working memory and stack for a 5-level search
stackbase  .equ 9   ; base of stack = acc 9
stackmax   .equ 14  ; max stack

  ; eniac always goes first and plays in the middle
  mov 1,A<->D       ; D=player1
  mov 5,A           ; A=column 4
  jsr move
  mov 1,A<->D       ; D=player1
  mov 4,A           ; A=column 4
  jsr move
  mov 1,A<->D       ; D=player1
  mov 3,A           ; A=column 4
  jsr move
  mov 2,A<->D       ; D=player2
  mov 2,A           ; A=column 4
  jsr move
  mov 2,A<->D       ; D=player2
  mov 2,A           ; A=column 4
  jsr move
  mov 2,A<->D       ; D=player2
  mov 2,A           ; A=column 4
  jsr move
  mov 2,A<->D       ; D=player2
  mov 3,A           ; A=column 4
  jsr move
  mov 1,A<->D       ; D=player2
  mov 4,A           ; A=column 4
  jsr move
  mov 1,A<->D       ; D=player2
  mov 3,A           ; A=column 4
  jsr move
  mov 1,A<->D       ; D=player2
  mov 2,A           ; A=column 4
  jsr move
  jsr printb

  halt

game
  read              ; human plays next, read move into LS
  mov 2,A<->D       ; D=player2
  mov F,A           ; A=column played
  jsr move
  jsr printb

  jmp far score1
score1_ret
  
  jmp game

  halt

  .org 200

; score the current board for player 1
; called in just one place from game loop and branches back there statically
; so it can use subroutines to save code space
; returns A=score
szero   .equ 30     ; zero value for heuristic score
scenter .equ 3      ; +3 for pieces in center col
srun3   .equ 5      ; +5 for run of length 3
srun2   .equ 2      ; +2 for run of length 2
sorun3  .equ 96     ; -4 for opponent run of length 3
score1
  mov szero,A<->C   ; C=zero score

  ; apply center column bonus
  mov 3,A
  jsr s_bonus       ; check row 1 
  mov 10,A
  jsr s_bonus       ; check row 2
  mov 17,A
  jsr s_bonus       ; check row 3
  mov 24,A
  jsr s_bonus       ; check row 4
  mov 31,A
  jsr s_bonus       ; check row 5
  mov 38,A
  jsr s_bonus       ; check row 6

  ; count horizontal runs
  ; B=offset, C=score, D=player|empty, E=column
  clr A
  swap A,B          ; B=offset (0)
score1_h
  mov B,A
  add dboardsize,A  ; test offset with boardsize
  jn score1_h_out   ; if offset>boardsize, done
  clr A
  swap A,D          ; D=player|empty (00)
  clr A
  swap A,E          ; E=column (0)
score1_row
  mov E,A
  add 96,A          ; test column with 4 
  jn score1_row_u   ; if column>=4, must uncount col-4
  jmp score1_row_c
score1_row_u
  mov B,A
  add 96,A          ; offset-=4
  swap A,B
  jsr s_uncount     ; ok if A sign is M
  swap B,A
  add 4,A           ; offset+=4
  swap A,B
score1_row_c
  jsr s_count       ; count at offset, update score
  swap B,A
  inc A             ; offset += 1
  swap A,B
  swap E,A
  inc A             ; column += 1
  mov A,E
  add 93,A          ; test column with 7
  jn score1_h       ; if column>=7 start of new row
  jmp score1_row
score1_h_out

  ; count vertical runs
  ; B=offset, C=score, D=player|empty, E=row
  mov 41,A<->B      ; B=offset, score1_v will init to 0
score1_v
  swap B,A
  add 59,A          ; offset-=41 (top of next column)
  swap A,B          ;
  mov B,A           ; fix sign
  add 93,A          ;
  jn score1_v_out   ; if offset>=7, done
  clr A
  swap A,D          ; D=player|empty (00)
  clr A
  swap A,E          ; E=row (0)
score1_col
  mov E,A
  add 96,A          ; test row with 4 
  jn score1_col_u   ; if row>=4, must uncount row-4
  jmp score1_col_c
score1_col_u
  mov B,A
  add 72,A          ; offset-=4*7
  swap A,B
  jsr s_uncount     ; ok if A sign is M
  swap B,A
  add 28,A          ; offset+=4*7
  swap A,B
score1_col_c
  jsr s_count       ; count at offset
  swap B,A
  add 7,A           ; offset += 7
  swap A,B
  swap E,A
  inc A             ; row += 1
  mov A,E
  add 94,A          ; test row with 6
  jn score1_v       ; if row>=6 start of new col
  jmp score1_col
score1_v_out

  ; count right \ diagonal runs
drstart .table 14, 7, 0, 1, 2, 3

  ; B=offset, C=score, D=player|empty, E=row, [tmp]=diag#
  mov tmp,A<->B
  mov 6,A
  mov A,[B]         ; initialize diag#
score1_dr
  clr A
  swap A,D          ; D=0 prior to ftl
  mov tmp,A<->B     ;
  mov [B],A         ; get diag#
  jz score1_dr_out  ; if diag#==0, all done 
  dec A
  mov A,[B]         ; diag#-=1
  add drstart,A
  ftl A,D           ; lookup start of r-diagonal
  clr A
  swap D,A          ; D=player|empty (00)
  mov A,B           ; B=start offset
  clr A
  swap A,E          ; E=row (0)
score1_dr_row
  mov E,A
  add 96,A          ; test row with 4 
  jn score1_dr_u    ; if row>=4, must uncount row-4
  jmp score1_dr_c
score1_dr_u
  mov B,A
  add 68,A          ; offset-=4*8
  swap A,B
  jsr s_uncount     ; ok if A sign is M
  swap B,A
  add 32,A          ; offset+=4*8
  swap A,B
score1_dr_c
  jsr s_count       ; count at offset
  ; skip down to next column in next row of diagonal
  swap B,A
  add 8,A           ; offset += 8
  mov A,B
  ; most right diagonals will end >= end of board
  add dboardsize,A  ; compare offset with boardsize
  jn score1_dr      ; if offset>=boardsize, done
  ; the diagonal (3,11,19,27) ends at 35 
  mov B,A           ;
  add 65,A          ; compare with 35 (lower left)
  jz score1_dr      ; if offset==lower left, wrapped (done)
  clr A
  swap E,A
  inc A             ; row += 1
  swap A,E
  jmp score1_dr_row ; next row
score1_dr_out

  ; count left / diagonal runs
dlstart .table 20, 13, 6, 5, 4, 3

  ; B=offset, C=score, D=player|empty, E=row, [tmp]=diag#
  mov tmp,A<->B
  mov 6,A
  mov A,[B]         ; initialize diag#
score1_dl
  clr A
  swap A,D          ; D=0 prior to ftl
  mov tmp,A<->B     ;
  mov [B],A         ; get diag#
  jz score1_dl_out  ; if diag#==0, all done 
  dec A
  mov A,[B]         ; diag#-=1
  add dlstart,A
  ftl A,D           ; lookup start of l-diagonal
  clr A
  swap D,A          ; D=player|empty (00)
  mov A,B           ; B=start offset
  clr A
  swap A,E          ; E=row (0)
score1_dl_row
  mov E,A
  add 96,A          ; test row with 4 
  jn score1_dl_u    ; if row>=4, must uncount row-4
  jmp score1_dl_c
score1_dl_u
  mov B,A
  add 76,A          ; offset-=4*6
  swap A,B
  jsr s_uncount     ; ok if A sign is M
  swap B,A
  add 24,A          ; offset+=4*6
  swap A,B
score1_dl_c
  jsr s_count       ; count at offset
  ; skip down to next column in next row of diagonal
  swap B,A
  add 6,A           ; offset += 6
  mov A,B
  ; most left diagonals will end >= 41
  add 59,A          ; compare offset with 41
  jn score1_dl      ; if offset>=41, done
  ; the diagonal (4,10,16,22,28) ends at 34
  mov B,A           ;
  add 65,A          ; compare with 34
  jz score1_dl      ; if offset==34, wrapped (done)
  ; the diagonal (3,9,15,21) ends at 27
  mov B,A           ;
  add 73,A          ; compare with 27
  jz score1_dl      ; if offset==27, wrapped (done)
  clr A
  swap E,A
  inc A             ; row += 1
  swap A,E
  jmp score1_dl_row ; next row
score1_dl_out
  swap C,A          ; return score
  jmp far score1_ret

; add to counts from board at [B]
s_count
  mov [B],A
  jz s_count0       ; if board==0, count 0
  dec A
  jz s_count1       ; if board==1, count 1
  ret
s_count0
  swap D,A
  inc A             ; D += 01 (empty)
  swap A,D
  mov E,A
  add 97,A          ; test size with 3
  jn s_addscore     ; if size>=3, add to score
  ret
s_count1
  swap D,A
  add 10,A          ; D += 10 (player1)
  swap A,D
  mov E,A
  add 97,A          ; test size with 3
  jn s_addscore     ; if size>=3, add to score
  ret

; remove counts from board at [B]
s_uncount
  mov [B],A
  jz s_uncount0     ; if board==0, uncount 0
  dec A
  jz s_uncount1     ; if board==1, uncount 1
  ret
s_uncount0
  swap D,A
  dec A             ; D -= 01 (empty)
  swap A,D
  ret
s_uncount1
  swap D,A
  add 90,A          ; D -= 10 (player1)
  swap A,D
  mov D,A           ; clear spurious - sign
  ret

; adjust score based on piece counts
s_addscore
  mov D,A           ; get counts in A
  add 60,A
  jz s_win          ; if counts==4(player)0(empty), win
  mov D,A
  add 69,A
  jz s_run3         ; if counts==3(player)1(empty), run of 3
  mov D,A
  add 78,A
  jz s_run2         ; if counts==2(player)2(empty), run of 2
  mov D,A
  dec A
  jz s_opprun3      ; if counts==0(player)1(empty), opponent run of 3
  ret
s_run3
  swap C,A
  add srun3,A       ; score += srun3 bonus
  swap A,C
  ret
s_run2
  swap C,A
  add srun2,A       ; score += srun2 bonus
  swap A,C
  ret
s_opprun3
  swap C,A
  add sorun3,A      ; score -= 4
  swap A,C
  mov C,A           ; fix bogus sign
  ret
s_win
  mov 99,A          ; score=99
  jmp far score1_ret ; short-circuit return

; add bonus to score if piece at A is player1
s_bonus
  swap A,B
  mov [B],A         ; check piece at position
  dec A
  jz s_bonus_yes    ; if player1, apply bonus
  ret
s_bonus_yes
  swap C,A
  add scenter,A     ; apply center column bonus
  swap A,C
  ret

  .org 308

; print out the game board and winner for debugging
; prints one piece per card AABB (A=piece, B=address) then 99BB (B=winner)
printb
  clr A
  swap A,B          ; B=0 (board data)
printb_loop
  mov [B],A         ; read word of board
  jz printb_skip    ; if nothing here, skip
  print             ; print AABB (A=piece, B=address)
printb_skip
  swap A,B          ;
  inc A             ; next word of board
  mov A,B
  add dboardsize,A  ; test if A==42 (42+58=100)
  jz printb_out     ; if end of board, done
  jmp printb_loop
printb_out
  mov winner,A<->B
  mov [B],A<->B     ; winner in B
  mov 99,A          ; A=99 flags end of board
  print
  ret

; play move in column# for player
; A=column# (1-7) D=player
move
  dec A             ; compute top of column offset
  swap A,C          ; C=offset to play
  mov tmpcol,A<->B  ; spill column offset into [tmpcol]
  mov C,A           ;
  mov A,[B]         ;
  swap A,B          ; B=next offset in column (+1 row)
  mov [B],A         ; check top of column
  jz move_drop      ; if top of col has room, drop piece
  mov 98,A          ; column full
  jmp error
move_drop
  mov C,A           ; A=current offset
  add 7,A           ; calc next row offset
  mov A,B           ;
  add dboardsize,A  ; test if offset>=42 
  jn move_place     ; if past end of board, place at bottom
  mov [B],A         ; check if next row empty
  jz move_next      ; if so, keep scanning
  jmp move_place    ; if nonempty, C is where to play
move_next
  swap B,A          ;
  swap A,C          ; cur offset = next offset
  jmp move_drop
move_place
  clr A             ; needed when A<0
  swap C,A          ; C<->A<->B
  swap A,B          ; B=offset for piece
  swap D,A          ; A=player
  mov A,[B]         ; store piece for player
  swap A,D          ; D=player
  swap A,B
  swap A,E          ; E=move offset

; update winner based on the piece just played
; D=player, E=move offset, [tmpcol]=column offset

  ; check move column for win
  clr A
  swap A,C          ; C=0 (run length)
  mov tmpcol,A<->B  ;
  mov [B],A<->B     ; B=column offset from [tmpcol]
win_col
  mov [B],A         ; A=piece at [offset]
  sub D,A           ; A-=player
  jz win_col_run    ; if A==player, count towards run
  clr A             ; else reset run length
  swap A,C          ;   (C=0)
  jmp win_col_next
win_col_run
  swap C,A          ; A=0 so safe to swap
  inc A             ;
  mov A,C           ; C+=1 (count run)
  add 96,A          ;
  jz win_won        ; if run length == 4, player won
win_col_next        ; advance to next  row
  swap B,A          ; A is known + here, so safe to swap
  add 7,A           ;
  mov A,B           ; offset += 7
  add dboardsize,A  ; check if offset past end of board
  jn win_col_done   ; if past end, done scanning col
  jmp win_col
win_col_done

  ; check move row for win
rowstart .table 0,0,0,0,0,0,0, 7,7,7,7,7,7,7, 14,14,14,14,14,14,14, 21,21,21,21,21,21,21, 28,28,28,28,28,28,28, 35,35,35,35,35,35,35

  swap D,A
  swap A,C          ; stash player in C
  clr A
  swap A,D          ; clear D prior to ftl
  mov tmp,A<->B     ; B=tmp
  mov E,A           ; A=move offset (0-41)
  mov A,[B]         ; spill move offset into [tmp]
  add rowstart,A    ; A+=rowstart (base of table)
  ftl A,D           ; lookup row offset
  swap D,A
  swap A,B          ; B=row offset
  swap C,A
  swap A,D          ; D=player
  clr A
  swap A,C          ; C=0 (run length)
  mov 7,A<->E       ; E=7 (columns)
win_row
  mov [B],A         ; A=piece at [offset]
  sub D,A           ; A-=player
  jz win_row_run    ; if A==player, count towards run
  clr A             ; else reset run length
  swap A,C          ; C=0 (reset run)
  jmp win_row_next
win_row_run
  swap C,A          ; A=0 so safe to swap
  inc A             ; C+=1 (count run)
  mov A,C           ; (save run length)
  add 96,A          ;
  jz win_won        ; if run length == 4, player won
win_row_next
  swap B,A          ; A is known + here, so safe to swap
  inc A             ; offset+=1
  swap A,B          ;
  swap A,E
  dec A             ; column-=1
  jz win_row_done   ; if examined 7 columns, done
  swap A,E          ; (store back column)
  jmp win_row
win_row_done

  ; check move \ diagonal for win
  mov tmpcol,A<->B  ;
  mov [B],A<->E     ; E=column offset from [tmpcol]
  mov tmp,A<->B     ;
  mov [B],A<->B     ; B=move offset from [tmp]
  ; rewind to upper left of diagonal
win_ul0
  mov E,A
  jz win_ul0_done   ; if column==0, at start
  dec A
  swap A,E          ; column -= 1
  mov B,A
  add 92,A          ; offset-=8 (setting sign if A>=8)
  jn win_ul0_prev   ; if A>=8, check next column
  jmp win_ul0_done  ; would go off top row
win_ul0_prev
  swap A,B          ; B=updated start offset
  mov B,A           ; A=start offset; also clear sign
  jmp win_ul0
win_ul0_done        ;
  ; scan down diagonal (B=start offset, E=column)
  clr A
  swap A,C          ; C=run length (0)

win_ul
  mov [B],A         ; read piece at offset
  sub D,A           ; A-=player
  jz win_ul_run     ; if A==player, count towards run
  clr A             ; else reset run length
  swap A,C          ; C=0 (reset run)
  jmp win_ul_next
win_ul_run
  swap C,A          ; A=0 so safe to swap
  inc A             ;
  mov A,C           ; C+=1 (count run)
  add 96,A          ;
  jz win_won        ; if run length == 4, player won
win_ul_next
  swap B,A          ; A is known + here, so safe to swap
  add 8,A           ; offset+=8
  mov A,B
  add dboardsize,A  ;
  jn win_ul_done    ; if A>=42, past last row of board
  swap E,A
  inc A             ; column+=1
  mov A,E
  add 93,A          ; compare A with 7
  jn win_ul_done    ; if column>=7, past last col of board
  jmp win_ul
win_ul_done

  ; check move / diagonal for win
  mov tmpcol,A<->B  ;
  mov [B],A<->E     ; E=column offset from [tmpcol]
  mov tmp,A<->B     ;
  mov [B],A<->B     ; B=move offset from [tmp]
  ; rewind to upper right of diagonal
win_ur0
  mov E,A
  add 94,A
  jz win_ur0_done   ; if column==6, at start
  swap E,A
  inc A
  swap A,E          ; column += 1
  mov B,A
  add 94,A          ; A-=6 (setting sign if A>=6)
  jn win_ur0_prev   ; if A>=6, check next column
  jmp win_ur0_done  ; would go off top row
win_ur0_prev
  swap A,B          ; B=updated start offset
  mov B,A           ; A=start offset; also clear sign
  jmp win_ur0
win_ur0_done        ;
  ; scan down diagonal (B=start offset, E=column)
  clr A
  swap A,C          ; C=run length (0)

win_ur
  mov [B],A         ; read piece at offset
  sub D,A           ; A-=player
  jz win_ur_run     ; if A==player, count towards run
  clr A             ; else reset run length
  swap A,C          ; C=0 (reset run)
  jmp win_ur_next
win_ur_run
  swap C,A          ; A=0 so safe to swap
  inc A             ;
  mov A,C           ; C+=1 (count run)
  add 96,A          ;
  jz win_won        ; if run length == 4, player won
win_ur_next
  swap B,A          ; A is known + here, so safe to swap
  add 6,A           ; offset+=6
  mov A,B
  add dboardsize,A  ;
  jn win_ur_done    ; if A>=42, past last row of board
  swap E,A
  dec A             ; column-=1
  jn win_ur_done    ; if column<0, past first col of board
  swap A,E          ; save column
  jmp win_ur
win_ur_done

  ; if move was in top row, check for draw (after all possible wins)
  mov tmp,A<->B     ;
  mov [B],A         ; A=move offset from [tmp]
  add 93,A
  jn win_none       ; if A>=7 then no draw possible
  mov 6,A<->B       ; B=end of first row
win_check_draw
  mov [B],A         ; check top of col
  jz win_none       ; if empty no draw
  swap B,A          ; 
  dec A             ; offset -= 1
  jn win_draw
  swap A,B          ; save offset
  jmp win_check_draw

win_draw
  mov winner,A<->B  ; B=winner
  mov 3,A           ; A=3
  mov A,[B]         ; set [winner] to player
  ret
win_won
  mov winner,A<->B  ; B=winner
  swap D,A          ; A=player
  mov A,[B]         ; set [winner] to player
  ret
win_none
  mov winner,A<->B  ; B=winner
  clr A             ; A=0
  mov A,[B]         ; set [winner] to player
  ret

; undo the last move in column
; A=column (1-7)
undo_move
  dec A             ;
  swap A,B          ; B=top of column offset
undo_move_scan
  mov [B],A         ; get piece here
  jz undo_move_next ; if empty, keep scanning
  jmp undo_move_out ; found piece
undo_move_next
  add 7,A           ; move down one row
  swap A,B
  add dboardsize,A  ; past end of column?
  jn undo_move_err  ; if so, error out
  jmp undo_move_scan
undo_move_out
  clr A
  mov A,[B]         ; remove piece
  ; search stops at the first winning move so undoing the last move
  ; clears any win (or a draw)
  mov winner,A<->B  ; B=winner
  clr A
  mov A,[B]         ; set [winner] to 0
  ret

undo_move_err
  mov 97,A          ; past end of column
  jmp error

; print an error code and halt
error
  mov A,B
  print
  print
  print
  halt