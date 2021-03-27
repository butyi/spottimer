@echo off
::Programming
UsbdmFlashProgrammer.exe -target=hcs08 -device=MC9S08DZ60 -program -masserase -security:image -execute prg.s19
echo Success.
