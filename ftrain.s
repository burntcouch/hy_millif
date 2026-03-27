;
;  training data
;
ftrain_0:
.byte ": 2* dup + ;"
.byte 0
.byte ": branch rp @ @ dup @ + rp @ ! ;"
.byte 0
.byte ": ?branch 0# invert rp @ @ @ 2 - and rp @ @ + 2 + rp @ ! ;"
.byte 0
.byte ": ['] rp @ @ dup 2 + rp @ ! @ ;"
.byte 0
.byte ": if ['] ?branch , here @ 0 , ; I"
.byte 0
.byte ": then dup here @ swap - swap ! ; I"
.byte 0
.byte ": else ['] branch , here @ 0 , swap dup here @ swap - swap ! ; I"
.byte 0
.byte ": begin here @ ; I"
.byte 0
.byte ": again ['] branch , here @ - , ; I"
.byte 0
.byte ": until ['] ?branch , here @ - , ; I"
.byte 0
.byte ": while ['] ?branch , here @ 0 , ; I"
.byte 0
.byte ": repeat swap ['] branch , here @ - , dup here @ swap - swap ! ; I"
.byte 0
.byte ": do here @ ['] >r , ['] >r , ; I"
.byte 0
.byte ": loop ['] r> , ['] r> , ['] lit , 1 , ['] + , ['] 2dup , ['] = , ['] ?branch , here @ - , ['] 2drop , ; I"
.byte 0
.byte ": type 0 do dup c@ emit 1 + loop drop ;"
.byte 0
.byte ": parse in> drop >in @ swap 0 begin over in> <> while 1 + repeat swap spc = if >in dup @ 1 - swap ! then ;"
.byte 0
.byte ": word in> drop begin dup in> <> until >in @ 2 - >in ! parse ;"
.byte 0
.byte ": [char] ['] lit , spc word drop c@ , ; I"
.byte 0
.byte ": ."
.byte $22
.byte " [char] "
.byte $22
.byte " parse type ; I"
.byte 0
.byte ": ( [char] ) parse drop drop ; I"
.byte 0
.byte ": create here @ : ['] lit , here @ 4 + , ['] exit , 0 s@ ! last ! ;"
.byte 0
.byte ": variable create cells allot ;"
.byte 0
.byte '.',$22
.byte " DONE!"
.byte $22, 0, 0                      ; to mark end?           
ftrain_end0:
