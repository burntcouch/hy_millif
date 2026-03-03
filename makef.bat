REM create msbasic for hydra
REM
del temp\*.o
h:\cc65\bin\ca65.exe -l temp\millif.txt -o temp\hy_millif.o hy_millif.s
h:\cc65\bin\ld65 -vm -C hy_millif.cfg temp\hy_millif.o -o temp\hy_millif.bin -Ln temp\hy_millif.lbl