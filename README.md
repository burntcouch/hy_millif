# hy_millif
<h2>Hydra-16 version of MilliForth</h2>
----------------------------------------------------------------------
<p>
  Patrick Struthers - March 2026
<p>
      - THANKS to [AGSB](https://github.com/agsb) for the starting point here....<p>
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
#see below for original intro from Sr. Barcellos



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

