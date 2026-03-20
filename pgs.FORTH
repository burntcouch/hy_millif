
 : 2dup over over ;
 : 2drop drop drop ;

 : alloc here @ + here ! ;

 : 2* dup + ;
 : >r rp @ @ swap rp @ ! rp @ 2 - rp ! rp @ ! ;
 : r> rp @ @ rp @ 2 + rp ! rp @ @ swap rp @ ! ;
 
 : branch rp @ @ dup @ + rp @ ! ;
 : ?branch 0# not rp @ @ @ 2 - and rp @ @ + 2 + rp @ ! ;
 : lit rp @ @ dup 2 + rp @ ! @ ;
 : ['] rp @ @ dup 2 + rp @ ! @ ;
 
 : if ['] ?branch , here @ 0 , ; I
 : then dup here @ swap - swap ! ; I
 : else ['] branch , here @ 0 , swap dup here @ swap - swap ! ; I
 
 : begin here @ ; I
 : again ['] branch , here @ - , ; I
 : until ['] ?branch , here @ - , ; I
 : while ['] ?branch , here @ 0 , ; I
 : repeat swap ['] branch , here @ - , dup here @ swap - swap ! ; I
 
 : do here @ ['] >r , ['] >r , ; I
 : loop ['] r> , ['] r> , ['] lit , 1 , ['] + , ['] 2dup , ['] = , ['] ?branch , here @ - , ['] 2drop , ; I
 
 : 0fh lit [ 4 4 4 4 + + + 1 - , ] ;
 : ffh lit [ 0fh 2* 2* 2* 2* 0fh or , ] ;
 : c@ @ ffh and ;
 : in> >in @ c@ >in dup @ 1 + swap ! ;
 : bl lit [ 1 2* 2* 2* 2* 2* , ] ;
 
 : type 0 do dup c@ emit 1 + loop drop ;
 : parse in> drop >in @ swap 0 begin over in> <> while 1 + repeat swap bl = if >in dup @ 1 - swap ! then ;
 : word in> drop begin dup in> <> until >in @ 2 - >in ! parse ;
 : [char] ['] lit , bl word drop c@ , ; I
 : ." [char] " parse type ; I

 : ( [char] ) parse drop drop ; I
 
 : create here @ : ['] lit , here @ 4 + , ['] exit , 0 s@ ! last ! ; 
 : cells lit [ 2 , ] ;
 : allot here @ + here ! ;
 : variable create cells allot ;
 
  ." Hello world !" cr
