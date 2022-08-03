                ; an unlikely max headroom incident
                ; svo 2022

                ; plot:
                ; 1) полная мельтешня из линий
                ; 2) на ее фоне медленно выползает Макс
                ; 3) мельтешня становится плавной
                ; 4) появляется надпись 
		;
		; ALL MY CYCLES
		; USED TO BE
		; BLITTING
		; AND I WAS MUTE
		; NOW I UNPACK
		; 14 REG STREAMS
		; ON THE FLY
		; I'M NO LONGER
		; OBLITTERATED
		
		; r.1 полностью развернутый блит с жумпом внутрь: 282 строки, но бывает один кадр 305
		; r.2 версия с гигачад-16. есть пропуски кадров, но не критично.

                .project oblitterated.rom
                .tape v06c-rom
		.org 100h

TILTSPEED       equ 421 ;128 ; 3*255

TILT1           equ 0           ; band tilt 0 = most horizontal
TILT2           equ 4           
TILT3           equ 8

BAND_THICC      equ 5           ; normal band base thickness
BAND_STEP       equ 32          ; band period
BAND_N          equ 8           ; number of bands



		di
; ---
start:
		xra	a
		out	10h
		lxi	sp, 100h
		mvi	a, 0C3h
		sta	0
		lxi	h, Restart
		shld	1

		mvi	a, 0C9h
		sta	38h

Restart:
		lxi sp,100h
		
		call ay_noise
		
                ei \ hlt
                lxi h, colors_nil + 15
                call colorset
		call Cls

                call bsszero		

                ; сбросить LFSR
                lxi h, 65535
                shld rnd16+1
                
                
                call ay_noise                
                
                ; создает таски и устанавливает начальный контекст гигачада (изначально он выключен)
                lxi h, song_1
                call gigachad_init
                
                ; начальная фаза -- мельтешня и выползающая харя
                call sequence_next
                
                ; первое сообщение
                lxi h, msg_sequence
                shld msgptr

		call SetPixelModeOR
		
                mvi a, 080h                     ; select plane $8000
                sta line_bitplane_1
                sta line_bitplane_2

		lxi h, ((224 + TILT1) << 8)|0
		shld line_x0
		lxi h, ((255 - TILT1) << 8)|255
		shld line_x1
                
                call draw_bands                

                mvi a, 0a0h                     ; select plane $a000
                sta line_bitplane_1
                sta line_bitplane_2

		lxi h, ((224 + TILT2) << 8)|0         ; y | x
		shld line_x0
		lxi h, ((255 - TILT2) << 8)|255
		shld line_x1
                
                call draw_bands                

                mvi a, 0c0h                     ; select plane $c000
                sta line_bitplane_1
                sta line_bitplane_2

		lxi h, ((224 + TILT3) << 8)|0
		shld line_x0
		lxi h, ((255 - TILT3) << 8)|255
		shld line_x1
                
                call draw_bands       

                ; initial phase for up/down cosine
                mvi a, 128
                sta faddi
                lxi h, $0000
                shld tiltphase

                ; убрать дефолтную мадженту
                call cyclecolors

foreva_lup        
                ; typical: line 282 (30 lines free)
                ; worst: line 305   (7 lines free)
                ei
                hlt
                lxi h, framecnt
                inr m
                mov a, m
                call cyclecolors

                call rnd16

                lxi h, faddi    ; update arg
                inr m
                call cosm       ; e = cos(m)

                ; invert direction: vertical stripes ping-pong
                mvi d, 0
                lxi h, updownctr
                inr m
                lxi h, fasign
                mov a, m
                jnz $+4
                cma
                mov m, a
                ora a
                jp no_negate_here
                
                ; negate increment
                mov a, e
                cma
                ;inr a
                mov e, a
                mvi d, $ff
no_negate_here
                lhld facum      ; facum += cos(arg)
                dad d
                shld facum

                lda frame_scroll
                sta frame_scroll_prev
                
                
                ; SELFMOD: 3 bytes
                ; phase 0:  rnd flicker:   lda rnd16+1
                ; phase 1:  fast flicker   mov a, l \ cma \ nop
                ; others:   slow pan       mov a, h \ nop \ nop
modesw1         nop
                nop
                nop
                
                sta frame_scroll        ; frame_scroll = trunc(facum)
                
                ; calculate tilt, a number 0..2
                lhld tiltphase
                lxi d, TILTSPEED
                dad d
                shld tiltphase
                mov a, h

                ; select tilt angle based on integral part of tiltphase
                sui 64
                jc pal_idx_0 ; 0..63
                sui 64
                jc pal_idx_1 ; 64..127
                sui 64
                jc pal_idx_2 ; 128..192
pal_idx_1                    ; 192..255
                lxi h, colors_2+15
                jmp setcolors
pal_idx_2
                lxi h, colors_3+15
                jmp setcolors
pal_idx_0
                lxi h, colors_1+15
                jmp setcolors

setcolors:                
                call colorset
                
                lda frame_scroll
                out 3
                
                ;mvi a, 15
                ;out 2

modesw2:        ; переход на главную процедуру секвенции        
                call 0
                
                ; музон
                call gigachad_frame
                        
                jmp foreva_lup
                
                ;mvi a, 0
                ;out 2

sequence_next:  
                lxi h, seq_index
sequence_next_L0:
                mvi d, 0
                mov e, m                        ; de = static_cast<int>(seq_index)
                inr m \ inr m \ inr m \ inr m   ; seq_index++
                lxi h, sequence                 ; hl = &sequence[0]
                dad d                           ; hl = &sequence[current].setup
                mov e, m
                inx h
                mov d, m                        ; de = sequence[current].setup
                inx h                           ; hl = &sequence[current].main
                mov a, d
                ora e
                jnz sequence_index_L1           ; if sequence[current].setup == 0
                ; end of sequence, loop back to 0
                lxi h, seq_index
                mvi m, 0                        ; сбросили индекс на 0 и повторяем
                jmp sequence_next_L0
sequence_index_L1:
                ; hl = &sequence[current].main
                ; de = sequence[current].setup
                push h
                lxi b, sequence_index_L2
                push b  ; адрес возврата из setup
                xchg
                pchl    ; вызов процедуры setup
sequence_index_L2:
                pop h
                mov e, m
                inx h
                mov d, m ; de = sequence[seq_index].main
                ; осталось прописать адрес main в главный переход
                xchg
                shld modesw2 + 1
                ret
                
        
                ; main sequence of the "animation"        
sequence        
                dw phase0_setup_mus, phase0_main    ; begin with fast flicker
                dw phase0_setup, phase0_main
                dw phase0_setup, phase0_main
                dw phase0_setup, phase0_main
                dw phase0_setup, phase0_main
                dw phase0_setup, phase0_main
                dw phase0_setup, phase0_main
                dw phaseN1_setup, phaseN1_main  ; TAPE ERROR appears
                dw phase0_setup, phase0_main    ; flicker again

                dw phase0_setup, phase0_main    ; flicker again
                dw phase0_setup, phase0_main    ; flicker again


                dw phase1_setup, phase1_main    ; face appears 
                dw phase2_setup, phase2_main    ; full max flickers 
                
                dw phase5_setup, phase5_main    ; main part with messages
                dw phase6_setup_noise, phase6_main    ; max disappears (loud noise)
                dw phase0_setup_noise, phase0_main    ; empty flicker (moderate noise)
                dw phase0_setup, phase0_main
                dw phase0_setup, phase0_main
                dw phase0_setup, phase0_main

                ; end titles...                
                dw phase7_setup_mus, phase7_main    ; end titles show up
                dw phase8_setup, phase8_main        ; end titles hold
                dw phase8_setup, phase8_main
                dw phase9_setup, phase9_main        ; end titles hold and wipe off
                dw phase0_setup_loudnoise, phase0_main
                dw phase0_setup_noise, phase0_main
                dw phase0_setup, phase0_main    ; empty flicker and repeat
                dw Restart, Restart

                
                dw 0, 0

msgptr          dw msg_sequence                
msg_sequence    dw msg_hello1, msg_hello2, msg_hello1, msg_hello2
                dw msg_what_a_strange
                dw msg_place_i_have_to
                dw msg_blit_myself
                dw msg_as_fast_as_i_can
                dw msg_just_to_stay
                dw msg_where_i_am
                dw msg_i_am_fully
                dw msg_i_am_fully
                dw msg_oblitterated, msg_oblitterated
                dw msg_oblitterated, msg_oblitterated
                dw msg_oblitterated, msg_oblitterated
                dw 0, 0

;1234567890123456
;
;what a strange
;place. i have
;to blit myself
;as fast as i can
;just to stay
;where i am!
;
;i am fully
;oblitterated

bss_start       equ $                
ctr8i           db 0
ctr8j           db 0
frame_scroll    db 0
frame_scroll_prev db 0
pal_idx         db 0
frameskip       db 0
framecnt        db 0

faddi           db 0            ; cos arg
facum           db 0, 0         ; scroll accumulator
fasign          db 0
updownctr       db 0

tiltphase       dw 0
ph1_height      db 0
seq_index       db 0
phase2_ctr      db 0                
phase0_ctr      db 0
msg_timer       db 0
mainseq_active  db 0            ; главная последовательность в процессе 
bss_length      equ $-bss_start
                ; e = cos(m)


LOGOXY          equ $04c1+0e000h

                lda rnd16+1
                
phaseN1_setup:
                mvi a, $7c ; "mov a, h"
                sta modesw1
                lxi h, 0
                shld modesw1+1

                mvi a, 130
                sta phase0_ctr
                ret
phaseN1_main:
                lxi h, msg_tape_error1
                shld blit_src1+1
                lxi h, msg_tape_error2
                shld blit_src2+1
                lxi h, $0620+0e000h     ; -- top / right corner
                shld blit_xy
                mvi a, 18/2             ; text tag height
                sta blit_height
                ;mvi a, 64/8/8            ; text tag width (1)
                ;sta blit_width
                lxi h, blit_line_c1 + (4 - 1) * blit_linej_sz
                shld blit_widthj
                call blit
             
             
                lxi h, phase0_ctr
                dcr m
                rnz
                jmp sequence_next
                
;; ----------------------------------------------
;; phase0:  полная мельтешня без переднего плана
;; ----------------------------------------------
phase0_setup_loudnoise:
                call gigachad_disable
                call ay_noise_louder
                jmp phase0_setup
phase0_setup_noise:
                call gigachad_disable
                call ay_noise
                jmp phase0_setup
phase0_setup_stfu:
                call gigachad_disable
                call ay_stfu
                jmp phase0_setup
phase0_setup_mus:
                ;;; START INTRO SONG
                lxi h, song_1
                call gigachad_init
                call gigachad_enable
                
                call gigachad_precharge

phase0_setup:
                ; modesw1 = "lda rnd16+1"
                mvi a, $3a ; lda
                sta modesw1
                lxi h, rnd16 + 1
                shld modesw1 + 1

                xra a
                sta frame_scroll
                sta frame_scroll_prev
                mvi a, 60 
                sta phase0_ctr
                ret
phase0_main:
                lxi h, phase0_ctr
                dcr m
                rnz
                lda seq_index
                push psw
                call bsszero
                pop psw
                sta seq_index
                jmp sequence_next

;; ----------------------------------------------
;; phase1: мельтешня быстрая, но не случайная, снизу выплывает харя
;; ----------------------------------------------
phase1_setup:
                ; modesw = "mov a, l \ cma" = 7d, 2f
                lxi h, $7d2f; $2f7d
                shld modesw1
                xra a
                sta modesw1+2

                sta ph1_height
                
                ret

phase1_main:
                lxi h, ph1_height
                inr m

                mov a, m
                ora a  ;; так получается обалденский эффект
                rar 
                inr a
                mov c, a
                ral
                mov b, a

                lxi h, LOGOXY-122/2
                mov l, a
                sub b
                shld wipe_xy
                shld blit_xy

                mov a, c
                ;cpi (122)/2 ;; это если полностью, но выходит затянуто
                cpi 60/2     ;; а так вполне себе шустро
                jc phase1_L1

                ; завершаем фазу 1
                ; перед следующей фазой надо тщательно затереть остатки мельтешни. 
                ; они через строку, поэтому два раза 
                mvi a, 80
                sta wipe_height
                mvi a, 128/8/8
                sta wipe_width
                ;sta blit_width
                call wipe

                lhld wipe_xy
                inr l
                shld wipe_xy
                call wipe
                
                jmp sequence_next
phase1_L1
                sta wipe_height
                sta blit_height
                mvi a, 128/8/8  ;= 2
                sta wipe_width
                
                lxi h, blit_line_c1 + (4 - 2) * blit_linej_sz
                shld blit_widthj

                lxi h, hello_jpg
                shld blit_src1+1
                lxi h, hello_jpg2
                shld blit_src2+1
                call wipe ; можно вообще не вызывать, но тогда грязновато
                jmp blit
                ;ret
                
;; ----------------------------------------------
;; phase1: переход между влетом и статической картинкой, мерцание?   
;; ----------------------------------------------
phase2_setup:         
                mvi a, 16
                sta phase2_ctr
                
                
                ;call gigachad_enable
                ;;; START MAIN SONG
                lxi h, song_0
                call gigachad_init
                jmp gigachad_enable
                ;ret
phase2_main:    
                lxi h, phase2_ctr
                mov a, m
                dcr m
                jz sequence_next
                
                ; редко -- выводим голову
                ani 3
                jz blit_full_head

                ; часто - все стираем: TODO померить как мы успеваем, но смотрится зашибись
                mvi a, 80
                sta wipe_height
                mvi a, 192/8/8 ;128/8/8
                sta wipe_width
                call wipe

                lhld wipe_xy
                inr l
                shld wipe_xy
                jmp wipe
                ;ret
                
;; ----------------------------------------------

phase3_setup:
                mvi a, $7c ; "mov a, h"
                sta modesw1
                lxi h, 0
                shld modesw1+1
                ret

                ; то же самое, что phase5, но только голова без текста
phase3_main:
                jmp blit_full_head
                ; ret 
;;
;; Основная фаза с полной головой и текстом
;; 
phase5_setup:
                mvi a, $7c ; "mov a, h"
                sta modesw1
                lxi h, 0
                shld modesw1+1
                mvi a, 1
                sta mainseq_active
                call msg_sequence_next
                jmp gigachad_enable
                ;ret

                ; основная фаза: рисуем все
phase5_main:
                call msg_sequence_frame
                ; для ускорения рисуем черепушку отдельно, она уже плечей
                call blit_full_head
blit_banner:
blit_banner_p1: lxi h, msg_tape_error1
                shld blit_src1+1
blit_banner_p2: lxi h, msg_tape_error2
                shld blit_src2+1
blit_banner_p3: lxi h, $16f0+0e000h     ; -- top / right corner
                shld blit_xy
                mvi a, 18/2             ; text tag height
                sta blit_height
                lxi h, blit_line_c1 + (4 - 1) * blit_linej_sz
                shld blit_widthj
                call blit
                lda mainseq_active
                ora a
                cz sequence_next
                ret

blit_full_head
blit_head:
                lxi h, hello_jpg
                shld blit_src1+1
                lxi h, hello_jpg2
                shld blit_src2+1
                lxi h, LOGOXY
                shld blit_xy
                mvi a, 122/2            ; head height
                sta blit_height
                lxi h, blit_line_c1 + (4 - 2) * blit_linej_sz
                shld blit_widthj
                call blit

                ; и плечи пошире
blit_torso:
                lxi h, max_bottom
                shld blit_src1+1
                lxi h, max_bottom2
                shld blit_src2+1
                lxi h, $0447+0e000h
                shld blit_xy
                mvi a, 72/2             ; 72 lines
                sta blit_height
                lxi h, blit_line_c1 + (4 - 3) * blit_linej_sz
                shld blit_widthj
                jmp blit

;; ----------------------------------------------
;; phase6: смываем харю
;; ----------------------------------------------
;; ----------------------------------------------
;; phase1: мельтешня быстрая, но не случайная, снизу выплывает харя
;; ----------------------------------------------
phase6_setup_noise:
                call gigachad_disable
                call ay_stfu
                call ay_noise_louder
phase6_setup:
                ; modesw = "mov a, l \ cma" = 7d, 2f
                lxi h, $7d2f; $2f7d
                shld modesw1
                xra a
                sta modesw1+2

                mvi a, 122/2
                sta ph1_height
                
                ; голову затереть черезстрочно, а то она ярковата для исчезающей
                lxi h, LOGOXY
                shld wipe_xy
                mvi a, 122/2            ; head height
                sta wipe_height
                mvi a, 128/8/8
                sta wipe_width
                call wipe
                ; и верх затереть совсем для расползания классного
                lxi h, LOGOXY
                inr l
                shld wipe_xy
                mvi a, 30
                sta wipe_height
                call wipe
                
                ; плечи надо затереть совсем, а то фигня выходит
                lxi h, $0447+0e000h
                shld wipe_xy
                mvi a, 72/2             ; 72 lines
                sta wipe_height
                mvi a, 192/8/8          ; 192 pixels wide torso
                sta wipe_width
                call wipe
                
                lxi h, $0448+0e000h
                shld wipe_xy
                call wipe
                
                jmp wipe_banner
                ;ret
phase6_main:
                ;jmp $
                lxi h, ph1_height
                dcr m ;\ dcr m
                mov a, m
                ora a  ;; так получается обалденский эффект
                rar 
                inr a
                mov c, a
                ral
                mov b, a

                lxi h, LOGOXY-122/2
                mov l, a
                sub b
                shld wipe_xy
                shld blit_xy

                mov a, c
                ora a     ;; а так вполне себе шустро
                jz $+6
                jp phase6_L1

                ; завершаем фазу
                ; перед следующей фазой надо тщательно затереть остатки мельтешни. 
                ; они через строку, поэтому два раза 
                mvi a, 128
                sta wipe_height
                mvi a, 128/8/8
                sta wipe_width
                call wipe

                lhld wipe_xy
                inr l
                shld wipe_xy
                call wipe
                jmp sequence_next
phase6_L1
                sta wipe_height
                sta blit_height
                mvi a, 128/8/8 ; 2
                sta wipe_width

                lxi h, blit_line_c1 + (4 - 2) * blit_linej_sz
                shld blit_widthj

                lxi h, hello_jpg
                shld blit_src1+1
                lxi h, hello_jpg2
                shld blit_src2+1
                call wipe ; можно вообще не вызывать, но тогда грязновато
                jmp blit
                ;ret

                
                ; end titles, kinda sorta
phase7_setup_mus:
                call gigachad_enable
phase7_setup:
                mvi a, $7c ; "mov a, h"
                sta modesw1
                lxi h, 0
                shld modesw1+1

                mvi a, 255
                sta phase0_ctr
                ret
phase7_main:
titleout_xy     equ $0020+0e000h
title_xy_1      equ titleout_xy + 12*256 + 14 * 8        ; oblitterated
title_xy_2      equ titleout_xy + 8 * 256 + 10 * 8       ; an unlikely max headroom incident
title_xy_3      equ titleout_xy + 12 * 256 + 3 * 8      ; svo 2022
title_xy_4      equ titleout_xy + 8 * 256               ; music by firestarter
text_height     equ 18/2
text_width      equ 1
                lxi h, msg_oblitterated
                shld blit_src1+1
                shld blit_src2+1
                lxi h, title_xy_1
                shld blit_xy
                mvi a, text_height
                sta blit_height
                mvi a, text_width

                lxi h, blit_line_c1 + (4 - text_width) * blit_linej_sz
                shld blit_widthj
                call blit

                lxi h, msg_no_longer_inv1
                shld blit_src1+1
                lxi h, msg_no_longer_inv2
                shld blit_src2+1
                lxi h, title_xy_1 + 2 * 8
                shld blit_xy
                call blit

                lxi h, msg_an_unlikely        
                shld blit_src1+1
                shld blit_src2+1
                lxi h, title_xy_2
                shld blit_xy
                call blit
                
                lxi h, msg_headroom_incident
                shld blit_src1+1
                shld blit_src2+1
                lxi h, title_xy_2 + 8 * 256
                shld blit_xy
                call blit
                
                lxi h, msg_svo2022
                shld blit_src1+1
                shld blit_src2+1
                lxi h, title_xy_3
                shld blit_xy
                call blit
                
                lxi h, msg_music_by
                shld blit_src1+1
                shld blit_src2+1
                lxi h, title_xy_4
                shld blit_xy
                call blit

                lxi h, msg_firestarter1
                shld blit_src1+1
                lxi h, msg_firestarter2
                shld blit_src2+1
                lxi h, title_xy_4 + 8 * 256
                shld blit_xy
                call blit

                lxi h, phase0_ctr
                dcr m
                rnz
                
                jmp sequence_next
                
phase8_setup:   ret
phase8_main:    jmp phase7_main

phase9_setup:
                ; wipe
                lxi h, titleout_xy + 8*256 + 16*8
                shld wipe_xy
                mvi a, text_height * 8
                sta wipe_height
                mvi a, 2
                sta wipe_width
                call wipe

                lxi h, titleout_xy + 8*256 + 16*8 + 1
                shld wipe_xy
                jmp wipe
                ;ret
phase9_main:
                jmp sequence_next

                ; wipe the banner message in its jumpy position
wipe_banner:
                mvi a, 9 \ sta wipe_height
                mvi a, 1 \ sta wipe_width
                lhld blit_banner_p3+1
                push h
                shld wipe_xy
                call wipe
                pop h
                inr l
                shld wipe_xy
                jmp wipe
                ; ret

MSG_TIME        equ 100
msg_sequence_frame:
                lxi h, msg_timer
                dcr m
                rnz
msg_sequence_next
                mvi a, MSG_TIME
                sta msg_timer
                
                ; стереть полностью сообщение
                call wipe_banner

                ; установить новое место для сообщения
                lda rnd16+1
                ani $f \ adi $e8
                sta blit_banner_p3+2
                lda rnd16+2
                ani $1f \ adi $d0+2
                sta blit_banner_p3+1
                
                lhld msgptr
ph5a_setup_L1:
                mov e, m
                inx h
                mov d, m
                inx h
                mov a, d
                ora e
                jnz ph5a_setup_L2
                sta mainseq_active
                lxi h, msg_sequence
                jmp ph5a_setup_L1
ph5a_setup_L2:                
                xchg \ shld blit_banner_p1+1 \ xchg
ph5a_setup_L4
                mov e, m
                inx h
                mov d, m
                dcx h
                ;
                mov a, d
                ora e
                jnz ph5a_setup_L3
                sta mainseq_active
                lxi h, msg_sequence
                jmp ph5a_setup_L4
ph5a_setup_L3:
                xchg \ shld blit_banner_p2+1 \ xchg
                shld msgptr                
                ret
                
cosm
                mov e, m
                mvi d, 0
                lxi h, costab
                dad d           ; hl = ptr cos(arg)
                mov e, m        ; de = cos(arg)
                ret

triam
                mov a, m
                jp $+4
                cma
                mov e, a
                ret

                ; h points to palette + 15
colorset:
		mvi	a, 88h
		out	0
		mvi	c, 15
colorset1:	mov	a, c
		out	2
		mov	a, m
		out	0Ch
		dcx	h
		out	0Ch
		out	0Ch
		dcr	c
		out	0Ch
		out	0Ch
		out	0Ch
		jp	colorset1
                ret

                ; paint backgrounds: thick and thin lines at various tilt angles
draw_bands
                mvi a, BAND_THICC-1
                sta ctr8i
                mvi a, BAND_N
                sta ctr8j
band_i_loop:		
		call line

		lxi h, ctr8i
		dcr m
		jz band_i_out

		lxi h, line_x0+1
		dcr m
		lxi h, line_x1+1
		dcr m 
		call line
		lxi h, line_x1+1
		dcr m
		jmp band_i_loop
band_i_out		
                
                ; repeat same line with a small gap
		lxi h, line_x0+1
		dcr m
		dcr m
		dcr m
		dcr m
		dcr m
		lxi h, line_x1+1
		dcr m
		dcr m
		dcr m
		dcr m
		dcr m
		call line

                ; copy the line up 8 times
                lda line_bitplane_1
                adi $1f
                mov h, a           ; hl points to bottom-right
                
                mvi b, 32          ; 32 columns
copy_column_up   
                mvi l, $ff
                mvi e, BAND_STEP+BAND_THICC+4 ; repeat byte copy for 32 lines
copy_32_up          
                mvi c, BAND_N
                ; copy 1 byte BAND_STEP lines up
                mov d, m        ; load it
copy_1_up                
                mov a, l
                sui BAND_STEP
                mov l, a
                mov a, m
                ora d
                mov m, a        ; copy it up
                dcr c
                jnz copy_1_up   ; and repeat BAND_N times
                
                dcr l           ; advance 1 line up
                dcr e
                jnz copy_32_up
                
                dcr h
                dcr b
                jnz copy_column_up
band_out
                ret


		; аргументы line()
line_x0		.db 100
line_y0		.db 55
line_x1		.db 0
line_y1		.db 50 

		; эти четыре байта должны идти в таком порядке, а то
line_y		.db 0
line_x		.db 0
line_dx 	.db 0
line_dy		.db 0

SetPixelModeXOR:
		lxi h,0A9AEh		;A9 - xra c; AE - xra m
		jmp SetPixelModeOR1
		
SetPixelModeOR:
		lxi h,0B1B6h		;B1 - ora c; B6 - ora m
SetPixelModeOR1:
		mov a,l
		sta SetPixelMode_g3
		sta SetPixelMode_g4
		sta SetPixelMode_s3
		mov a,h
		sta SetPixelMode_g1
		sta SetPixelMode_g2
		sta SetPixelMode_s1
		sta SetPixelMode_s2
		ret
		
PixelMask:
		.db 10000000b
		.db 01000000b
		.db 00100000b
		.db 00010000b
		.db 00001000b
		.db 00000100b
		.db 00000010b
		.db 00000001b
line:		; вычислить line_dx, line_dy и приращение Y
		; line_dx >= 0, line_dy >= 0, line1_mod_yinc ? [-1,1]

		; вычисление расстояния по X (dx)
		; проверить, что x0 <= x1
		lda line_x0
		sta line_x
		mov b, a		;b = x0
		lda line_x1
		sub b			;a = x1 - x0
		jnc line_x_positive     ;если x0 <= x1, то переход

		;если x0 > x1, то пришли сюда
		cma
		inr a			; -(x1-x0)=x0-x1
		sta line_dx		; сохранили |dx|
		lhld line_x0
		xchg
		lhld line_x1
		shld line_x0
		mov a,l
		sta line_x
		xchg
		shld line_x1
		jmp line_calc_dy
		
line_x_positive:
		sta line_dx		; сохранили |dx|

		; вычисление расстояния по Y (dy)
line_calc_dy:
		; если y0 <= y1
		lda line_y0
		sta line_y
		mov b, a		;b = y0
		lda line_y1
		sub b			;a = y1 - y0
		jnc line_y_positive	;если y0 <= y1, то переход

		;если y0 > y1, то пришли сюда
		cma
		inr a			; -(y1-y0)= y0 - y1
		sta line_dy		; сохранили |dy|
		
		; приращение y = -1
		mvi a, 02Dh 		; dcr l
		jmp set_line1_mod_yinc

line_y_positive:
		sta line_dy	        ; y1 - y0
		mvi a, 02Ch 		; inr l
set_line1_mod_yinc:
		sta line1_mod_yinc_g
		sta line1_mod_yinc_s1
		sta line1_mod_yinc_s2

line_check_gs:
		; проверяем крутизну склона:
		; dy >= 0, dx >= 0
		;  	dy <= dx 	?	пологий
		;	dy > dx 	?	крутой
		lhld line_dx 	                ; l = dx, h = dy
		mov a, l 
		cmp h				;если dy<=dx
		jnc  line_gentle	        ;то склон пологий
		
		; крутой склон
		; начальное значение D
		; D = 2 * dx - dy
		lda line_dy
		cma
		mov e,a
		mvi d,0FFh
		inx d				; de = -dy

		lhld line_dx
		mvi h,0
		dad h
		shld line1_mod_dx_s+1		; сохранить 2*dx константой
		; сохранить 2*dx константой
		mov a,l
		sta line1_mod_dx_sLo+1		; сохранить 2*dx константой
		mov a,h
		sta line1_mod_dx_sHi+1		; сохранить 2*dx константой

		dad d				; hl = 2 * dx - dy
		push h				; поместить в стек значение D = 2 * dx - dy
		xchg				; hl = -dy
		
		dad h				; hl = -2*dy
line1_mod_dx_s:
		lxi d,0				; de = 2*dx
		dad d 				; hl = 2 * dx - 2 * dy
		; сохранить как конст
		mov a,l
		sta line1_mod_dxdy_sLo+1
		mov a,h
		sta line1_mod_dxdy_sHi+1

		lhld line_y	;h=x; l=y
		xchg		;d=x; e=y
		mvi a,111b
		ana d
		adi PixelMask&255
		mov l,a
		mvi a,PixelMask>>8
		aci 0
		mov h,a			; hl - адрес маски в PixelMask
		mov c,m 		; начальное значение маски пикселя
		
		mvi a,11111000b
		ana d
		rrc
		rrc 
		;#stc 
		;#rar 
		rrc
line_bitplane_1 equ .+1
                ori 080h

		xchg 		        ; l=y
		mov h,a		        ; h=старший байт экранного адреса
		pop d			; de = 2 * dx - dy

		lda line_dy
		mov b,a

		;------ крутой цикл (s/steep) -----
line1_loop_s:	; <--- точка входа в крутой цикл --->
		mov a,m
SetPixelMode_s1:
		xra c
		mov m,a	 		; записать в память результат с измененным пикселем

		; if D > 0
		xra a
		ora d
		jp line1_then_s
line1_else_s: 	; else от if D > 0
line1_mod_yinc_s2:
		inr l			; y = y +/- 1
		mov a,m
SetPixelMode_s2:
		xra c
		mov m,a	 		; записать в память результат с измененным пикселем
		dcr b
		rz
line1_mod_dx_sLo:
		mvi a,0		        ; изменяемый код (2*dx) младший байт
		add e
		mov e,a
line1_mod_dx_sHi:
		mvi a,0		        ; изменяемый код (2*dx) старший байт
		adc d
		mov d,a
		;в итоге de = de + 2*dx
		jm line1_else_s

line1_then_s:
line1_mod_yinc_s1:
		inr l			; y = y +/- 1
		mov a,c
		rrc 			; xincLo
		mov c,a
		jnc $+4
		inr h			; xincHi
SetPixelMode_s3:
		xra m
		mov m,a	 		; записать в память результат с измененным пикселем
		dcr b
		rz
line1_mod_dxdy_sLo:
		mvi a,0			; изменяемый код: 2*(dx-dy) младший байт
		add e
		mov e,a
line1_mod_dxdy_sHi:
		mvi a,0			; изменяемый код: 2*(dx-dy) старший байт
		adc d
		mov d,a
		;в итоге de = de + 2*(dx-dy)
		jm line1_else_s
		jmp line1_then_s
		; --- конец тела крутого цикла ---

		
line_gentle:
		; склон пологий
		; начальное значение D
		; D = 2 * dy - dx
		lda line_dx
		cma
		mov e,a
		mvi d,0FFh
		inx d				; de = -dx

		lhld line_dy
		mvi h,0
		dad h
		shld line1_mod_dy_g+1		; сохранить 2*dy константой
		; сохранить 2*dy константой
		mov a,l
		sta line1_mod_dy_gLo+1
		mov a,h
		sta line1_mod_dy_gHi+1


		dad d				; hl = 2 * dy - dx
		push h				; поместить в стек значение D = 2 * dy - dx
		xchg				; hl = -dx
		
		dad h				; hl = -2*dx
line1_mod_dy_g:
		lxi d,0
		dad d 				; hl = 2 * dy - 2 * dx
		mov a,l
		sta line1_mod_dydx_gLo+1        ; сохранить как конст
		mov a,h
		sta line1_mod_dydx_gHi+1        ; сохранить как конст
		
		pop d				; de = 2 * dy - dx

		; основной цикл рисования линии
		; версия для пологого склона (_g)
		lhld line_x	;l=x h=dx
		mov c,l		;c=x
		mov b,h		;line_dx
		lda line_y	;a=y
		sta line_yx_g+1

		; подготовить начальное значение регистра c
		mvi a, 111b 		; сначала вычисляем смещение 
		ana c 			; пикселя в PixelMask (с = x)
		adi PixelMask&255
		mov l,a
		mvi a,PixelMask>>8
		aci 0
		mov h,a			; hl - адрес маски в PixelMask
		mvi a,11111000b
		ana c
		rrc
		rrc

		rrc
line_bitplane_2 equ .+1
                ori 080h

		;#stc
		;#rar
		;mvi a, 080h
		sta line_yx_g+2	; 0x80 | (x >> 3), l = y

		xra a
		cmp b		        ;dx=0?
		mov c,m			; маска
line_yx_g:
		lxi h, 0                ; hl указывает в экран
		jnz line1_loop_g	;если dx<>0, то переход на обычное рисование линии
;если dx=0, то ставим одну точку
                mov a,m
SetPixelMode_g2:
		xra c
		mov m,a 		; записать в память
		ret

		;------ пологий цикл (g/gentle) -----
line1_loop_g:	; <--- точка входа в пологий цикл --->
		mov a,m
SetPixelMode_g1:
		xra c
		mov m,a 		; записать в память

		; if D > 0
		xra a
		ora d
		jp line1_then_g
line1_else_g: 	; else от if D > 0
		mov a,c
		rrc 			; сдвинуть вправо (следующий X)
		mov c,a			; сохраняем текущее значение маски
		jnc $+4 		; если не провернулся через край
		inr h			;line_x += 1
SetPixelMode_g3:
		xra m
		mov m,a 		; записать в память
		dcr b			; dx -= 1
		rz

line1_mod_dy_gLo:
		mvi a,0		        ; изменяемый код (2*dy) младший байт
		add e
		mov e,a
line1_mod_dy_gHi:
		mvi a,0		        ; изменяемый код (2*dy) старший байт
		adc d
		mov d,a
		;в итоге de= de + 2*dy
		jm line1_else_g

line1_then_g:
line1_mod_yinc_g:
		inr l			; изменяемый код: line_y += yinc или line_y -= yinc
		mov a,c
		rrc 			; сдвинуть вправо (следующий X)
		mov c,a			; сохраняем текущее значение маски
		jnc $+4 		; если не провернулся через край
		inr h			;line_x += 1
SetPixelMode_g4:
		xra m
		mov m,a 		; записать в память
		dcr b			; dx -= 1
		rz
line1_mod_dydx_gLo:
		mvi a,0		        ; изменяемый код: 2*(dy-dx) младший байт
		add e
		mov e,a
line1_mod_dydx_gHi:
		mvi a,0		        ; изменяемый код: 2*(dy-dx) старший байт
		adc d
		mov d,a
		;в итоге de = de + 2*(dy-dx)
		jm line1_else_g
		jmp line1_then_g
		; --- конец тела пологого цикла ---

		; --- конец line() ---
		
Cls:
		lxi	h,08000h
		mvi	e,0
		xra	a
ClrScr:
		mov	m,e
		inx	h
		cmp	h
		jnz	ClrScr
		ret

		; выход:
		; HL - число от 1 до 65535
rnd16:
		lxi h, 65535
		dad h
		shld rnd16+1
		rnc
		mvi a,00000001b ;перевернул 80h - 10000000b
		xra l
		mov l,a
		mvi a,01101000b	;перевернул 16h - 00010110b
		xra h
		mov h,a
		shld rnd16+1
		ret

col_r           db 0
col_g           db 86
col_b           db 170
                
                ; cycle palette
                ; a = frame counter
cyclecolors:
                mvi c, 3*16/2-8/2   ; 3 palettes, 16 colours each, skip one, first 8 no change

                rar
                jc cycle_bleu
                rar
                jc cycle_green
cycle_red                
                lxi h, col_r
                inr m \ inr m \ inr m
                ;call cosm
                call triam
                
                jmp update_red
cycle_green
                lxi h, col_g
                inr m \ inr m
                call triam
                
                jmp update_green

cycle_bleu                
                lxi h, col_b
                inr m
                call triam
                
                ;call update_bleu
                ;ret
update_bleu
                mov a, e
                ani 300q
                mov e, a

                lxi h, colors_3+15
update_bleu_next
                dcx h           ; point to colour #14
                mov a, m
                ora a
                jz update_bleu_skip
                ani 077q
                ora e
                mov m, a
update_bleu_skip                
                dcx h
                dcr c
                jnz update_bleu_next
                ret 

                ; e = red value
update_red      
                mov a, e
                rlc \ rlc \ rlc
                ani 7
                jnz $+4
                inr a
                mov e, a

                lxi h, colors_3+15
update_red_next
                dcx h           ; point to colour #14
                mov a, m
                ora a
                jz update_red_skip
                ani 370q
                ora e
                mov m, a
update_red_skip                
                dcx h
                dcr c
                jnz update_red_next
                ret 

                ; e = red value
update_green      
                mov a, e
                rar
                rar
                ani 070q
                jnz $+5
                adi 010q
                mov e, a

                lxi h, colors_3+15
update_green_next
                dcx h           ; point to colour #14
                mov a, m
                ora a
                jz update_green_skip
                ani 307q
                ora e
                mov m, a
update_green_skip                
                dcx h
                dcr c
                jnz update_green_next
                ret 

                
colors:         ; octal bgr 2:3:3
                ;  1_0_0_0: $80  : 1000 1010 1100 1110
                ;  0_1_0_0: $a0  : 0100 0110 1100 1110
                ;  0_0_1_0: $c0  : 0010 0110 1010 1110
                ;  0_0_0_1; $e0
colors_1                
                .db 000q,377q,000q,377q,000q,377q,000q,377q
                .db 307q,377q,307q,377q,307q,377q,307q,377q ; -- all $8000
colors_2                
                .db 000q,377q,000q,377q,317q,377q,317q,377q
                .db 000q,377q,000q,377q,317q,377q,317q,377q ; -- all $a000
colors_3
                .db 000q,377q,327q,377q,000q,377q,327q,377q
                .db 000q,377q,327q,377q,000q,377q,327q,377q ; -- all $c000

colors_nil:     .db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

costab          .db 255,255,255,255,254,254,254,253,253,252,251,250,249,249,247,246,245,244,243,241,240,238,237,235,233,232,230,228,226,224,222,220,217,215,213,210,208,206,203,201,198,195,193,190,187,184,182,179,176,173,170,167,164,161,158,155,152,149,146,142,139,136,133,130,127,124,120,117,114,111,108,105,102,99,96,93,90,87,84,81,78,75,72,69,66,64,61,58,56,53,51,48,46,43,41,39,37,34,32,30,28,26,24,23,21,19,17,16,14,13,12,10,9,8,7,6,5,4,3,3,2,2,1,1,0,0,0,0,0,0,0,0,1,1,2,2,3,3,4,5,6,7,8,9,10,12,13,14,16,17,19,21,23,24,26,28,30,32,34,37,39,41,43,46,48,51,53,56,58,61,64,66,69,72,75,78,81,84,87,90,93,96,99,102,105,108,111,114,117,120,124,127,130,133,136,139,142,146,149,152,155,158,161,164,167,170,173,176,179,182,184,187,190,193,195,198,201,203,206,208,210,213,215,217,220,222,224,226,228,230,232,233,235,237,238,240,241,243,244,245,246,247,249,249,250,251,252,253,253,254,254,254,255,255,255,255


		; Вывести транспарант посреди экрана
		; Мы должны немного обгонять луч, чтобы
		; к началу сканирования первой строки
		; верх картинки уже был готов
		; blit_src1+1 - откуда копируем 1
		; blit_src2+1 - откуда копируем 2 (глючный вариант)
		; blit_line-1 - число пар строк
		; blit_line1-1 - размер по горизонтали в байтах / 8
blit_xy         equ blit_xy_+1
blit:
		lxi h, 0
		dad sp
		shld blit_sp+1
blit_src1:	lxi sp, hello_jpg
                lda rnd16+2     ; выбираем когда показывать глючный кадр
                mov b, a
                lda framecnt
                rar \ rar
                ana b
                rar
                jnc $+6
blit_src2:      lxi sp, hello_jpg2
blit_xy_:	lxi h, LOGOXY
                
                ; adjust for scroll direction
                lda fasign
                rar
		lda frame_scroll
		sbi 0
		;
		
		add l
		mov l, a
                mov b, h        ; сохраним в b первый столб
blit_height     equ $+1
                mvi a, 124/2    ; ПАРАМЕТР: число пар строк
                ; ПАРАМЕТР: blit_linej = blit_line1 * (4 - width8) * blit_linej_sz
blit_linej_sz   equ blit_line_c2 - blit_line_c1
blit_widthj     equ $+1                
blit_linej:      jmp blit_line_c1
blit_line_c1:   ; [8 columns 1]
                ; {1}
                pop d           ; берем два столбца строки в de
                mov m, e        ; записываем в экран первый столб
                inr h           ; столб += 1
                mov m, d        ; записываем второй столб
                inr h           ; столб += 1
                ; {2,3,4}
                db $d1,$73,$24,$72,$24
                db $d1,$73,$24,$72,$24
                db $d1,$73,$24,$72,$24
blit_line_c2:                
                ; [8 columns 2]
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                
                ; [8 columns 3]
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d \ inr h

                ; [8 columns 4]
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d \ inr h
                pop d \ mov m, e \ inr h \ mov m, d ; \ inr h
                

                dcr a           ; уменьшаем счетчик пар строк
                jz blit_sp      ; изя всё
                dcr l           ; следующая строка (через одну)
                dcr l
                mov h, b        ; снова первый столбец
                jmp blit_linej

blit_sp:	lxi sp, 0
		ret

                ; затереть область экрана нулями
                ; blit_xy -> куда затирать
                ; height = ?
                ; width = ?
wipe_height     equ wipe_line-1
wipe_width      equ wipe_line1-1
wipe_xy         equ wipe_xy_+1

wipe:		
wipe_xy_:       lxi h, LOGOXY                
                ; adjust for scroll direction
                lda fasign
                rar
		lda frame_scroll_prev
		sbi 0
		;
		
		add l
		mov l, a

                mov b, h        ; сохраним в b первый столб

                lxi d, 0
                mvi a, 124/2    ; ПАРАМЕТР: число пар строк
wipe_line:
                mvi c, 128/8/8  ; ПАРАМЕТР: размер по горизонтали в байтах/8
wipe_line1:
                mov m, d \ inr h \ mov m, d \ inr h
                mov m, d \ inr h \ mov m, d \ inr h
                mov m, d \ inr h \ mov m, d \ inr h
                mov m, d \ inr h \ mov m, d \ inr h
                dcr c                
                jnz wipe_line1
                dcr a
                rz
                dcr l \ dcr l
                mov h, b
                jmp wipe_line
                
bsszero:
                xra a
		lxi h, bss_start
                mvi c, bss_length
bsszero_L1:     mov m, a
                inx h
                dcr c
                jnz bsszero_L1

hello_jpg
;Opened image max3-top.png 128x120
db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$1f,$ff,$ff,$ff,$e0,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$01,$80,$ff,$ff,$ff,$ff,$f8,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$18,$07,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00
db $00,$00,$01,$81,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00,$00,$00
db $00,$00,$06,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00,$00,$00
db $00,$00,$60,$1f,$ff,$ff,$ff,$ff,$ff,$ff,$e0,$00,$00,$00,$00,$00
db $00,$00,$80,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$00,$00
db $00,$02,$00,$3f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00
db $00,$06,$00,$3f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00
db $00,$08,$0e,$07,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00,$00
db $00,$10,$1c,$07,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00,$00
db $00,$20,$20,$03,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$00
db $00,$60,$00,$00,$00,$7f,$ff,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$00
db $00,$40,$00,$01,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$00
db $00,$80,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00
db $01,$80,$c0,$1f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00
db $01,$00,$80,$3f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$00
db $02,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00
db $02,$00,$01,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00
db $04,$00,$01,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00
db $04,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00
db $06,$00,$00,$1f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00
db $02,$00,$c0,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00
db $02,$00,$f0,$03,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00
db $02,$00,$c0,$07,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00
db $02,$00,$00,$0f,$ff,$ff,$ef,$ff,$f0,$3c,$3f,$ff,$c0,$00,$00,$00
db $04,$00,$00,$0f,$ff,$ff,$e7,$ff,$3f,$ff,$ff,$ff,$b0,$00,$00,$00
db $04,$00,$00,$1f,$ff,$ff,$f3,$fb,$fc,$00,$ff,$ff,$b8,$00,$00,$00
db $07,$80,$40,$3f,$ff,$ff,$f1,$f3,$e0,$00,$7f,$ff,$f8,$00,$00,$00
db $00,$80,$00,$7f,$ff,$ff,$e1,$de,$00,$00,$7f,$ff,$f8,$00,$00,$00
db $00,$80,$00,$ff,$ff,$ff,$ff,$38,$00,$00,$6f,$ff,$f8,$00,$00,$00
db $01,$c0,$00,$ff,$c0,$00,$f1,$f0,$00,$00,$6f,$ff,$fe,$00,$00,$00
db $00,$40,$00,$3c,$1f,$fe,$31,$e0,$00,$00,$6f,$ff,$fe,$00,$00,$00
db $00,$40,$00,$df,$ff,$e7,$ff,$e0,$00,$00,$6f,$ff,$fc,$00,$00,$00
db $00,$30,$1e,$78,$00,$01,$fe,$40,$00,$00,$6f,$ff,$fe,$00,$00,$00
db $00,$0e,$13,$80,$00,$00,$27,$e0,$00,$00,$ef,$ff,$fe,$00,$00,$00
db $00,$02,$07,$00,$00,$00,$0f,$fc,$00,$00,$df,$ff,$fe,$00,$00,$00
db $00,$02,$1a,$00,$00,$00,$1f,$ff,$00,$03,$3f,$ff,$ff,$00,$00,$00
db $00,$01,$00,$00,$00,$00,$1f,$ff,$80,$1e,$ff,$ff,$fe,$00,$00,$00
db $00,$00,$80,$00,$00,$00,$1f,$ff,$f0,$e3,$ff,$ff,$ff,$00,$00,$00
db $00,$00,$58,$00,$00,$00,$1f,$ff,$ff,$cf,$ff,$ff,$ff,$00,$00,$00
db $00,$00,$3c,$00,$00,$00,$1f,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00
db $00,$00,$1f,$00,$00,$00,$1f,$ff,$bf,$ff,$ff,$ff,$ff,$00,$00,$00
db $00,$00,$09,$c0,$00,$00,$1f,$ff,$cf,$ff,$ff,$ff,$fe,$00,$00,$00
db $00,$00,$08,$e4,$00,$e0,$1f,$ff,$ef,$3f,$ff,$ff,$b8,$00,$00,$00
db $00,$00,$04,$0f,$ff,$80,$1f,$fc,$f7,$e3,$ff,$ff,$c0,$00,$00,$00
db $00,$00,$02,$00,$40,$00,$0c,$0f,$ff,$f0,$ff,$ff,$c0,$00,$00,$00
db $00,$00,$01,$00,$1f,$00,$00,$1f,$ff,$fc,$3f,$ff,$e0,$00,$00,$00
db $00,$00,$00,$80,$3e,$00,$00,$3f,$ff,$fc,$1f,$ff,$e0,$00,$00,$00
db $00,$00,$00,$40,$1c,$00,$00,$7f,$ff,$fe,$3f,$ff,$f0,$00,$00,$00
db $00,$00,$00,$10,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$08,$00,$00,$00,$ff,$ff,$ff,$9f,$ff,$f0,$00,$00,$00
db $00,$00,$00,$08,$00,$00,$00,$ff,$c0,$01,$8f,$ff,$f0,$00,$00,$00
db $00,$00,$00,$04,$00,$00,$00,$38,$1f,$ff,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$02,$00,$00,$00,$03,$ff,$ff,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$01,$00,$00,$00,$0f,$fe,$00,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$00,$80,$00,$00,$3f,$f8,$07,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$00,$40,$00,$00,$78,$00,$7f,$ff,$ff,$f0,$00,$00,$00
max_bottom
;Opened image max3-bottom.png 192x67
db $00,$00,$00,$00,$20,$00,$00,$00,$07,$ff,$ff,$ff,$f0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$10,$00,$00,$00,$0f,$fb,$ff,$ff,$ef,$ff,$ff,$ff,$e0,$00,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$08,$00,$00,$00,$1f,$e7,$ff,$ff,$ef,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00,$00
db $00,$00,$00,$00,$04,$00,$00,$00,$0f,$3f,$ff,$ff,$cf,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$00
db $00,$00,$00,$00,$03,$00,$00,$00,$01,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$80,$00,$00,$0f,$ff,$ff,$ff,$bf,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$40,$00,$00,$3f,$ff,$ff,$ff,$bf,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$10,$00,$00,$ff,$ff,$ff,$ff,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00
db $00,$00,$00,$00,$00,$0c,$00,$03,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00
db $00,$00,$00,$00,$00,$20,$00,$0f,$ff,$ff,$ff,$fe,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$00,$00,$60,$00,$1f,$ff,$ff,$ff,$fe,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$00,$02,$01,$00,$3f,$ff,$ff,$ff,$fd,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00
db $00,$00,$00,$00,$18,$01,$60,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$bf,$ff,$00,$00,$00
db $00,$00,$00,$00,$40,$00,$80,$07,$ff,$8f,$ff,$cf,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00
db $00,$00,$00,$01,$80,$00,$80,$03,$ff,$83,$ff,$3f,$ff,$ff,$ff,$ff,$3f,$ff,$ff,$ff,$ff,$80,$00,$00
db $00,$00,$00,$0e,$00,$00,$80,$41,$fc,$00,$38,$ff,$ff,$ff,$ff,$fe,$ff,$ff,$ff,$bf,$ff,$c0,$00,$00
db $00,$00,$00,$3c,$00,$00,$40,$03,$80,$00,$03,$ff,$ff,$ff,$ff,$fd,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00
db $00,$00,$01,$f8,$00,$00,$40,$00,$00,$38,$07,$ff,$ff,$ff,$ff,$fb,$ff,$ff,$ff,$df,$ff,$c0,$00,$00
db $00,$00,$03,$f0,$00,$00,$40,$00,$00,$e0,$0f,$ff,$ff,$ff,$ff,$f7,$ff,$ff,$ff,$df,$ff,$e0,$00,$00
db $00,$00,$1e,$00,$00,$00,$20,$00,$00,$00,$1f,$ff,$ff,$ff,$ff,$f7,$ff,$ff,$ff,$ef,$ff,$e0,$00,$00
db $00,$00,$f0,$00,$00,$00,$20,$00,$00,$00,$7f,$ff,$ff,$ff,$ff,$f9,$ff,$ff,$ff,$ef,$ff,$f8,$00,$00
db $00,$03,$c0,$00,$00,$00,$20,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$3f,$ff,$ff,$f7,$ff,$ff,$00,$00
db $00,$07,$80,$00,$00,$00,$20,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$df,$ff,$ff,$f7,$ff,$ff,$80,$00
db $00,$3e,$00,$00,$00,$00,$10,$00,$00,$00,$7f,$ff,$ff,$ff,$ff,$ff,$fb,$ff,$ff,$f7,$ff,$ff,$c0,$00
db $00,$f0,$00,$00,$00,$00,$10,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$fc,$7f,$ff,$f7,$ff,$ff,$f0,$00
db $03,$c0,$00,$00,$00,$00,$10,$00,$00,$00,$00,$3f,$ff,$ff,$ff,$ff,$fc,$7f,$ff,$f7,$ff,$ff,$f8,$00
db $07,$c0,$00,$00,$00,$00,$10,$00,$00,$00,$00,$1f,$ff,$ff,$ff,$ff,$fc,$7f,$ff,$f3,$ff,$ff,$f8,$00
db $3f,$00,$00,$00,$00,$00,$08,$00,$00,$60,$00,$03,$ff,$ff,$ff,$ff,$fc,$ff,$ff,$ff,$ff,$ff,$fc,$00
db $fe,$00,$00,$00,$00,$00,$08,$00,$00,$e0,$00,$00,$ff,$ff,$ff,$ff,$fc,$ff,$ff,$ff,$ff,$ff,$fe,$00
db $f8,$00,$00,$00,$00,$00,$08,$00,$01,$c0,$00,$00,$3f,$ff,$ff,$ff,$fe,$ff,$ff,$ff,$ff,$ff,$fe,$00
db $f0,$00,$00,$00,$00,$00,$04,$00,$03,$c0,$00,$00,$0f,$ff,$ff,$ff,$fe,$ff,$ff,$ff,$ff,$ff,$fe,$00
db $e0,$00,$00,$00,$00,$00,$04,$00,$07,$80,$00,$70,$03,$ef,$ff,$ff,$fe,$ff,$ff,$f1,$ff,$ff,$ff,$00
db $c0,$00,$00,$00,$00,$00,$04,$00,$1f,$80,$00,$7f,$fc,$01,$ff,$ff,$ff,$ff,$ff,$fb,$ff,$ff,$ff,$80
db $c0,$00,$00,$00,$00,$00,$02,$00,$1f,$80,$00,$3f,$ff,$01,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0
db $80,$00,$00,$00,$00,$00,$02,$00,$3f,$00,$00,$3f,$ff,$01,$ff,$ff,$ff,$ff,$db,$ff,$ff,$ff,$ff,$f0
db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

hello_jpg2
db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$0f,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$3f,$ff,$ff,$ff,$c0,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$60,$3f,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$30,$0f,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00,$00
db $00,$00,$01,$81,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00,$00,$00
db $00,$00,$01,$83,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$00,$00
db $00,$00,$30,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$00,$00
db $00,$00,$40,$3f,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00
db $00,$04,$00,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00,$00
db $00,$06,$00,$3f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00
db $00,$04,$07,$03,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00,$00
db $00,$20,$38,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00,$00
db $00,$08,$08,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$00
db $00,$c0,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$e0,$00,$00,$00,$00
db $00,$20,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00
db $00,$40,$00,$00,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00
db $01,$80,$c0,$1f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00
db $02,$01,$00,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f8,$00,$00,$00,$00
db $04,$00,$01,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$00
db $01,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00
db $02,$00,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00
db $01,$00,$00,$3f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$e0,$00,$00,$00
db $0c,$00,$00,$3f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00
db $02,$00,$c0,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00
db $02,$00,$f0,$03,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c0,$00,$00,$00
db $04,$01,$80,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$80,$00,$00,$00
db $04,$00,$00,$1f,$ff,$ff,$df,$ff,$e0,$78,$7f,$ff,$80,$00,$00,$00
db $08,$00,$00,$1f,$ff,$ff,$cf,$fe,$7f,$ff,$ff,$ff,$60,$00,$00,$00
db $08,$00,$00,$3f,$ff,$ff,$e7,$f7,$f8,$01,$ff,$ff,$70,$00,$00,$00
db $0f,$00,$80,$7f,$ff,$ff,$e3,$e7,$c0,$00,$ff,$ff,$f0,$00,$00,$00
db $01,$00,$00,$ff,$ff,$ff,$c3,$bc,$00,$00,$ff,$ff,$f0,$00,$00,$00
db $00,$20,$00,$3f,$ff,$ff,$ff,$ce,$00,$00,$1b,$ff,$fe,$00,$00,$00
db $00,$70,$00,$3f,$f0,$00,$3c,$7c,$00,$00,$1b,$ff,$ff,$80,$00,$00
db $00,$80,$00,$78,$3f,$fc,$63,$c0,$00,$00,$df,$ff,$fc,$00,$00,$00
db $00,$80,$01,$bf,$ff,$cf,$ff,$c0,$00,$00,$df,$ff,$f8,$00,$00,$00
db $00,$60,$3c,$f0,$00,$03,$fc,$80,$00,$00,$df,$ff,$fc,$00,$00,$00
db $00,$0e,$13,$80,$00,$00,$27,$e0,$00,$00,$ef,$ff,$fe,$00,$00,$00
db $00,$02,$07,$00,$00,$00,$0f,$fc,$00,$00,$df,$ff,$fe,$00,$00,$00
db $00,$00,$86,$80,$00,$00,$07,$ff,$c0,$00,$cf,$ff,$ff,$c0,$00,$00
db $00,$01,$00,$00,$00,$00,$1f,$ff,$80,$1e,$ff,$ff,$fe,$00,$00,$00
db $00,$00,$40,$00,$00,$00,$0f,$ff,$f8,$71,$ff,$ff,$ff,$80,$00,$00
db $00,$00,$2c,$00,$00,$00,$0f,$ff,$ff,$e7,$ff,$ff,$ff,$80,$00,$00
db $00,$00,$78,$00,$00,$00,$3f,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00
db $00,$00,$3e,$00,$00,$00,$3f,$ff,$7f,$ff,$ff,$ff,$fe,$00,$00,$00
db $00,$00,$04,$e0,$00,$00,$0f,$ff,$e7,$ff,$ff,$ff,$ff,$00,$00,$00
db $00,$00,$02,$39,$00,$38,$07,$ff,$fb,$cf,$ff,$ff,$ee,$00,$00,$00
db $00,$00,$02,$07,$ff,$c0,$0f,$fe,$7b,$f1,$ff,$ff,$e0,$00,$00,$00
db $00,$00,$01,$00,$20,$00,$06,$07,$ff,$f8,$7f,$ff,$e0,$00,$00,$00
db $00,$00,$00,$40,$07,$c0,$00,$07,$ff,$ff,$0f,$ff,$f8,$00,$00,$00
db $00,$00,$00,$20,$0f,$80,$00,$0f,$ff,$ff,$07,$ff,$f8,$00,$00,$00
db $00,$00,$00,$10,$07,$00,$00,$1f,$ff,$ff,$8f,$ff,$fc,$00,$00,$00
db $00,$00,$00,$20,$00,$00,$01,$ff,$ff,$ff,$ff,$ff,$e0,$00,$00,$00
db $00,$00,$00,$02,$00,$00,$00,$3f,$ff,$ff,$e7,$ff,$fc,$00,$00,$00
db $00,$00,$00,$04,$00,$00,$00,$7f,$e0,$00,$c7,$ff,$f8,$00,$00,$00
db $00,$00,$00,$04,$00,$00,$00,$38,$1f,$ff,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$00,$80,$00,$00,$00,$ff,$ff,$ff,$ff,$fc,$00,$00,$00
db $00,$00,$00,$00,$40,$00,$00,$03,$ff,$80,$3f,$ff,$fc,$00,$00,$00
db $00,$00,$00,$00,$80,$00,$00,$3f,$f8,$07,$ff,$ff,$f0,$00,$00,$00
db $00,$00,$00,$00,$40,$00,$00,$78,$00,$7f,$ff,$ff,$f0,$00,$00,$00

max_bottom2
db $00,$00,$00,$00,$08,$00,$00,$00,$01,$ff,$ff,$ff,$fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$40,$00,$00,$00,$3f,$ef,$ff,$ff,$bf,$ff,$ff,$ff,$80,$00,$00,$00,$00,$00,$00,$00
db $00,$00,$00,$00,$01,$00,$00,$00,$03,$fc,$ff,$ff,$fd,$ff,$ff,$ff,$ff,$ff,$ff,$f0,$00,$00,$00,$00
db $00,$00,$00,$00,$08,$00,$00,$00,$1e,$7f,$ff,$ff,$9f,$ff,$ff,$ff,$ff,$ff,$ff,$f8,$00,$00,$00,$00
db $00,$00,$00,$00,$06,$00,$00,$00,$03,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$80,$00,$00,$0f,$ff,$ff,$ff,$bf,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$08,$00,$00,$07,$ff,$ff,$ff,$f7,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$e0,$00,$00,$00
db $00,$00,$00,$00,$00,$40,$00,$03,$ff,$ff,$ff,$fd,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe,$00,$00,$00,$00
db $00,$00,$00,$00,$00,$01,$80,$00,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f8,$00,$00,$00
db $00,$00,$00,$00,$00,$10,$00,$07,$ff,$ff,$ff,$ff,$3f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f8,$00,$00,$00
db $00,$00,$00,$00,$00,$c0,$00,$3f,$ff,$ff,$ff,$fd,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$e0,$00,$00,$00
db $00,$00,$00,$00,$02,$01,$00,$3f,$ff,$ff,$ff,$fd,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fc,$00,$00,$00
db $00,$00,$00,$00,$18,$01,$60,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$bf,$ff,$00,$00,$00
db $00,$00,$00,$00,$80,$01,$00,$0f,$ff,$1f,$ff,$9f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00
db $00,$00,$00,$00,$c0,$00,$40,$01,$ff,$c1,$ff,$9f,$ff,$ff,$ff,$ff,$9f,$ff,$ff,$ff,$ff,$c0,$00,$00
db $00,$00,$00,$0e,$00,$00,$80,$41,$fc,$00,$38,$ff,$ff,$ff,$ff,$fe,$ff,$ff,$ff,$bf,$ff,$c0,$00,$00
db $00,$00,$00,$07,$80,$00,$08,$00,$70,$00,$00,$7f,$ff,$ff,$ff,$ff,$bf,$ff,$ff,$ff,$ff,$f8,$00,$00
db $00,$00,$03,$f0,$00,$00,$80,$00,$00,$70,$0f,$ff,$ff,$ff,$ff,$f7,$ff,$ff,$ff,$bf,$ff,$80,$00,$00
db $00,$00,$03,$f0,$00,$00,$40,$00,$00,$e0,$0f,$ff,$ff,$ff,$ff,$f7,$ff,$ff,$ff,$df,$ff,$e0,$00,$00
db $00,$00,$07,$80,$00,$00,$08,$00,$00,$00,$07,$ff,$ff,$ff,$ff,$fd,$ff,$ff,$ff,$fb,$ff,$f8,$00,$00
db $00,$01,$e0,$00,$00,$00,$40,$00,$00,$00,$ff,$ff,$ff,$ff,$ff,$f3,$ff,$ff,$ff,$df,$ff,$f0,$00,$00
db $00,$0f,$00,$00,$00,$00,$80,$00,$00,$03,$ff,$ff,$ff,$ff,$ff,$fc,$ff,$ff,$ff,$df,$ff,$fc,$00,$00
db $00,$03,$c0,$00,$00,$00,$10,$00,$00,$00,$7f,$ff,$ff,$ff,$ff,$ff,$ef,$ff,$ff,$fb,$ff,$ff,$c0,$00
db $00,$07,$c0,$00,$00,$00,$02,$00,$00,$00,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$7f,$ff,$fe,$ff,$ff,$f8,$00
db $00,$1e,$00,$00,$00,$00,$02,$00,$00,$00,$00,$1f,$ff,$ff,$ff,$ff,$ff,$8f,$ff,$fe,$ff,$ff,$fe,$00
db $03,$c0,$00,$00,$00,$00,$10,$00,$00,$00,$00,$3f,$ff,$ff,$ff,$ff,$fc,$7f,$ff,$f7,$ff,$ff,$f8,$00
db $01,$f0,$00,$00,$00,$00,$04,$00,$00,$00,$00,$07,$ff,$ff,$ff,$ff,$ff,$1f,$ff,$fc,$ff,$ff,$fe,$00
db $0f,$c0,$00,$00,$00,$00,$02,$00,$00,$18,$00,$00,$ff,$ff,$ff,$ff,$ff,$3f,$ff,$ff,$ff,$ff,$ff,$00
db $fe,$00,$00,$00,$00,$00,$08,$00,$00,$e0,$00,$00,$ff,$ff,$ff,$ff,$fc,$ff,$ff,$ff,$ff,$ff,$fe,$00
db $f0,$00,$00,$00,$00,$00,$10,$00,$03,$80,$00,$00,$7f,$ff,$ff,$ff,$fd,$ff,$ff,$ff,$ff,$ff,$fc,$01
db $78,$00,$00,$00,$00,$00,$02,$00,$01,$e0,$00,$00,$07,$ff,$ff,$ff,$ff,$7f,$ff,$ff,$ff,$ff,$ff,$00
db $70,$00,$00,$00,$00,$00,$02,$00,$03,$c0,$00,$38,$01,$f7,$ff,$ff,$ff,$7f,$ff,$f8,$ff,$ff,$ff,$80
db $80,$00,$00,$00,$00,$00,$08,$00,$3f,$00,$00,$ff,$f8,$03,$ff,$ff,$ff,$ff,$ff,$f7,$ff,$ff,$ff,$01
db $60,$00,$00,$00,$00,$00,$01,$00,$0f,$c0,$00,$1f,$ff,$80,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$e0
db $80,$00,$00,$00,$00,$00,$02,$00,$3f,$00,$00,$3f,$ff,$01,$ff,$ff,$ff,$ff,$db,$ff,$ff,$ff,$ff,$f0
db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00


.include messages.inc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;         GIGACHAD - 16       ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; total number of scheduler tasks                
n_tasks         equ 14

; task stack size 
task_stack_size equ 22

                xra a
                out $10
                
                mvi a, $c9
                sta $38

;brutal_restart:                
;                lxi sp, $100
            
                ; intro song
song_1:         dw songA_00, songA_01, songA_02, songA_03, songA_04, songA_05, songA_06
                dw songA_07, songA_08, songA_09, songA_10, songA_11, songA_12, songA_13            


                ; main song
song_0:         dw songB_00, songB_01, songB_02, songB_03, songB_04, songB_05, songB_06
                dw songB_07, songB_08, songB_09, songB_10, songB_11, songB_12, songB_13            
            
create_sptr     dw 0

                ; create 14 tasks for song
                ; hl = address of array (song_00, song_01, ...song_13)
create_song_tasks:
                xra a
                shld create_sptr
                
                lxi b, buffer00
                lxi h, stack_00 + task_stack_size

create_song_tasks_L1:
                push h
                lhld create_sptr
                mov e, m \ inx h \ mov d, m \ inx h
                shld create_sptr
                pop h
                
                push b
                push h
                call dzx0_create
                pop h
                ; task_stack += task_stack_size 
                mvi c, task_stack_size & 255
                mvi b, task_stack_size >> 8
                dad b   
                
                ; task_buffer += 256
                pop b
                inr b

                inr a
                cpi 14
                jnz create_song_tasks_L1

                ret

                ; hl = array of [song_00, song_01, ... song_13]
gigachad_init:
                ;call create_tasks
                call create_song_tasks
                call scheduler_init
                call gigachad_disable

                mvi a, -16
                sta ay_nline
                mvi a, -1
                sta gigachad_nfrm

                ret
                
gigachad_enable:
                xra a
                jmp $+5
gigachad_disable:
                mvi a, $c9
                sta gigachad_frame
                ret
                
                ; silently process first 16 frames 
                ; can only be called after gigachad_init
gigachad_precharge
                lxi h, gigachad_nfrm
                mov a, m
                inr a
                ani $f
                mov m, a
                cpi 14
                
                jp $+6
                call scheduler_tick
                lxi h, ay_nline
                inr m
                jnz gigachad_precharge                
                ret

                
gigachad_frame:
                ret
                lxi h, gigachad_nfrm
                mov a, m
                inr a
                ani $f
                mov m, a
                cpi 14
                
                jp $+6
                call scheduler_tick
                lxi h, ay_nline
                inr m
                call ay_send

                ret

                ; current line in decode buffer
                ; regs would be r0 = buffer00[ay_nline], r1 = buffer00[ay_nline + 256], etc
ay_nline        db 0
gigachad_nfrm   db 0

                ;
                ; AY-3-8910 register buffer
                ;
ayctrl          equ $15
aydata          equ $14
                
ay_outde
           	mov a, d
                out ayctrl
                mov a, e
                out aydata
                ret
                
ay_stfu         lxi d, $0700
                call ay_outde
                lxi d, $0800
                call ay_outde
                lxi d, $0900
                call ay_outde
                lxi d, $0a00
                jmp ay_outde

ay_noise	
                lxi d, $07c7 ; noise enable on channel A
                call ay_outde
                lxi d, $0803 ; volume pretty low on channel A
                call ay_outde
                lxi d, $0905 ; volume pretty low on channel B
                call ay_outde
                lxi d, $0a03 ; volume pretty low on channel C
                jmp ay_outde
		;ret

ay_noise_louder
                lxi d, $07c7 ; noise enable on channel A
                call ay_outde
                lxi d, $0806 ; volume pretty low on channel A
                call ay_outde
                lxi d, $090c ; volume pretty low on channel B
                call ay_outde
                lxi d, $0a06 ; volume pretty low on channel C
                jmp ay_outde
		;ret

                
                ; send from buffers to AY regs
                ; m = line number 
                ; reg13 (envelope shape) is special: $ff means no change / don't write
ay_send         
                mvi e, 13
                ;lxi b, ay_line+13
                mov c, m                
                mvi b, (buffer00 >> 8) + 13 ; last column
                
                ldax b
                cpi $ff
                jz ay_send_L2           ; no touchy fishy
ay_send_L1                
                mov a, e
                out ayctrl
                ldax b
                out aydata
ay_send_L2                
                dcr b                   ; prev column
                dcr e
                jp ay_send_L1
                ret
                
                
scheduler_init:
                lxi h, context
                shld context_ptr
                xra a
scheduler_init_L1:                
                sta scheduler_tick
                ret
scheduler_deinit:
                mvi a, $c9
                jmp scheduler_init_L1
                
                ;
                ; call all tasks in order
                ;
scheduler_tick: 
                ret
                lxi h, 0
                dad sp
                shld sched_sp
                lhld context_ptr
                mov e, m \ inx h \ mov d, m ; de = &context[n]
                xchg
                sphl
                
                ; restore task context and return into it
                pop h
                pop d
                pop b
                pop psw
                ret

sched_yield:
                lxi h, 0 
                dad sp
                xchg                    ; de = task context
                lhld context_ptr        ; hl = context[n]
                mov m, e \ inx h \ mov m, d \ inx h
                mvi a, context_end >> 8
                cmp h
                jnz sched_ret
                mvi a, context_end & 255
                cmp l
                jnz sched_ret
                lxi h, context
sched_ret
                shld context_ptr
sched_sp        equ $+1
                lxi sp, 0
                ret
                

                ; dzx0 task calls this to yield after producing each octet
dzx0_yield:     push psw
                push b
                push d
                push h
                jmp sched_yield

                ;
                ; create a dzx0 task
                ;
                ; a = task number (0..n_tasks-1)
                ; hl = task stack end
                ; bc = dst buffer
                ; de = stream source
dzx0_create:                   
                shld crea_loadsp
                lxi h, crea_b+1
                mov m, c \ inx h \ mov m, b \ inx h \ inx h
                mov m, e \ inx h \ mov m, d
                
                lxi h, 0
                dad sp
                shld dzx0_create_sp
                
                lxi d, context  ; context[0]
                mov l, a
                mvi h, 0
                dad h
                dad d           ; hl = &context[a]
                shld crea_ctx+1 ; will save task sp here
crea_loadsp     equ $+1
                lxi sp, 0
crea_b:         lxi b, 0
crea_d:         lxi d, 0

                ; create task entry point within its context
                lxi h, dzx0
                push h
                push psw
                push b
                push d
                push h
                lxi h, 0
                dad sp
crea_ctx:       shld 0                  ; save sp in task context
dzx0_create_sp  equ $+1
                lxi sp, 0
                ret                     ; this is a normal return

dzx0:
		lxi h,0FFFFh            ; tos=-1 offset?
		push h
		inx h
		mvi a,080h
dzx0_literals:  ; Literal (copy next N bytes from compressed file)
		call dzx0_elias         ; hl = read_interlaced_elias_gamma(FALSE)
;		call dzx0_ldir          ; for (i = 0; i < length; i++) write_byte(read_byte()
		push psw
dzx0_ldir1:
		ldax d
		stax b
		inx d
		inr c           ; stay within circular buffer

		; yield every 16 bytes
		mvi a, 15
		ana c
		cz dzx0_yield 
		;call dzx0_yield
		dcx h
		mov a,h
		ora l
		jnz dzx0_ldir1
		pop psw
		add a

		jc dzx0_new_offset      ; if (read_bit()) goto COPY_FROM_NEW_OFFSET
	
		; COPY_FROM_LAST_OFFSET
		call dzx0_elias         ; hl = read_interlaced_elias_gamma(FALSE) 
dzx0_copy:
		xchg                    ; hl = src, de = length
		xthl                    ; ex (sp), hl:
		                        ; tos = src
		                        ; hl = -1
		push h                  ; push -1
		dad b                   ; h = -1 + dst
		mov h, b                ; stay in the buffer!
		xchg                    ; de = dst + offset, hl = length
;		call dzx0_ldir          ; for (i = 0; i < length; i++) write_byte(dst[-offset+i]) 
		push psw
dzx0_ldir_from_buf:
		ldax d
		stax b
		inr e
		inr c                   ; stay within circular buffer
		
		; yield every 16 bytes
		mvi a, 15
		ana c
		cz dzx0_yield 
		dcx h
		mov a,h
		ora l
		jnz dzx0_ldir_from_buf
		mvi h,0
		pop psw
		add a
		                        ; de = de + length
		                        ; hl = 0
		                        ; a, carry = a + a 
		xchg                    ; de = 0, hl = de + length .. discard dst
		pop h                   ; hl = old offset
		xthl                    ; offset = hl, hl = src
		xchg                    ; de = src, hl = 0?
		jnc dzx0_literals       ; if (!read_bit()) goto COPY_LITERALS
		
		; COPY_FROM_NEW_OFFSET
		; Copy from new offset (repeat N bytes from new offset)
dzx0_new_offset:
		call dzx0_elias         ; hl = read_interlaced_elias_gamma()
		mov h,a                 ; h = a
		pop psw                 ; drop offset from stack
		xra a                   ; a = 0
		sub l                   ; l == 0?
		;rz                      ; return
		jz dzx0_ded
		push h                  ; offset = new offset
		; last_offset = last_offset*128-(read_byte()>>1);
		rar\ mov h,a            ; h = hi(last_offset*128)
		ldax d                  ; read_byte()
		rar\ mov l,a            ; l = read_byte()>>1
		inx d                   ; src++
		xthl                    ; offset = hl, hl = old offset
		
		mov a,h                 ; 
		lxi h,1                 ; 
		cnc dzx0_elias_backtrack; 
		inx h
		jmp dzx0_copy
dzx0_elias:
		inr l
dzx0_elias_loop:	
		add a
		jnz dzx0_elias_skip
		ldax d
		inx d
		ral
dzx0_elias_skip:
		rc
dzx0_elias_backtrack:
		dad h
		add a
		jnc dzx0_elias_loop
		jmp dzx0_elias
dzx0_ldir:
		push psw
		mov a, b
		cmp d
		jz dzx0_ldir_from_buf

                ; reached the end, just restart the scheduler
dzx0_ded       ; jmp brutal_restart
                call dzx0_yield
                jmp dzx0_ded


;
;
; SONG DATA
;
; see ym6break.py
;
; recipe: 
;   1. extract each register as separate stream
;   2. salvador -classic -w 256 register_stream
;   3. make db strings etc

; /3E/!EHA,q Da/!uHa___... . .NC/
; /Firestarter_HDS    25.12.2002/
; Created by Sergey Bulba's AY-3-8910/12 Emulator v2.9
songB_00: db $96,$ef,$9e,$df,$e8,$16,$ea,$c8,$fe,$85,$5a,$8e,$16,$9a,$77,$c8,$5f,$b0,$7d,$a8,$ff,$c8,$c0,$7d,$70,$bb,$0a,$fe,$91,$40,$7e,$48,$f3,$9f,$fe,$d7,$40,$df,$d0,$40,$c9,$80,$05,$55,$c0,$00,$20
songB_01: db $96,$00,$9f,$01,$e8,$0e,$fe,$05,$39,$40,$41,$55,$c0,$00,$20
songB_02: db $80,$be,$58,$3f,$ef,$c8,$9f,$77,$f8,$e8,$fe,$be,$05,$a1,$df,$68,$be,$05,$a1,$16,$68,$be,$56,$85,$20,$a1,$be,$57,$2b,$81,$96,$db,$f8,$be,$c0,$fe,$4c,$d5,$50,$cc,$80,$06,$bf,$9f,$f8,$e8,$fe,$be,$05,$a1,$df,$72,$b0,$05,$6e,$20,$fe,$4c,$c0,$80,$6b,$96,$db,$f8,$be,$c0,$fe,$4c,$d5,$50,$cc,$80,$06,$bf,$9f,$f8,$e8,$fe,$be,$05,$a1,$df,$72,$b0,$05,$6e,$20,$fe,$4c,$c0,$80,$6b,$96,$db,$f8,$be,$c0,$fe,$4c,$d5,$50,$cc,$80,$06,$bf,$9f,$f8,$e8,$fe,$be,$05,$a1,$df,$72,$b0,$05,$6e,$20,$fe,$4c,$c0,$80,$6b,$96,$db,$f8,$be,$85,$fe,$4c,$d5,$50,$70,$00,$08
songB_03: db $19,$03,$06,$08,$09,$03,$56,$85,$00,$e1,$a0,$7d,$78,$6e,$01,$fe,$4e,$40,$05,$b9,$02,$fe,$38,$a0,$e4,$fe,$4c,$85,$80,$5f,$48,$5c,$c5,$e0,$73,$50,$5c,$c4,$80,$5b,$01,$93,$fe,$d5,$40,$cd,$b0,$79,$a0,$5c,$c1,$80,$5f,$d0,$5c,$c5,$e0,$73,$50,$5c,$c4,$80,$5b,$01,$93,$fe,$d5,$40,$cd,$b0,$79,$a0,$5c,$c1,$80,$5f,$d0,$5c,$c5,$e0,$73,$50,$5c,$c4,$80,$5b,$01,$93,$fe,$d5,$40,$cd,$b0,$79,$a0,$5c,$c1,$80,$5f,$d0,$5c,$c5,$e0,$73,$50,$5e,$a2,$57,$00,$00,$80
songB_04: db $85,$ef,$69,$0a,$69,$df,$a1,$0a,$69,$ef,$02,$09,$d0,$b1,$92,$85,$68,$77,$57,$d5,$40,$ff,$10,$30,$56,$ee,$9f,$fe,$60,$5b,$df,$ca,$fe,$85,$15,$a1,$9f,$68,$85,$56,$81,$77,$5f,$28,$73,$f0,$73,$e8,$79,$08,$5b,$c8,$93,$fe,$25,$08,$f1,$54,$ff,$dc,$f4,$1f,$f0,$ee,$85,$0a,$fe,$f3,$79,$3c,$f7,$e8,$fd,$d8,$b8,$f7,$c0,$e6,$b5,$d8,$0c,$77,$58,$b1,$92,$88,$61,$42,$42,$22,$3b,$3b,$0f,$f5,$fc,$e4,$d8,$7d,$28,$e4,$40,$7f,$10,$97,$e8,$de,$28,$10,$58,$cf,$4f,$4f,$15,$40,$7f,$6c,$ff,$80,$7d,$f5,$fd,$0c,$40,$ff,$d8,$08,$7f,$a0,$e7,$9d,$f4,$fd,$b8,$e0,$7f,$b8,$df,$60,$f4,$7f,$e0,$85,$f4,$f7,$28,$fd,$ec,$50,$fe,$a0,$28,$5c,$96,$08,$7b,$64,$64,$c8,$fe,$9c,$f4,$df,$80,$d8,$f7,$20,$37,$38,$85,$f4,$cf,$18,$ff,$fd,$79,$18,$df,$e8,$dc,$e5,$a0,$60,$f2,$77,$58,$b1,$92,$99,$14,$72,$80,$57,$d5,$40,$f8,$cd,$10,$79,$30,$5c,$97,$38,$ff,$6c,$80,$f9,$7d,$f1,$0c,$e0,$f4,$7f,$a0,$e7,$9d,$f4,$95,$b8,$f7,$60,$d5,$f4,$f7,$28,$fd,$ec,$50,$fe,$c4,$08,$47,$aa,$ff,$64,$c8,$79,$f4,$c9,$78,$79,$20,$72,$30,$17,$fb,$d8,$61,$0a,$bf,$fe,$79,$18,$f7,$e8,$fd,$f0,$b8,$f7,$c0,$e6,$b5,$d8,$0c,$77,$58,$b1,$92,$d7,$60,$31,$38,$e5,$28,$e4,$40,$7f,$10,$97,$e8,$de,$28,$10,$5c,$fd,$10,$40,$ff,$6c,$80,$ff,$7d,$f5,$34,$f7,$40,$fd,$d8,$08,$ff,$a0,$9d,$9f,$f4,$b8,$f5,$e0,$ff,$b8,$60,$7d,$f4,$fe,$e0,$f4,$17,$df,$28,$ec,$f7,$50,$f9,$a0,$28,$72,$08,$59,$ee,$64,$64,$c8,$fe,$f4,$73,$80,$7f,$d8,$25,$80,$c0,$00,$20
songB_05: db $85,$00,$68,$01,$56,$80,$00,$57,$95,$48,$e5,$30,$5c,$85,$d0,$1f,$28,$55,$7d,$24,$79,$f0,$e5,$e8,$f5,$c0,$fe,$b4,$40,$10,$7e,$11,$5c,$47,$85,$38,$f5,$a0,$39,$fe,$04,$c9,$24,$5e,$28,$54,$7f,$f5,$10,$f7,$f4,$94,$40,$1c,$c5,$38,$73,$d4,$55,$e1,$28,$55,$f9,$f5,$e8,$7d,$c0,$7f,$b4,$81,$40,$1c,$c5,$38,$e1,$38,$7d,$a0,$4e,$fe,$44,$3e,$29,$4c,$15,$70,$00,$08
songB_06: db $61,$04,$02,$00,$1f,$d0,$13,$94,$fe,$39,$40,$41,$55,$c0,$00,$20
songB_07: db $85,$30,$a1,$32,$69,$30,$69,$20,$5a,$30,$5a,$22,$5f,$80,$79,$a0,$7d,$70,$7d,$98,$7d,$a0,$5e,$58,$15,$fc,$28,$c1,$80,$73,$e0,$57,$d7,$a8,$d5,$40,$f7,$70,$91,$a0,$0f,$fe,$4c,$c5,$88,$f7,$a0,$d7,$70,$d7,$98,$d5,$a0,$e1,$58,$5f,$28,$cc,$80,$17,$35,$e0,$7d,$a8,$7d,$40,$5f,$70,$79,$a0,$10,$f4,$fe,$cc,$88,$5f,$a0,$7d,$70,$7d,$98,$7d,$a0,$5e,$58,$15,$fc,$28,$c1,$80,$73,$e0,$57,$d7,$a8,$d5,$40,$f7,$70,$91,$a0,$0f,$fe,$4c,$c5,$88,$f7,$a0,$d7,$70,$d7,$98,$d5,$a0,$e1,$58,$5f,$28,$cc,$80,$17,$35,$e0,$7d,$a8,$7d,$40,$5f,$70,$7c,$a0,$17,$00,$00,$80
songB_08: db $6a,$0f,$0e,$0b,$0a,$aa,$09,$0c,$aa,$0b,$07,$aa,$06,$05,$af,$04,$e8,$e5,$d0,$0f,$88,$5e,$57,$7f,$0e,$0d,$0d,$5d,$70,$42,$e7,$0d,$88,$d5,$40,$72,$80,$41,$55,$70,$00,$08
songB_09: db $a6,$0f,$0d,$08,$00,$5a,$1f,$05,$a6,$00,$aa,$0c,$0b,$ab,$0a,$09,$fd,$b8,$a0,$e4,$93,$f7,$0a,$06,$04,$03,$02,$01,$d8,$df,$a0,$70,$5f,$40,$7d,$98,$7d,$a0,$5f,$b8,$17,$97,$28,$24,$80,$58,$32,$08,$08,$07,$07,$e0,$17,$35,$80,$ff,$c0,$48,$7d,$40,$5c,$d7,$50,$90,$a0,$5c,$df,$80,$a0,$78,$18,$5f,$a0,$7d,$70,$7d,$40,$f5,$10,$f5,$a0,$7c,$b8,$5f,$28,$72,$80,$55,$83,$08,$08,$07,$07,$21,$e0,$73,$80,$5f,$c0,$f7,$48,$d5,$40,$cd,$50,$79,$a0,$05,$cd,$80,$f7,$a0,$85,$18,$f7,$a0,$d7,$70,$df,$40,$10,$5f,$a0,$57,$c5,$b8,$f7,$28,$25,$80,$58,$32,$08,$08,$07,$07,$e0,$17,$35,$80,$ff,$c0,$48,$7d,$40,$5c,$d7,$50,$90,$a0,$5c,$df,$80,$a0,$78,$18,$5f,$a0,$7d,$70,$7d,$40,$f5,$10,$f5,$a0,$7c,$b8,$5f,$28,$72,$80,$55,$83,$08,$08,$07,$07,$21,$e0,$73,$80,$5f,$c0,$f7,$48,$d5,$40,$cd,$50,$79,$a0,$57,$00,$00,$80
songB_10: db $08,$0f,$0e,$0d,$0c,$43,$fd,$d0,$f0,$e5,$b8,$e5,$a0,$3c,$b8,$57,$fd,$40,$e8,$7d,$30,$5f,$a0,$5c,$81,$d0,$5f,$f8,$57,$95,$10,$f4,$08,$3d,$e8,$5e,$ea,$90,$e2,$0b,$0a,$09,$08,$07,$06,$05,$04,$03,$02,$01,$00,$fe,$ef,$09,$e0,$d0,$7f,$c0,$df,$b8,$d0,$e5,$e8,$ee,$96,$94,$ff,$93,$d0,$97,$70,$91,$b8,$7f,$40,$95,$e8,$f6,$38,$e4,$09,$20,$e5,$a0,$5f,$18,$5c,$d7,$90,$d6,$b8,$09,$02,$01,$00,$00,$0b,$01,$e0,$e1,$fe,$cd,$98,$5e,$10,$5c,$95,$20,$fe,$d0,$a0,$5b,$0f,$b8,$06,$fe,$5f,$d0,$f7,$f0,$97,$b8,$94,$a0,$f1,$b8,$5f,$40,$f5,$e8,$f5,$30,$7d,$a0,$72,$d0,$05,$7d,$f8,$5e,$10,$57,$d0,$08,$f5,$e8,$7a,$ea,$43,$0b,$0a,$09,$08,$07,$06,$05,$04,$03,$02,$01,$00,$8b,$fe,$09,$bd,$e0,$d0,$ff,$f0,$b8,$7f,$d0,$97,$e8,$bb,$96,$94,$fe,$93,$d0,$70,$5e,$b8,$45,$fe,$40,$e8,$57,$db,$38,$09,$93,$20,$95,$a0,$7d,$18,$73,$90,$5f,$b8,$58,$24,$02,$01,$00,$00,$2f,$01,$e1,$83,$fe,$35,$98,$79,$10,$72,$20,$57,$f9,$d0,$a0,$70,$00,$08
songB_11: db $85,$00,$a0,$3c,$15,$a0,$1e,$16,$85,$3c,$a1,$22,$5a,$3c,$16,$85,$32,$a1,$3c,$05,$73,$68,$0f,$fe,$11,$28,$1e,$05,$c9,$b0,$5c,$95,$98,$b9,$32,$fe,$28,$3c,$41,$5c,$c3,$68,$c4,$fe,$4a,$1e,$01,$72,$b0,$57,$25,$98,$6e,$32,$fe,$4a,$3c,$10,$57,$30,$68,$f1,$fe,$12,$80,$1e,$5c,$95,$b0,$c9,$98,$5b,$32,$92,$fe,$84,$3c,$05,$cd,$50,$79,$b8,$5c,$00,$02
songB_12: db $85,$00,$55,$57,$00,$00,$80
songB_13: db $85,$ff,$b9,$0a,$e8,$2b,$08,$90,$fe,$7d,$a0,$68,$0a,$05,$6c,$08,$95,$c8,$33,$80,$55,$f5,$a0,$68,$0a,$05,$5a,$ff,$15,$a5,$0a,$57,$d5,$58,$b2,$08,$80,$45,$3d,$a0,$5a,$0a,$01,$56,$85,$ff,$69,$0a,$55,$f5,$58,$6c,$08,$91,$80,$4f,$a0,$56,$80,$0a,$55,$a1,$ff,$5a,$0a,$55,$7d,$58,$5b,$08,$24,$80,$53,$d5,$a0,$a1,$0a,$05,$c0,$00,$20

; I CAN (SUX MIX)
; 2006.04.22 Firestarter_HDS
; Created by Sergey Bulba's AY-3-8910/12 Emulator v2.9
songA_00: db $84,$00,$55,$5a,$44,$11,$55,$c0,$00,$20
songA_01: db $84,$00,$55,$5a,$03,$11,$55,$c0,$00,$20
songA_02: db $96,$44,$85,$d5,$68,$60,$5a,$44,$69,$07,$68,$f9,$16,$85,$39,$a5,$44,$a0,$60,$5a,$39,$57,$31,$f8,$6f,$a2,$fe,$4c,$c0,$a0,$17,$9b,$2c,$84,$8c,$20,$d5,$a0,$e5,$a8,$cd,$a0,$5f,$50,$72,$a0,$05,$f7,$50,$20,$a0,$15,$5c,$00,$02
songA_03: db $19,$03,$06,$08,$09,$03,$a0,$01,$17,$fd,$a8,$b0,$b8,$00,$fe,$4e,$a8,$5f,$50,$57,$c5,$a8,$73,$a0,$00,$5b,$03,$9a,$ff,$04,$05,$06,$83,$03,$35,$a0,$79,$a8,$78,$50,$57,$24,$f8,$5c,$80,$a0,$55,$70,$00,$08
songA_04: db $85,$00,$a5,$3b,$a1,$44,$89,$84,$44,$0a,$fc,$16,$9a,$44,$c5,$45,$f5,$80,$bd,$fc,$fe,$3d,$40,$e1,$fe,$7d,$00,$6f,$10,$fe,$13,$25,$a0,$00,$f1,$fe,$29,$fc,$5a,$c5,$11,$68,$fc,$45,$f5,$10,$c8,$a0,$05,$57,$00,$00,$80
songA_05: db $85,$00,$a5,$08,$a2,$03,$6a,$04,$05,$06,$03,$42,$85,$0a,$fb,$c0,$07,$c4,$fe,$f5,$80,$bd,$0a,$fe,$3d,$40,$e1,$fe,$7d,$00,$6f,$0d,$fe,$13,$25,$a0,$00,$f1,$fe,$29,$0a,$5a,$07,$11,$68,$0a,$45,$f5,$10,$c8,$a0,$05,$57,$00,$00,$80
songA_06: db $80,$00,$05,$57,$00,$00,$80
songA_07: db $96,$10,$9a,$12,$32,$69,$12,$a8,$36,$e2,$00,$20,$ef,$00,$04,$ef,$f9,$00,$d0,$f7,$c8,$df,$b0,$c1,$f7,$ab,$a8,$fe,$91,$b4,$b0,$1f,$c0,$6e,$30,$4f,$e8,$14,$fe,$97,$30,$32,$d3,$c0,$ee,$2e,$16,$fe,$e3,$78,$35,$f8,$e5,$c0,$f5,$88,$cc,$a0,$01,$7a,$d5,$00,$32,$f7,$eb,$02,$fe,$10,$21,$a0,$7d,$a8,$5f,$50,$57,$fc,$00,$a8,$1f,$fe,$62,$20,$30,$ab,$20,$22,$25,$a0,$55,$bc,$19,$fe,$a6,$1b,$9a,$3b,$1b,$18,$aa,$09,$19,$09,$9e,$0b,$d0,$3d,$c8,$f7,$b0,$d5,$a8,$ff,$78,$50,$17,$fc,$b0,$a8,$1f,$fe,$62,$29,$39,$ab,$29,$2b,$f9,$30,$50,$72,$a0,$45,$5c,$00,$02
songA_08: db $39,$00,$00,$fc,$15,$56,$2a,$10,$1e,$1d,$aa,$1c,$1b,$aa,$1a,$19,$aa,$18,$17,$aa,$16,$15,$aa,$14,$13,$aa,$12,$11,$e1,$fe,$00,$c9,$a0,$15,$70,$00,$08
songA_09: db $a6,$0f,$0e,$0c,$00,$f8,$fc,$aa,$10,$1e,$1d,$aa,$1c,$1b,$ae,$1a,$19,$e4,$ba,$18,$dc,$f1,$17,$d0,$ff,$a8,$b0,$6e,$1f,$fe,$4f,$84,$fe,$f0,$a8,$5e,$50,$47,$e3,$55,$59,$10,$16,$d7,$d8,$91,$a8,$73,$a0,$00,$5f,$e9,$a8,$d5,$0d,$72,$0b,$0a,$0a,$09,$08,$a0,$00,$e5,$a8,$7c,$50,$5c,$91,$f8,$72,$a0,$01,$55,$c0,$00,$20
songA_10: db $85,$00,$a7,$0c,$99,$ec,$a3,$0f,$0f,$0d,$0b,$0a,$85,$c8,$f7,$c0,$df,$e0,$f8,$5e,$80,$59,$e0,$0a,$09,$08,$88,$f1,$c0,$7d,$30,$79,$80,$7d,$30,$73,$a0,$00,$5f,$c8,$57,$d5,$a8,$ff,$50,$a8,$40,$f4,$fe,$c8,$a0,$05,$57,$00,$00,$80
songA_11: db $96,$00,$61,$3f,$3d,$3b,$19,$91,$30,$2e,$2c,$98,$25,$23,$21,$68,$1f,$16,$60,$2b,$29,$27,$1f,$80,$f5,$fc,$ee,$b0,$fe,$43,$21,$f8,$67,$38,$36,$34,$90,$fe,$c8,$a0,$00,$57,$dc,$b8,$91,$a0,$15,$c0,$00,$20
songA_12: db $80,$00,$05,$57,$00,$00,$80
songA_13: db $96,$ff,$25,$0a,$ff,$39,$d0,$5a,$0a,$10,$f4,$d8,$4f,$a8,$55,$cd,$a0,$55,$5a,$0a,$11,$55,$c0,$00,$20



;
; runtime data (careful with relative equ directives)
;

; task stacks

stacks          
stack_00        equ stacks
stack_01        equ stack_00 + task_stack_size
stack_02        equ stack_01 + task_stack_size
stack_03        equ stack_02 + task_stack_size
stack_04        equ stack_03 + task_stack_size
stack_05        equ stack_04 + task_stack_size
stack_06        equ stack_05 + task_stack_size
stack_07        equ stack_06 + task_stack_size
stack_08        equ stack_07 + task_stack_size
stack_09        equ stack_08 + task_stack_size
stack_10        equ stack_09 + task_stack_size
stack_11        equ stack_10 + task_stack_size
stack_12        equ stack_11 + task_stack_size
stack_13        equ stack_12 + task_stack_size
stack_14        equ stack_13 + task_stack_size
stack_15        equ stack_14 + task_stack_size
stacks_end      equ stack_15 + task_stack_size

; array of task sp: context[i] = task's stack pointer
context         equ stacks_end
context_end     equ context + 2 * n_tasks

context_ptr:    equ context_end
bss_end         equ context_ptr + 2


; buffers for unpacking the streams, must be aligned to 256 byte boundary

buffer00        equ     0xff00 & bss_end + 256        
buffer01        equ     0xff00 & bss_end + 256 * 2        
buffer02        equ     0xff00 & bss_end + 256 * 3
buffer03        equ     0xff00 & bss_end + 256 * 4        
buffer04        equ     0xff00 & bss_end + 256 * 5
buffer05        equ     0xff00 & bss_end + 256 * 6        
buffer06        equ     0xff00 & bss_end + 256 * 7
buffer07        equ     0xff00 & bss_end + 256 * 8        
buffer08        equ     0xff00 & bss_end + 256 * 9
buffer09        equ     0xff00 & bss_end + 256 * 10        
buffer10        equ     0xff00 & bss_end + 256 * 11
buffer11        equ     0xff00 & bss_end + 256 * 12       
buffer12        equ     0xff00 & bss_end + 256 * 13
buffer13        equ     0xff00 & bss_end + 256 * 14       

	.end


