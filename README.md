# spottimer

Spot Light Timer

## Introduction

This project was developed as a solution for the bathroom spot light, which is
always forgotten to be switched off, because it is not connected to switched
normal lamp, but connected directly to socket with a separated switch. 
Project switches on the lamp at power on, but switches it off after 10 minutes
automatic. Meantime it gives warning that lamp will be switched off soon by
some flashes.

## Software

Software is pure assembly code. Just ne necessary code is written. There is no
universal or general modules.

To understand my description below you may need to look at the related part in
[processor reference manual](https://www.nxp.com/docs/en/data-sheet/MC9S08DZ60.pdf).

### Central Processor Unit (S08CPUV3)
 
Regarding assembly commands refer
[HCS08RMV1.pdf](https://www.nxp.com/docs/en/reference-manual/HCS08RMV1.pdf).
It is not available on the link from where I have downloaded.
Therefore I have stored it
[here](https://github.com/butyi/sci2can/raw/master/hw/HCS08RMV1.pdf).

### Parallel Input/Output Control

To prevent extra current consumption caused by flying not connected input ports,
all ports shall be configured as output. I have configured ports to low level
output by default.
There are only some exceptions for the used ports, where this default
initialization is not proper. For example inputs pins.

### Multi-purpose Clock Generator (S08MCGV1)

MCG is configured to PEE mode. But this mode can be reached through other modes.
See details in
[AN3499](https://www.nxp.com/docs/en/application-note/AN3499.pdf).
This is because quarz is already mounted on board and higher accuracy is better
for timing. Bus frequency is only 8MHz now. This is far enough for this easy
project.

### Structure

Software does not have any operation system. It is not needed, especially
because there no task in main loop. Everything is executed in RTC interrupt
routine.

### Main activity

The main activity is to count down a counter by one in each second.
Counter is inicialized to 600 for 10 minutes (600s) at power up.
When the counter reaches zero, spot lamp is switched off.
During counting down, at specific values the lamp is switched off
for one second only as warning, that lamp will be switched off soon.
The complete activity is running in the RTC interrupt, which is called
once a second.

### Compile

- Download assembler from [aspisys.com](http://www.aspisys.com/asm8.htm).
  It works on both Linux and Windows.
- Check out the repo
- Run my bash file `./c`.
  Or run `asm8 prg.asm` on Linux, `asm8.exe prg.asm` on Windows.
- prg.s19 is now ready to download.

### Download

Since I haven't written downloader/bootloader for DZ family yet, I use USBDM.

USBDM Hardware interface is cheap. I have bought it for 10€ on Ebay.
Just search "USBDM S08".

USBDM has free software tool support for S08 microcontrollers.
You can download it from [here](https://sourceforge.net/projects/usbdm/).
When you install the package, you will have Flash Downloader tools for several
target controllers. Once is for S08 family.

It is much more comfortable and faster to call the download from command line.
Just run my bash file `./p`.

## Hardware

The hardware is [sci2can board](https://github.com/butyi/sci2can)
Once digital output controls the 5V realy coil by FET IRLML0040TRP.
Coil has also a diode to supress transient when coil current is
interrupted by the FET. The relay interrupts the 230V side of spot
power supply.

The board (sci2can) has a private power supply from 230V to 5V 700mA.

The complete system is look like this.

![system](https://github.com/butyi/spottimer/raw/master/pics/spottimer.jpg)

## License

This is free. You can do anything you want with it.
While I am using Linux, I got so many support from free projects,
I am happy if I can give something back to the community.

## Keywords

Motorola, Freescale, NXP, MC68HC9S08DZ60, 68HC9S08DZ60, HC9S08DZ60, MC9S08DZ60,
9S08DZ60, HC9S08DZ48, HC9S08DZ32, HC9S08DZ, 9S08DZ, UART, RS232.

###### 2021 Janos BENCSIK


