;
;  training data
;
ftrain_0:
.byte ": 2* dup + ;"
.byte 0
.byte ": ?branch nb not rp @ @ @ 2 - and rp @ @ + 2 + rp @ ! ;  : branch rp @ @ dup @ + rp @ ! ;"
.byte 0
.byte ": if lit ?branch , here @ 0 , ; I"
.byte 0
.byte ": then dup here @ swap - swap ! ; I"
.byte 0
.byte ": else lit branch , here @ 0 , swap dup here @ swap - swap ! ; I"
.byte 0
.byte ": begin here @ ; I"
.byte 0
.byte ": again lit branch , here @ - , ; I"
.byte 0
.byte ": until lit ?branch , here @ - , ; I"
.byte 0
.byte ": while lit ?branch , here @ 0 , ; I"
.byte 0
.byte ": repeat swap lit branch , here @ - , dup here @ swap - swap ! ; I"
.byte 0
.byte ": do here @ lit >r , lit >r , ; I"
.byte 0
.byte ": loop lit r> , lit r> , lit lit , 1 , lit + , lit 2dup , lit = , lit ?branch , here @ - , lit 2drop , ; I"
.byte 0
.byte ": i rp @ 4 + @ ;  : j rp @ 8 + @ ;"
.byte 0
.byte ": create here @ : lit lit , here @ 4 + , lit exit , 0 s@ ! last ! ;"
.byte 0
.byte ": variable create cells allot ;"
.byte 0
.byte ": type 0 do dup c@ emit 1 + loop drop ;"
.byte 0
.byte ": parse in> drop >in @ swap 0 begin over in> <> while 1 + repeat swap spc = if >in dup @ 1 - swap ! then ;"
.byte 0
.byte ": word in> drop begin dup in> <> until >in @ 2 - >in ! parse ;"
.byte 0
.byte ": [char] lit lit , spc word drop c@ , ; I"
.byte 0
.byte ": ."
.byte $22
.byte " [char] "
.byte $22
.byte " parse type ; I"
.byte 0
.byte ": ( [char] ) parse drop drop ; I"
.byte 0, 0                               ; to mark end?           
ftrain_end0:
