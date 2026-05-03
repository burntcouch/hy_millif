# HyForth for 6502
<h2>Hydra-16 version of MilliForth</h2>
----------------------------------------------------------------------
<p>
  Patrick Struthers - March 2026
<p>
      - THANKS to AGSB (https://github.com/agsb) for the starting point here....<p>
   MilliForth 6502 --> (https://github.com/agsb/milliForth-6502)
<p>
----------------------------------------------------------------------
<p>  
Update, 5/3/26:
<p> Hell of a lot has changed in a month or so.  ROM conversion still works as noted below in 3/21/26 notes, and installation now proceeds very simply: </p>
<p> -- change to appropriate ROM bank in Wozmon (I use bank $03 for testing most of the time) by saving the bank number to location ZP $01 --  e.g '1:3' in Wozmon if you are using bank $03.</p>
<p> -- Run the COPYTORAM routine from the jmp point at A003.  'A003R' in Wozmon.</p>
<p> -- Start HyForth at $0800 by entering '800R'</p>
<p>   You will see a 'HyForth 0.xx MMDDYY' version banner and then the HF> prompt. </p>
----------------------------------------------------------------------
<p>   As you can below, a lot of words have been added in the last month and a half; the list is a screenshot of the output of 'words' on the most current version (0.88 5/2/26).</p>
<p>  The list is only very loosely organized at this time, into 4 main sections:</p>
<p> CORE:  starting with 'bye' and 'abort', the basic stack access words up to about 'lit', 'var', and 'cons' ... and at the end of the list the rest of the essenstial words for basic Forthiness:  'I' ('immediate'), [, ], ',', ';', ':' (the compiler), @, ! and lastly 'exit'. </p>
<p>  PRIMITIVES:  the interpreter includes functions to handle inline #'s and text, but for speed and efficiency reasons all 'single digit' #'s (whether decimal, binary, or hex) have explicit definitions in native code, thus '0' - '9', '-1' - '-9', '$0' - '$F', '%0' and '%1'.  Also all of the conditionals are defined, as well as the basic logic functions.  'negate' and 'invert' as defined in traditional Forth have been changed to 'neg' and 'not', and AGSB's '0#' was changed to 'bool' (to convert the TOS value to it's boolean equivalent).  Most of the stack manipulation functions are also in the group, such as 'dup' and 'swap' but including more tricky ones such as 'pick' (indexed stack access) and 'snip' (remove bottomost cell from stack).</p>
<p>  ADDITIONAL STUFF:  I could not do without '*' and '/' for very long so I found very efficient 6502 algorithms for those; both return a 32-bit value; in the case of '/' this includes both the division result and the remainder...so 'mod' is just '/ swap drop'.  '*' always gives a 32 bit result with the LSW on top of the stack.</p>
<p>  This group also includes a lot of debugging tools, including a disassembler, 'syscall' for system calls, a random # generator, some ANSI screen functions ('Ascr', 'Acls', 'Acol'), and the basic parts of the memory manager:  'malloc', 'mlen', 'mktemp', and 'purge'.  'dump' and 'debug' are mixed in with the CORE group but the former has also been generalized to dump any page in memory rather than just showing a binary dump of the heap, and also formatted to be more readable.  'debug' toggles the ROM routine 'DUMPREG' to non-invasively dump the status and PC/SP/A/X/Y registers, as well as options for looking at the hardware stack, zero page, TIB, and DS/RT stack areas.</p>
<p>  Lastly, you will see 'cload', 'autoload' and 'bload'.  These three words are the essential for loading extra 'meta-compiler' words and binary libraries.</p>
<p>  META-COMPILED WORDS:  the traditional Forth conditionals and loop structures are NOT easy to implement in native code using AGSB's engine, so for now these are loaded (using 'cload' or 'autoload').  These include 'if', 'then', 'else', 'do', 'loop', 'begin', 'again', 'repeat', 'until', and 'while', as well as the 'i/j/k' loop indexes. </p>
<pre>
 1BE7: |          | 1BDF: |          | 1BCA: decsz!     | 1BB4: mdump      |
 1BA6: k          | 1B96: j          | 1B86: i          | 1B41: loop       |
 1B2A: do         | 1B01: repeat     | 1AE9: while      | 1AD1: until      |
 1AB9: again      | 1AAB: begin      | 1A84: else       | 1A6D: then       |
 1A58: if         | 1A3B: branch     | 1A0B: ?branch    | 1A00: 2*         |
 194A: exit       | 1916: :          | 18FA: ;          | 18DE: ,          |
 18D3: ]          | 18CA: [          | 18AC: I          | 1876: @          |
 1862: !          | 185A: ;$         | 1852: :$         | 1845: exec       |
 181B: mlen       | 1793: malloc     | 1745: purge0     | 172B: mktemp     |
 1704: syscall    | 16D5: disasm     | 16BB: free       | 168F: memcpy     |
 167B: xdrv       | 1638: /          | 160C: *          | 15F1: max        |
 15C4: min        | 159F: rand32     | 1592: rand       | 1571: rseed      |
 1542: Acol       | 14F8: Ascr       | 14DA: Acls       | 144C: bload      |
 13E9: cload      | 13A3: autoload   | 1347: snip       | 1313: pick       |
 12E6: 2over      | 12D5: 2drop      | 12B9: 2dup       | 12A0: tuck       |
 128E: nip        | 1275: over       | 125A: rot        | 1245: xR         |
 1230: xS         | 1223: drop       | 1214: dup        | 11F9: swap       |
 11DE: <          | 11C2: >=         | 11A4: <=         | 117C: >          |
 116B: 0=         | 1152: =          | 1138: <>         | 111C: neg        |
 1106: not        | 10ED: xor        | 10D5: or         | 10BC: and        |
 10B2: %1         | 10A8: %0         | 109E: $F         | 1094: $E         |
 108A: $D         | 1080: $C         | 1076: $B         | 106C: $A         |
 1060: -9         | 1054: -8         | 1048: -7         | 103C: -6         |
 1030: -5         | 1024: -4         | 1018: -3         | 100C: -2         |
 1001: 0          | 0FF9: $0         | 0FED: -1         | 0FE4: 9          |
 0FDA: $9         | 0FD1: 8          | 0FC7: $8         | 0FBE: 7          |
 0FB4: $7         | 0FAB: 6          | 0FA1: $6         | 0F98: 5          |
 0F8E: $5         | 0F85: 4          | 0F7B: $4         | 0F72: 3          |
 0F68: $3         | 0F5F: 2          | 0F55: $2         | 0F48: 1          |
 0F40: $1         | 0E9E: cons       | 0E1B: var        | 0DFD: lit        |
 0DEE: spc        | 0DDD: cells      | 0DC9: c!         | 0DB6: c@         |
 0DA0: in>        | 0D90: r>         | 0D80: >r         | 0D6E: memptr     |
 0D65: rp         | 0D5C: sp         | 0D51: back       | 0D46: here       |
 0D3B: last       | 0D2A: >in        | 0D18: cr         | 0CFF: debug      |
 0CF1: s@         | 0CDA: bool       | 0CC1: -          | 0CA9: +          |
 0C8B: nand       | 0C79: emit       | 0C69: key        | 0C23: cbit       |
 0C01: sbit       | 0BD3: tbit       | 0BB6: <<         | 0B99: >>         |
 0B82: decs!      | 0B27: rdcstk!    | 0AFA: dcstk!     | 0AC8: dwstk!     |
 0A89: dsget@     | 0A56: dsgetn@    | 0A29: .sz        | 09F9: ord        |
 09E4: .C         | 09CB: .          | 0911: words      | 08E9: dump       |
 0882: .R         | 0869: ?R         | 0850: ?S         | 0822: .S         |
 0817: reset      | 080C: abort      | 0803: bye        |

  
</pre>
<p>
<pre>
LATEST CHANGES (3/21/26):
     ROM conversion is now done; this version resides almost entirely at $A000 and on;
  The 'COPYTOROM' routine at $A003 will load the dictionary into RAM at $0600, and 
  running from there will bring up HyForth with all the primitives and added words
  from 'hywords.s' into RAM.  Current RAM footprint is less than 2K, and ROM usage is
  around 3K with test scripts.  Zeropage usage is 38 bytes total, from $D8-$FB.
     And a lot MORE stuff.  All of the numerical conversions now work; a lot more hard-
   coded words, including:  2drop, 2dup, 2over, r>, >r, nip, tuck, xR (clear return
   stack), allot, sp, rp, >in, last, here, cr.
     More importantly, 'cload' will now load all of the scripts for compiled test words
  sequentially; usage is '$xxxx cload', where xxxx is the address of a zero terminated
  string of Forth words.  The 'ftrain.s' file is assembled into ROM as part of the 
  overall build, and the first word, '2*', ends up at $A5B9.  cload will automatically
  push the address of the next string onto the stack, so after you load the first
  one in the list you just type 'cload' until you've got them all loaded.
    AGAIN, this is now a stable, full featured forth, after the test words are loaded;
a lot still needs to be done with machine-coded words but we're getting there...
------------------------------------------------------------------------------------
LATEST CHANGES (3/14/26):
    A lot of the 'training' words in the my_bf.FORTH file have now been hardcoded, 
  include digits 0-9, -1 to -9, $A-F, %0 and %1 (binary digits); drop, dup, rot, over, 
  swap; xS (clear data stack); <, >, >=, <=, =, <>; not, and, or, xor, neg; .C (prints
   two characters packed in word).  I renamed the following:  .S / .R for %S / %R; << 
   and >> for asl / lsr - these latter now do multiple bit shifts, a la:
          ( w n -- w&lt;&lt;n )  and similar for &gt;&gt;
------------------------------------------------------------------------------------
    Decimal to 'word' conversions now working fine, and binary/hex are just around the 
  corner.  Per design, none of these will work as bare words inside a compiled word,
  but we are working on hardcoding literals (both numbers and strings).
     SIZE-WISE:  with all of the new hardcoded words and the number conversions, the 
  RAM code (engine, primitives and words) comes in at around 3K, with a lot of scope 
  for optimization.  Very promising if the other essential things like branch, IF/THEN,
  DO/LOOP, BEGIN...UNTIL/WHILE etc, as well as literals and CREATE can all be wedged-in.
     LOAD and SAVE for both hardcoded and compiled words also need to be done.  Just 
  hoping this stays under 8K at this point; ROM conversion down the road a bit, but 
  will help.
</pre>
-------------------------------------------------------------<p>
-------------------------------------------------------------<p>
  
<pre>
INSTALLATION:
This is a very simple system, so....it is a little bit messy to set up 
  right now.

Essentially, we want to generate a RAM image of the running HyForth image
at $0600 by switching to the ROM, running the COPYTORAM routine (at 
approximately $A900), then starting HyForth at $0600 through WozMon.  The input 
buffer stack (TIB) is the entire page at $0400, with the DS and RT stacks
splitting $0500.  Currently the end of the hardcoded word dictionary comes out
at about $1100, with user-compiled words extending above that.

The Hydra-16 maps ROM chips into one of 256 16K banks, any one of which
will show up at $A000 depending on the selected bank.  These are selected
by putting the bank # at zeropage
address $01...more or less.

The 'more' is that they work, the 'less' is that you have to find the 
bank.  Due to a flaw in the design of the 1.8C vesion of Hydra-16 (only 
one with extant hardware), you have to offset the upload of your ROM 
image by $2000, and then copy any data that spills over <base address + 
$4000> back to the $0000 offset of your base address for the bank.

Example:  My port of MSBASIC is approximately 11K at this point; if I am 
loading it in the first bank on the first ROM chip, I use Xgpro to load 
the binary at $2000, and then I cut and paste $4000 to ~ $5C00 to $0000 
on the ROM.  If this is done carefully the code will mate together fine 
when it is plugged in.  If you make sure $00 is loaded to ZP $01 then 
your code will start at $A000.

HyForth itself...almost 99% works.  I added a lot of debugging code to 
discover the various problems with the port, and renamed many of the ZP 
variable labels and jump/branch points for more clarity.
Needless to say it is no longer 100% 'classic', according to AGSB's 
interpretation of Forth design standards.

One of the most difficult issues with the original source, is that AGSB 
assumes that the zero page and the page for the TIB (text input buffer at
$0400, labeled INBUF in this version) to be preset to $00.  He also 
expected the zero-page area ($E0-$FF) used for most of the variables in 
this version to start at 
zero....

So I wrote a routine (since I was using a ROM routine to copy the Forth 
binary to $0500 anyway) to zero out those two areas.

The 'zeroout' code and the debugger for HyForth reside at the end of the 
Hydra-16 'task RAM' area, above $7000.  This will probably change soon, 
either so they reside in ROM HyForth itself does better at initialization.

=======================================================================

Training data for HyForth is included in the *.FORTH files along with
the assembly source code.  Cut-and-paste this data (carefully) a few 
lines at a time and you will have a pretty standard Forth implementation
in a few minutes.  There is still some fragility in the system due to 
lack of bounds and other sanity checks, but these will be addressed as 
the project progresses.

=======================================================================

My partners in this project, including Dan Struthers and others involved 
with testing and development for the Hydra-16 hardware and ROM design 
(https://github.com/danstruthers/hydra-16/tree/V1.8C), will be moving the 
functional core of HyForth entirely to ROM, along with a binary that will
load the base training data to make it a fully functional language.

In the meantime...please be free to take a look at this port and adapt it 
as necessary for your favority 6502-based SoC.  More when....
</pre>
<p>  
#see below for original intro from Sr. Barcellos
<p>
<p>----------------------------------------------------------------</p>
#From (https://github.com/burntcouch/hy_millif/blob/0.2/hy_millif.s)
<p>
<pre>
; ---------------------------------------------------------------------
;
;   A MilliForth for 6502 
;
;   original for the 6502, by Alvaro G. S. Barcellos, 2023
;
;   https://github.com/agsb 
;   see the disclaimer file in this repo for more information.
;
;   SectorForth and MilliForth was made for x86 arch 
;   and uses full 16-bit registers 
;
;   The way at 6502 is use page zero and lots of lda/sta
;
;   Focus in size not performance.
;
;   why ? For understand better my skills, 6502 code and thread codes
;
;   how ? Programming a new Forth for old 8-bit cpu emulator
;
;   what ? Design the best minimal Forth engine and vocabulary
  ;----------------------------------------------------------------------
;   Changes:
;
;   all data (36 cells) and return (36 cells) stacks, TIB (80 bytes) 
;       and PIC (32 bytes) are in same page $200, 256 bytes; 
;
;   TIB and PIC grows forward, stacks grows backwards;
;
;   no overflow or underflow checks;
;
;   the header order is LINK, SIZE+FLAG, NAME.
;
;   only IMMEDIATE flag used as $80, no hide, no compile;
;
;   As ANSI Forth 1994: FALSE is $0000 ; TRUE is $FFFF ;
;
;----------------------------------------------------------------------
;   Remarks:
;
;       this code uses 
;           Direct Thread Code, aka DTC or
;           Minimal Thread Code, aka MTC.
;
;       use a classic cell with 16-bits. 
;
;       no TOS register, all values keeped at stacks;
;
;       TIB (terminal input buffer) is like a stream;
;
;       Chuck Moore uses 64 columns, be wise, obey rule 72 CPL; 
;
;       words must be between spaces, before and after;
;
;       no line wrap, do not break words between lines;
;
;       only 7-bit ASCII characters, plus \n, no controls;
;           ( later maybe \b backspace and \u cancel )
;
;       words are case-sensitivy and less than 16 characters;
;
;       no need named-'pad' at end of even names;
;
;       no multiuser, no multitask, no checks, not faster;
;
;----------------------------------------------------------------------
;   For 6502:
;
;       a 8-bit processor with 16-bit address space;
;
;       the most significant byte is the page count;
;
;       page zero and page one hardware reserved;
;
;       hardware stack not used for this Forth;
;
;       page zero is used as pseudo registers;
;
;----------------------------------------------------------------------
;   For stacks:
;
;   "when the heap moves forward, move the stack backward" 
;
;   as hardware stacks do: 
;      push is 'store and decrease', pull is 'increase and fetch',
;
;   but see the notes for Devs.
;
;   common memory model organization of Forth: 
;   [INBUF->...<-DSPTR: user forth dictionary :NEXTHEAP->pad...<-RTPTR]
;   then backward stacks allow to use the slack space ... 
;
;   this 6502 Forth memory model blocked in pages of 256 bytes:
;   [page0][page1][page2][core ... forth dictionary ...NEXTHEAP...]
;   
;   At page2: 
;
;   |$00 INBUF> .. $50| <DSPTR..DSEND $98| <RTPTR..RTEND $E0|SCRIBB> ..$FF|
;
;   From page 3 onwards:
;
;   |$0300 cold:, warm:, forth code, init: here> heap ... tail| 
;
;   PIC is a transient area of 32 bytes 
;   PAD could be allocated from here
;
;----------------------------------------------------------------------
;   For Devs:
;
;   the hello_world.forth file states that stacks works
;       to allow : dup sp@ @ ; so sp must point to actual TOS.
;   
;   The movement will be:
;       pull is 'fetch and increase'
;       push is 'decrease and store'
;
;   Never mess with two underscore variables;
;
;   Not using smudge, 
;       colon saves "here" into "back" and 
;       semis loads "LASTHEAPest" from "back";
;
;   Do not risk to put stacks with $FF.
;
;   Also carefull inspect if any label ends with $FF and move it;
;
;   This source is hacked for use with Ca65.
;
;----------------------------------------------------------------------
;
;   Stacks represented as (standart)
;       S:(w1 w2 w3 -- u1 u2)  R:(w1 w2 w3 -- u1 u2)
;       before -- after, top at left.
;
;----------------------------------------------------------------------
;
</pre>
