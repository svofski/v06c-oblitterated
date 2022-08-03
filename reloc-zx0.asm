        .project reloc-zx0.0100
        .tape v06c-rom

;dst     equ $4000
;dzx_sz  equ 92
;data_sz equ 3328 + dzx_sz
ayctrl  .equ $15
aydata  .equ $14

        .org $100
        ;lxi sp, data_sz
        di
        xra a
        out $10

        
        lxi sp, $100

        lxi d, $07c7 ; noise enable on channel A
        call ay_outde
        lxi d, $0803 ; volume pretty low on channel A
        call ay_outde
        lxi d, $0905 ; volume pretty low on channel B
        call ay_outde
        lxi d, $0a03 ; volume pretty low on channel C
        call ay_outde

        lxi b, $100
        push b
        
        lxi d, src
        lxi h, dst
        push h          ; unpacker return address = dst
loop:
        ldax d
        mov m, a
        inx h
        inx d
        mov a, h
        cpi  ((dst + data_sz + dzx_sz) >> 8) + 1 ; дошли до края?
        jnz loop
        
        ; for dzx0: bc = source, de = destination
        lxi d, dst + dzx_sz
        ret
ay_outde
   	mov a, d
        out ayctrl
        mov a, e
        out aydata
        ret
        db 'SVO/2022'
src     equ $    
        ; here there lies dzx7
