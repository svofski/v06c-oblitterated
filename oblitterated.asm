                ; OBLITTERATED
                ; an unlikely max headroom incident
                ;
                ; Vector-06c demo
                ; svo 2022 for cafeparty

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

                ; нормальное сообщение
MSG_TIME        equ 100
                ; первертствие
GREET_TIME      equ 40



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
                
                ;;;;;;;
                ;mvi a, 15
                ;out 2

modesw2:        ; переход на главную процедуру секвенции        
                call 0
                

                ; музон
                call gigachad_frame
                        

                ;mvi a, 0
                ;out 2
                ;;;;;;

                jmp foreva_lup
                

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
                dw phaseA_setup, phaseA_main    ; logo display
                dw Restart, Restart

                
                dw 0, 0

                ; сообщения двойной ширины (128, 16 стобцов)
msgptr          dw msg_sequence                
msg_sequence    dw msg_hello1, msg_hello2, msg_hello1, msg_hello2
                dw msg_what_a_strange_place, msg_what_a_strange_place
                dw msg_i_have_to_blit_myself, msg_i_have_to_blit_myself
                dw msg_as_fast_as_i_can, msg_as_fast_as_i_can
                dw msg_just_to_stay_where_i_am
                dw msg_just_to_stay_where_i_am
                dw msg_null
                dw msg_null
                dw msg_i_am_fully
                dw msg_i_am_fully
                dw msg_oblitterated, msg_oblitterated
                dw msg_oblitterated, msg_oblitterated
                dw msg_oblitterated, msg_oblitterated
                dw 0, 0

greetz_sequence 
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_errorsoft ;, msg_gr_errorsoft
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_frog      ;, msg_gr_frog
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_ivagor    ;, msg_gr_ivagor
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_kansoft   ;, msg_gr_kansoft
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_lafromm   ;, msg_gr_lafromm
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_manwe        ;, msg_gr_zx
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_metamorpho;, msg_gr_metamorpho
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_nzeemin   ;, msg_gr_nzeemin
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_tnt23     ;, msg_gr_tnt23
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_else      ;, msg_gr_else
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_gr_orgaz     ;, msg_gr_orgaz
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_null, msg_null, ;msg_null, msg_null
                dw msg_null, msg_null, ;msg_null, msg_null
                dw 0, 0

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
var_ctr16       dw 0
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
                call wipe

                lhld wipe_xy
                inr l
                shld wipe_xy
                call wipe
                
                jmp sequence_next
phase1_L1
                ;
                sta varblit_clip_h
                ;

                sta wipe_height
                sta blit_height
                mvi a, 128/8/8  ;= 2
                sta wipe_width
                
                call wipe

                lxi d, varmax_top_a
                lxi h, varmax_top_b
                lda wipe_xy
                mov c, a
                jmp varblit
                
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
                lxi h, $e0f0 ; a bogus last message position so that it's wiped safely
                shld blit_banner_p3+1

                mvi a, MSG_TIME
                sta msg_seq_time
                call msg_sequence_next
                jmp gigachad_enable
                ;ret

                ; основная фаза: рисуем все
phase5_main:
                ; для ускорения рисуем черепушку отдельно, она уже плечей
                call blit_full_head     

                call msg_sequence_frame
                jz p5_L1  ; новое сообщение -> пропускаем рисование, а то кадр
blit_banner:
blit_banner_p1: lxi h, msg_tape_error1
                shld blit_src1+1
blit_banner_p2: lxi h, msg_tape_error2
                shld blit_src2+1
blit_banner_p3: lxi h, $16f0+0e000h     ; -- top / right corner

                ; all messages are 2x wide
                shld blit_xy
                mvi a, 18/2             ; text tag height
                sta blit_height
                lxi h, blit_line_c1 + (4 - 2) * blit_linej_sz
                shld blit_widthj
                call blit
p5_L1:
                lda mainseq_active
                ora a
                cz sequence_next
                ret

blit_full_head
blit_head:
                mvi c, LOGOXY & 255
                lxi d, varmax_top_a
                lxi h, varmax_top_b
                call varblit              ; return @ line 201

                ; и плечи пошире
blit_torso:
                mvi c, $47  
                lxi d, varmax_bottom_a
                lxi h, varmax_bottom_b
                jmp varblit

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
                
                jmp wipe_banner2
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
                ; остаток точно совпадает с phase1_L1
                jmp phase1_L1
;                sta wipe_height
;                sta blit_height
;                mvi a, 128/8/8 ; 2
;                sta wipe_width
;
;                lxi h, blit_line_c1 + (4 - 2) * blit_linej_sz
;                shld blit_widthj
;
;                lxi h, hello_jpg
;                shld blit_src1+1
;                lxi h, hello_jpg2
;                shld blit_src2+1
;                call wipe ; можно вообще не вызывать, но тогда грязновато
;                jmp blit
;                ;ret

                
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

                ; инициализация гритзов
                lxi h, $e0f0 ; a bogus last message position so that it's wiped safely
                shld blit_banner_p3+1
                lxi h, greetz_sequence ; 29a
                shld msgptr
                mvi a, GREET_TIME
                sta msg_seq_time
                mvi a, 1
                sta mainseq_active
                call msg_sequence_next
                ret

phase7_main:
titleout_xy     equ $0020+0e000h
title_xy_1      equ titleout_xy + 12*256 + 14 * 8        ; oblitterated
title_xy_2      equ titleout_xy + 8 * 256 + 10 * 8       ; an unlikely max headroom incident
title_xy_3      equ titleout_xy + 12 * 256 + 3 * 8      ; svo 2022
title_xy_4      equ titleout_xy + 8 * 256               ; music by firestarter
text_height     equ 18/2
text_width      equ 1
text_dwidth     equ 2

                mvi a, text_height
                sta blit_height
                ;mvi a, text_width

                ; greetz
                call msg_sequence_frame

                ; 8-column messages
                lxi h, blit_line_c1 + (4 - text_width) * blit_linej_sz
                shld blit_widthj

                lxi h, msg_no_longer_inv1
                shld blit_src1+1
                lxi h, msg_no_longer_inv2
                shld blit_src2+1
                lxi h, title_xy_1 + 2 * 8
                shld blit_xy
                call blit

                
                lxi h, msg_svo2022
                shld blit_src1+1
                shld blit_src2+1
                lxi h, title_xy_3
                shld blit_xy
                call blit
                
                ; double-width texts
                lxi h, blit_line_c1 + (4 - text_dwidth) * blit_linej_sz
                shld blit_widthj
                lxi h, msg_an_unlikely_max_headroom_incident
                shld blit_src1+1
                shld blit_src2+1
                lxi h, title_xy_2
                shld blit_xy
                call blit

                lxi h, msg_music_by_firestarter_a
                shld blit_src1+1
                lxi h, msg_music_by_firestarter_b
                shld blit_src2+1
                lxi h, title_xy_4
                shld blit_xy
                call blit

                lxi h, msg_oblitterated
                shld blit_src1+1
                shld blit_src2+1
                lxi h, title_xy_1
                shld blit_xy
                call blit

                ; blit greetz
                lhld blit_banner_p1+1
                shld blit_src1+1
                lhld blit_banner_p2+1
                shld blit_src2+1
                lhld blit_banner_p3+1
                shld blit_xy
                call blit


                ; cafeparty logo
                mvi a, 0            ; disable interlace
                sta varblit_ilace
                lxi h, adj_for_scroll_exact
                shld varblit_adj_vec 

                mvi c, $5c
                lxi d, cafe_bw
                lxi h, cafe_bw
                call varblit

                lxi h, adj_for_scroll
                shld varblit_adj_vec

                ; эта фаза завершается когда заканчиваются тексты
                ;lxi h, phase0_ctr
                ;dcr m
                ;rnz
                lda mainseq_active
                ora a
                rnz
                
                jmp sequence_next
                
phase8_setup:   ret
phase8_main:    jmp phase7_main

phase9_setup:
                ; wipe
                lxi h, titleout_xy + 8*256 + 16*8
                shld wipe_xy
                mvi a, text_height * 9
                sta wipe_height
                mvi a, 2
                sta wipe_width
                call wipe

                lxi h, titleout_xy + 8*256 + 16*8 + 1
                shld wipe_xy
                ;mvi a, $55
                ;sta wipe_bitmap
                jmp wipe
                ;ret
phase9_main:
                jmp sequence_next



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PHASE A: final logo display
;; hold for 1 minute = 3000 frames
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

endlogo_y       equ $90
              
phaseA_setup:   
                call gigachad_disable
                call ay_stfu
                lxi h, 3000
                shld var_ctr16
                jmp Cls
phaseA_main:
                ; hijack the main loop because it's the end anyway
                ei
                hlt

                lxi h, colors_logo+15
                call colorset
                lda frame_scroll
                out 3

                lxi h, adj_for_scroll_exact
                shld varblit_adj_vec 

                ; cafeparty logo
                mvi a, 0
                sta varblit_ilace   ; disable interlace
                mvi a, $c0
                sta varblit_plane   ; set plane = $c0
                mvi c, endlogo_y
                lxi d, cafe_c0
                lxi h, cafe_c0
                call varblit

                mvi a, 0            ; disable interlace
                sta varblit_ilace
                mvi a, $e0        
                sta varblit_plane   ; set plane = $e0

                mvi c, endlogo_y
                lxi d, cafe_e0
                lxi h, cafe_e0
                call varblit

                lxi h, adj_for_scroll
                shld varblit_adj_vec
  
                lhld var_ctr16
                lxi b, -1
                dad b
                mov a, h
                ora l
                jz sequence_next
                shld var_ctr16
                jmp phaseA_main

wipe_banner2ex: lhld blit_banner_p3+1
                call adj_for_scroll
                mvi d, 18
                mov b, h
                xra a
wb2ex_L1:       mov m, a \ inr h \ mov m, a \ inr h
                mov m, a \ inr h \ mov m, a \ inr h
                mov m, a \ inr h \ mov m, a \ inr h
                mov m, a \ inr h \ mov m, a \ inr h
                mov m, a \ inr h \ mov m, a \ inr h
                mov m, a \ inr h \ mov m, a \ inr h
                mov m, a \ inr h \ mov m, a \ inr h
                mov m, a \ inr h \ mov m, a; \ inr h
                dcr d
                rz
                dcr l
                mov h, b
                jmp wb2ex_L1

wipe_banner2ez: 
                lxi h, 0
                dad sp
                shld wb2ez_sp + 1
                lhld blit_banner_p3+1
                call adj_for_scroll
                mvi d, 16 ; columns
                lxi b, 0
                inr l 
wb2ez_L1:       sphl
                push b
                push b
                push b
                push b
                push b
                push b
                push b
                push b
                push b
                inr h
                dcr d
                jnz wb2ez_L1
                
wb2ez_sp:       lxi sp, 0
                ret

                ; wipe the (double) banner message in its jumpy position
wipe_banner2:
                mvi a, 9 \ sta wipe_height
                mvi a, 2 \ sta wipe_width
                lhld blit_banner_p3+1
                mvi a, -8 \ add h \ mov h, a
                push h
                shld wipe_xy
                call wipe
                pop h
                inr l
                shld wipe_xy
                jmp wipe
                ; ret

                ; Z = new message
                ; NZ = not yet
msg_sequence_frame:
                lxi h, msg_timer
                dcr m
                rnz
msg_sequence_next
msg_seq_time    equ $+1
                mvi a, MSG_TIME
                sta msg_timer
                
                ; стереть полностью текущее сообщение
                ;call wipe_banner2ex  ; 5392
                call wipe_banner2ez  ; 3104
                ; установить новое место для сообщения
                lda rnd16+1
                ani $f \ adi $e0      ; x - столбец
                sta blit_banner_p3+2
                lda rnd16+2
                ani $1f \ adi $d0+2
                sta blit_banner_p3+1
                
                ; загрузить указатели на следующее сообщение
                lhld msgptr
mseq_next_L1:
                mov e, m
                inx h
                mov d, m
                inx h
                mov a, d
                ora e
                jnz mseq_next_L2
                sta mainseq_active    ; признак конца секвенции
                lxi h, msg_sequence
                jmp mseq_next_L1
mseq_next_L2:                
                xchg \ shld blit_banner_p1+1 \ xchg
mseq_next_L4:   ; следующий указатель из последовательности
                mov e, m
                inx h
                mov d, m
                dcx h
                ;
                mov a, d
                ora e
                jnz mseq_next_L3
                sta mainseq_active
                lxi h, msg_sequence
                jmp mseq_next_L4
mseq_next_L3
                xchg \ shld blit_banner_p2+1 \ xchg
                shld msgptr                
                xra a ; set zero flag 
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
                lxi h, 0
                dad sp
                shld cls_sp+1
                lxi sp, 0
                lxi d, 0
                ; 256/32 * 32 -> 256 times for one bitplane
                lxi b, $400
cls_L1:           
                push d \ push d \ push d \ push d
                push d \ push d \ push d \ push d
                push d \ push d \ push d \ push d
                push d \ push d \ push d \ push d
                dcr c
                jnz cls_L1
                dcr b
                jnz cls_L1
cls_sp:         lxi sp, 0
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

                ;      0 0: black   0, 4, 8, 12
                ;      0 1: white   1, 5, 9, 13
                ;      1 0: yellow  2, 6, 10, 14
                ;      1 1: blue    3, 7, 11, 15

col_black       equ 000q
col_white       equ 377q
col_yellow      equ 067q
col_blue        equ 221q

colors_logo     .db col_black, col_white, col_yellow, col_blue
                .db col_black, col_white, col_yellow, col_blue
                .db col_black, col_white, col_yellow, col_blue
                .db col_black, col_white, col_yellow, col_blue

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



                ; di
                ; mvi c, $d0      ; y
                ; lxi d, frame_A
                ; lxi h, frame_B
                ; call varblit
varblit:
                ; select glitchy frame
                call sel_glitchy ; chosen frame in d
                mov l, c
varblit_adj_vec equ $+1
                call adj_for_scroll
                mov c, l

                lxi h, 0
                dad sp
                shld varblit_sp
                xchg
                sphl

                mov l, c

varblit_clip_h  equ $+1
                mvi d, 0
vb_L0:
                pop b   ; e = first column, d = number of 2-column chunks (0-16)
                mov a, b
                ora c
                jz vb_exit

varblit_plane   equ $+1
                mvi a, $e0 ; plane msb
                add c
                mov h, a        ; hl = screen addr

                mov a, b  ; d = precalculated offset into vbline_16
                sta vb_M1+1 
vb_M1:          jmp vbline_16
vb_L1:
                .org 0x100 + . & 0xff00
vbline_16:      pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b \ inr h
                pop b \ mov m, c \ inr h \ mov m, b; \ inr h

vb_L2:          ; next line (interlaced)
varblit_ilace:  dcr l 
                dcr l
                dcr d
                jnz vb_L0
                ;jmp vb_L0
                
vb_exit:
                ; restore clip_h because it's so easy to forget
                xra
                sta varblit_clip_h
                mvi a, $2d ; dcr l
                sta varblit_ilace
varblit_sp      equ $+1
                lxi sp, 0
                ret

                ; hl = frame A
                ; de = frame B
                ; result is swapped sometimes
sel_glitchy:    lda rnd16+2
                mov b, a
                lda framecnt
                rar \ rar
                ana b
                rar
                rnc
                xchg
                ret

                ; l = y coordinate
                ; result = l adjusted for scroll offset
                ; CLOBBERS: a
adj_for_scroll  
                ; adjust for scroll direction
                lda fasign 
                rar
                lda frame_scroll
                sbi 0
                add l
                mov l, a
                ret

                ; works for the logo (non-interlace)
                ; bad for the main part
adj_for_scroll_exact:
                ; adjust for scroll direction
                lda fasign 
                rar
                push psw
                lda frame_scroll
                sbi 0
                add l
                mov l, a
                pop psw
                rnc
                inr l
                ret

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
blit_src1:	lxi sp, 0
                lda rnd16+2     ; выбираем когда показывать глючный кадр
                mov b, a
                lda framecnt
                rar \ rar
                ana b
                rar
                jnc $+6
blit_src2:      lxi sp, 0
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
                ; ПАРАМЕТР: blit_widthj = blit_line1 * (4 - width8) * blit_linej_sz
blit_linej_sz   equ blit_line_c2 - blit_line_c1
blit_widthj     equ $+1                
blit_linej:     jmp blit_line_c1 ; этот жумп меняем для установки ширины
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

wipe_bitmap     equ $+1
                mvi d, 0
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

; varmax_top_1
varmax_top_a:
.include varmax_top_a.inc
varmax_top_b:
.include varmax_top_b.inc
varmax_bottom_a:
.include varmax_bottom_a.inc
varmax_bottom_b:
.include varmax_bottom_b.inc

; all text messages
.include messages.inc

; cafeparty logo bitmaps
.include cafe.inc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;         GIGACHAD - 16       ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



; total number of scheduler tasks                
n_tasks         equ 14

; task stack size 
task_stack_size equ 22

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

; songA_00
.include firestarter_3elehaq.inc

; I CAN (SUX MIX)
; 2006.04.22 Firestarter_HDS
; Created by Sergey Bulba's AY-3-8910/12 Emulator v2.9
.include firestarter_2006_027.inc


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


