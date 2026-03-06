# hy_millif
<h2>Hydra-16 version of MilliForth</h2>
----------------------------------------------------------------------
<p>
  Patrick Struthers - March 2026
<p>
      - THANKS to AGSB (https://github.com/agsb) for the starting point here....<p>
   MilliForth 6502 --> (https://github.com/agsb/milliForth-6502)
<p>
<p>  The HyForth project starts here with AGSB's core Forth engine;
  the engine will be moved to ROM and the heap will be copied to RAM
  on cold start.<p>
<p>  
<p>  The ulitmate purpose of working this port through is to develop a
  flexible and powerful operating system for the Hydra-16 of reasonable
  efficiency and minimal memory footprint.  HyForth will grow and 
  shrink in RAM footprint according to context.<p>
<p>
<pre>
INSTALLATION:
This is a very simple system, so....it is a little bit messy to set up 
  right now.

Essentially, we want to generate a RAM image of the running HyForth image
at $0500 by switching to the ROM, running the COPYTORAM routine (at 
approximately $A900), then starting HyForth at $0500 through WozMon.

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

One of the most difficult flaws in the original source, is that AGSB 
assumes that the zero page and the page for the TIB (text input buffer at
$0400, labeled INBUF in this version).  He also expected the zero-page area ($E0-$FF) used for most of the variables in this version to start at zero....

So I wrote a routine (since I was using a ROM routine to copy the Forth binary to $0500 anyway) to zero out those two areas.

The 'zeroout' code and the debugger for HyForth reside at the end of the 
Hydra-16 'task RAM' area, above $7000.  This will probably change soon, 
either so they reside in ROM HyForth itself does better at initialization.

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
