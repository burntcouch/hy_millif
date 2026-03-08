REM create msbasic for hydra
REM
del temp\*.o
mkdir .\%1
copy *.* .\%1
h:\cc65\bin\ca65.exe -l temp\hyforth.txt -o temp\hyforth.o hy_millif.s
h:\cc65\bin\ld65 -vm -C hy_millif.cfg temp\hyforth.o -Ln temp\hyforth.lbl