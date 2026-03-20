;
;  training data
;
ftrain_0:
.byte ": 2dup over over ;"
.byte 0
.byte ": 2drop drop drop ;"
.byte 0
.byte ": , here @ ! here @ 2 + here ! ;"
.byte 0
.byte ": 2* dup + ;"
.byte 0
.byte ": 80h 1 7 << ;"
.byte 0
.byte ": immediate last @ 2 + dup @ 80h or swap ! ;"
.byte 0
.byte ": [ 0 s@ ! ; immediate"
.byte ": ] 1 s@ ! ;"
.byte 0
.byte ": >r rp @ @ swap rp @ ! rp @ 2 - rp ! rp @ ! ;"
.byte 0
.byte ": r> rp @ @ rp @ 2 + rp ! rp @ @ swap rp @ ! ;"
.byte 0
.byte ": branch rp @ @ dup @ + rp @ ! ;"
.byte 0
.byte ": ?branch 0# not rp @ @ @ 2 - and rp @ @ + 2 + rp @ ! ;"
.byte 0
.byte ": lit rp @ @ dup 2 + rp @ ! @ ;"
.byte 0
.byte ": ['] rp @ @ dup 2 + rp @ ! @ ;"
.byte 0
.byte ": rot >r swap r> swap ;"
.byte 0
.byte ": if ['] ?branch , here @ 0 , ; immediate"
.byte 0
.byte ": then dup here @ swap - swap ! ; immediate"
.byte 0
.byte ": else ['] branch , here @ 0 , swap dup here @ swap - swap ! ; immediate"
.byte 0
.byte ": begin here @ ; immediate"
.byte 0
.byte ": again ['] branch , here @ - , ; immediate"
.byte 0
.byte ": until ['] ?branch , here @ - , ; immediate"
.byte 0
.byte ": while ['] ?branch , here @ 0 , ; immediate"
.byte 0
.byte ": repeat swap ['] branch , here @ - , dup here @ swap - swap ! ; immediate"
.byte 0
.byte ": do here @ ['] >r , ['] >r , ; immediate"
.byte 0
.byte ": loop ['] r> , ['] r> , ['] lit , 1 , ['] + , ['] 2dup , ['] = , ['] ?branch , here @ - , ['] 2drop , ; immediate"
.byte 0
.byte ": 0fh lit [ 4 4 4 4 + + + 1 - , ] ;"
.byte 0
.byte ": ffh lit [ 0fh 2* 2* 2* 2* 0fh or , ] ;"
.byte 0
.byte ": c@ @ ffh and ;"
.byte 0
.byte ": in> >in @ c@ >in dup @ 1 + swap ! ;"
.byte 0
.byte ": bl lit [ 1 2* 2* 2* 2* 2* , ] ;"
.byte 0
ftrain_end0:
