; =============================================================================
; Spot lamp timer
; This software has the function to switch bathroom spot lamp off after 10 minutes.
;   It also reminds to reset it (manual switch off-on)
;   - one flash at 7 minute 
;   - two flash at 8 minute 
;   - three flash at 9 minute
; =============================================================================
;
#include "dz60.inc"
; ====================  EQUATES ===============================================

LED             @pin    PTA,6
CANRX           @pin    PTE,7
CANTX           @pin    PTE,6
RxD1            @pin    PTE,1
RxD1_2          @pin    PTA,0
FET             @pin    PTD,3

; ====================  PROGRAM START  ========================================

#RAM


spot_timer      ds      2       ; count seconds


; ====================  PROGRAM START  ========================================

#ROM

start:
        sei                     ; disable interrupts

        ldhx    #XRAM_END       ; H:X points to SP
        txs                     ; Init SP

        jsr     COP_Init
        jsr     PTX_Init        ; I/O ports initialization
        bsr     MCG_Init
        bsr     RTC_Init

        cli                     ; Enable interrupts
MAIN
        jsr     KickCop         ; Update watchdog
        bra     MAIN




; ------------------------------------------------------------------------------
; Real-Time Counter (S08RTCV1)
; This is periodic timer. (Like PIT in AZ60, TBM in GZ60 in the past) 
;  - Select external clock (RTCLKS = 1)
;  - Use interrupt to handle software timer variables (RTIE = 1)
;  - RTCPS = 13 (10^4 means 4MHz/50000 = 80Hz)
;  - RTCMOD = 100 (80Hz/80 = 1Hz -> 1s)
; This will result 250ms periodic interrupt.
RTC_Init
        ; Set up registers
        mov     #RTIE_|RTCLKS0_|13,RTCSC
        mov     #79,RTCMOD

        ldhx    #600            ; Pull up timer for 10 minutes
        sthx    spot_timer
        
        rts

; RTC (periodic) interrupt routine, hits in every 10ms
RTC_IT
        ; Toggle LED
        lda     LED
        eor     #LED_
        sta     LED

        ; Update spot lamp state
        ; Three off at 9th minute
        ldhx    spot_timer
        cphx    #64
        beq     SC_Off
        cphx    #62
        beq     SC_Off
        cphx    #60
        beq     SC_Off

        ; Two off at 8th minute
        cphx    #122
        beq     SC_Off
        cphx    #120
        beq     SC_Off

        ; One off at 7th minute
        cphx    #180
        beq     SC_Off

        ; Off after 10th minute
        cphx    #0
        beq     SC_Off

        mov     #FET_,FET       ; Switch On
        bra     SC_End
SC_Off
        mov     #0,FET          ; Switch Off
SC_End
        ; Check if is spot_timer already zero
        lda     spot_timer
        ora     spot_timer+1
        beq     RTC_End         ; Spot_timer is already zero, no decrement needed

        ; Decrement spot_timer since not zero yet
        ldhx    spot_timer
        aix     #-1
        sthx    spot_timer

RTC_End
        bset    RTIF.,RTCSC     ; clear flag
        rti



; ------------------------------------------------------------------------------
; Using DZ60, the function will switch to PEE Mode (based on AN3499)
;  Fext = 4MHz (crystal)
;  Fmcgout = ((Fext/R)*M/B) - for PEE mode
;  Fbus = Fmcgout/2 (8MHz)
MCG_Init
        ; -- First, FEI must transition to FBE mode

        ; MCG Control Register 2 (MCGC2)
        ;  BDIV = 00 - Set clock to divide by 1
        ;  RANGE_SEL = 1 - High Freq range selected (i.e. 4MHz in high freq range)
        ;  HGO = 1 - Ext Osc configured for high gain
        ;  LP = 0 - FLL or PLL is not disabled in bypass modes
        ;  EREFS = 1 - Oscillator requested
        ;  ERCLKEN = 1 - MCGERCLK active
        ;  EREFSTEN = 0 - Ext Reference clock is disabled in stop
        mov     #RANGE_SEL_|EREFS_|ERCLKEN_,MCGC2 ; HGO_|

        ; Loop until OSCINIT = 1 - indicates crystal selected by EREFS bit has been initalised
imcg1
        brclr   OSCINIT.,MCGSC,imcg1

        ; MCG Control Register 1 (MCGC1)
        ;  CLKSx    = 10    Select Ext reference clk as clock source 
        ;  RDIVx    = 111   Set to divide by 128 (i.e. 4MHz/128 = 31.25kHz - in range required by FLL)
        ;  IREFS    = 0     Ext Ref clock selected
        ;  IRCLKEN  = 0     MCGIRCLK inactive
        ;  IREFSTEN = 0     Internal ref clock disabled in stop  
        mov     #CLKS1_|RDIV2_|RDIV1_|RDIV0_,MCGC1

        ; Loop until IREFST = 0 - indicates ext ref is current source
imcg2
        brset  IREFST.,MCGSC,imcg2

        ; Loop until CLKST = 10 - indiates ext ref clk selected to feed MCGOUT
imcg3
        lda     MCGSC
        and     #CLKST1_|CLKST0_        ; mask CLKST bits
        cmp     #CLKST1_
        bne     imcg3

        ; -- Next FBE must transition to PBE mode

        ; MCG Control Register 1 (MCGC1)
        ;  CLKSx    = 10    Select Ext reference clk as clock source 
        ;  RDIVx    = 010   Set to divide by 4 (i.e. 4MHz/4 = 1 MHz - in range required by FLL)
        ;  IREFS    = 0     Ext Ref clock selected
        ;  IRCLKEN  = 0     MCGIRCLK inactive
        ;  IREFSTEN = 0     Internal ref clock disabled in stop  
        mov     #CLKS1_|RDIV1_,MCGC1

        ; MCG Control Register 3 (MCGC3)
        ;  LOLIE = 0    No request on loss of lock
        ;  PLLS  = 1    PLL selected
        ;  CME   = 0    Clock monitor is disabled
        ;  VDIV  = 0100 Set to multiply by 16 (1Mhz ref x 16 = 16MHz)
        mov     #PLLS_|4,MCGC3

        ; Loop until PLLST = 1 - indicates current source for PLLS is PLL
imcg4
        brclr   PLLST.,MCGSC,imcg4

        ; Loop until LOCK = 1 - indicates PLL has aquired lock
imcg5
        brclr   LOCK.,MCGSC,imcg5

        ; -- Last, PBE mode transitions into PEE mode

        ; MCG Control Register 1 (MCGC1)
        ;  CLKS     = 00    Select PLL clock source 
        ;  RDIV     = 010   Set to divide by 4 (i.e. 4MHz/4 = 1 MHz - in range required by PLL)
        ;  IREFS    = 0     Ext Ref clock selected
        ;  IRCLKEN  = 0     MCGIRCLK inactive
        ;  IREFSTEN = 0     Internal ref clock disabled in stop
        mov     #RDIV1_,MCGC1

        ; Loop until CLKST = 11 - PLL O/P selected to feed MCGOUT in current clk mode
imcg6  
        lda     MCGSC
        and     #CLKST1_|CLKST0_        ; mask CLKST bits
        cmp     #CLKST1_|CLKST0_
        bne     imcg6

        ; ABOVE CODE ALLOWS ENTRY FROM PBE TO PEE MODE

        ; Since RDIV = 4, BDIV = 1, VDIV = 16
        ; Now
        ;  Fmcgout = ((4MHz/4)*16)/1 = 16MHz
        ;  Fbus = Fmcgout/2 = 8MHz

        rts

; ------------------------------------------------------------------------------
; Parallel Input/Output Control
; To prevent extra current consumption caused by flying not connected input
; ports, all ports shall be configured as output. I have configured ports to
; low level output by default.
; There are only a few exceptions for the used ports, where different
; initialization is needed.
; Default init states are proper for OSCILL_SUPP pins, no exception needed.
PTX_Init
        ; All ports to be low level
        clra
        sta     PTA
        sta     PTB
        sta     PTC
        sta     PTD
        sta     PTE
        sta     PTF
        sta     PTG
        bset    CANTX.,CANTX            ; CANTX to be high
        bset    LED.,LED                ; LED2 to be On
        bset    FET.,FET                ; FET to be On
        

        ; All ports to be output
        lda     #$FF
        sta     DDRA
        sta     DDRB
        sta     DDRC
        sta     DDRD
        sta     DDRE
        sta     DDRF
        sta     DDRG
        bclr    CANRX.,CANRX+1          ; CANRX to be input
        bclr    RxD1.,RxD1+1            ; RxD1 to be input
        bclr    RxD1_2.,RxD1_2+1        ; RxD1_2 to be input
        lda     #RxD1_2_
        sta     PTAPE                   ; RxD1_2 to be pulled up

        rts

; ------------------------------------------------------------------------------
; Computer Operating Properly (COP) Watchdog
COP_Init
        ; System Options Register 2
        ; COPCLKS = 0 (1kHz)
        ; COPW = 0 (No COP Window)
        ; ADHTS = 0 (ADC Hardware Trigger from RTC overflow)
        ; MCSEL = 0 (MCLK output on PTA0 is disabled)
        ; -> So, no change needed for SOPT2
        
        ; System Options Register 1
        ; COPT = 01b (2^5 cycles, 1kHz) ~= 32ms
        ; STOPE = 0 (Stop mode disabled)
        ; SCI2PS = 0 (TxD2 on PTF0, RxD2 on PTF1.)
        ; IICPS = 0 (SCL on PTF2, SDA on PTF3)
        lda     #COPT0_|IICPS_
        sta     SOPT1
        rts
        
        ; Refresh Watchdog
KickCop
        psha                    ; Save A, because function will change it
        lda       #$55          ; First pattern $55
        sta       COP
        coma                    ; Second pattern $AA
        sta       COP
        pula                    ; Restore original content of A
        rts


; ===================== Include Files =========================================

; ===================== Constants =============================================

; ===================== IT VECTORS ==========================================
        org     Vrtc
        dw      RTC_IT
        
        org     Vreset
        dw      start           ; Program Start




