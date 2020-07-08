
    processor 6502
    include "vcs.h"
    include "macro.h"

UPPER_PLAYFIELD_HEIGHT      = 8
LOWER_PLAYFIELD_HEIGHT      = 8
PLAYAREA_HEIGHT             = 192 - UPPER_PLAYFIELD_HEIGHT - LOWER_PLAYFIELD_HEIGHT
INITIAL_TREE_POSITION       = 192 - 8
TREE_DELAY                  = 1
UPPER_PLAYFIELD_LIMIT       = UPPER_PLAYFIELD_HEIGHT
PLAYAREA_LIMIT              = UPPER_PLAYFIELD_LIMIT + PLAYAREA_HEIGHT
LOWER_PLAYFIELD_LIMIT       = PLAYAREA_LIMIT + LOWER_PLAYFIELD_HEIGHT
FLAP_X                      = 40
BACKGROUND_COLOR            = $9e
TREE_COLOR                  = $14
BORDER_COLOR                = $9e
    SEG.U vars
    ORG $80

FLAP_Y              ds 1
TREE_X              ds 1
WALL_DEC_COUNT      ds 1
TREE_SHAPE          ds 1
HOLE_START          ds 1
HOLE_END            ds 1
FLAP_FRAME_COUNTER  ds 1
FLAP_CURRENT_FRAME  ds 2
RND                 ds 1
HOLE_SIZE           ds 1

    SEG
    ORG $F000

Reset
    CLEAN_START

    ; Once-only initialization...
    lda #BACKGROUND_COLOR
    sta COLUBK             ; set the background color

    lda #$14
    sta COLUP0              ; tree color

    lda #120
    sta FLAP_Y              ; set flappy initial y position

    lda #$1e
    sta COLUP1              ; flappy color

    lda #INITIAL_TREE_POSITION 
    sta TREE_X              ; set tree initial x position

    lda #TREE_DELAY
    sta WALL_DEC_COUNT

    lda #%11101111
    sta TREE_SHAPE

    lda #%00000101
    sta CTRLPF

    lda #192 - 8 - 8 - 10
    sta HOLE_START

    lda #10
    sta HOLE_END

    lda #64
    sta FLAP_FRAME_COUNTER

    lda #<FlapFrame1
    sta FLAP_CURRENT_FRAME
    lda #>FlapFrame1
    sta FLAP_CURRENT_FRAME + 1

    lda #17 ; rnd seed
    sta RND

    lda #50
    sta HOLE_SIZE ; default hole size

MainLoop
    VERTICAL_SYNC
	lda #43
	sta TIM64T ; we set this timer to around the time it takes to complete the vblank

    ; very bad collision check
    lda TREE_X
    clc
    sbc #8
    cmp #FLAP_X
    bcs NoCollisionWithTree

    clc
    adc #8
    cmp #FLAP_X
    bcs NoCollisionWithTree

    lda FLAP_Y
    clc
    sbc #2 ; allow one pixel cleareance
    clc
    cmp HOLE_START
    bcc NoTopCollision
    jmp Collision

NoTopCollision
    lda FLAP_Y
    clc
    sbc #8
    clc
    cmp HOLE_END
    bcs NoDownCollision
    jmp Collision

NoCollisionWithTree
NoDownCollision
    lda FLAP_Y
    clc
    cmp 192 - #UPPER_PLAYFIELD_HEIGHT - #LOWER_PLAYFIELD_HEIGHT
    bcc NoCeilingCollision
    jmp Collision

NoCeilingCollision
    lda FLAP_Y
    clc
    cmp #8
    bcs NoCollision
    jmp Collision

Collision
    lda #$48 ; change to RED
    sta COLUBK
    jmp Reset

NoCollision

    lda TREE_X
    ldx #0
    jsr WaitForSprite

    lda #FLAP_X ; constant
    ldx #1
    jsr WaitForSprite

; is controller Down?
	lda #%00010000
	bit SWCHA
	bne DoneMoveUp

    REPEAT 1 ; control speed
        inc FLAP_Y ; y is backward
        inc FLAP_Y ; y is backward
        inc FLAP_Y ; y is backward
    REPEND
DoneMoveUp

;   update RND
    lda RND
    asl
    asl
    clc
    adc RND
    clc
    adc #17        ; RND * 5 + 17
    sta RND

; check flap frame
; we increment on every frame and if the mask give 0 = frame0, 1 = frame1
    lda FLAP_FRAME_COUNTER
    clc
    cmp #32
    bcs SetFlapFrame1

    lda #<FlapFrame0
    sta FLAP_CURRENT_FRAME
    lda #>FlapFrame0
    sta FLAP_CURRENT_FRAME + 1

    lda FLAP_FRAME_COUNTER
    bne DoneFlapFrame
    ; reset FLAP_FRAME_COUNTER
    lda #64
    sta FLAP_FRAME_COUNTER

    jmp DoneFlapFrame

SetFlapFrame1
    lda #<FlapFrame1
    sta FLAP_CURRENT_FRAME
    lda #>FlapFrame1
    sta FLAP_CURRENT_FRAME + 1

DoneFlapFrame
    dec FLAP_FRAME_COUNTER

    ; lda FLAP_FRAME_COUNTER
    ; and #%00000001
    ; bne SkipDropAltitude
    dec FLAP_Y
SkipDropAltitude

; check if we need to move the tree
    ldy WALL_DEC_COUNT
    dey
    sty WALL_DEC_COUNT
    bne SkipTreeMove
    
    lda #TREE_DELAY
    sta WALL_DEC_COUNT ; reset tree wall move counter

; move the tree
    lda TREE_X
    sec
    sbc #1 ; change to adjust the speed, beware of underflow!
    sta TREE_X
    ; clc
    cmp #24 ; weird stuff here
    bne SkipTreeReset

    ; Reset tree to position
    lda TREE_SHAPE
    asl
    adc #0
    sta TREE_SHAPE

    lda #INITIAL_TREE_POSITION 
    sta TREE_X

    lda RND
    and #%00111110 ; get a value from 64 to 0
    adc #30
    sta HOLE_END

    clc
    adc HOLE_SIZE
    sta HOLE_START

    ; ADD SPEED
    lda HOLE_SIZE
    clc
    sbc #1
    sta HOLE_SIZE ; weirdly dec seem to produce weird results :/

SkipTreeReset
SkipTreeMove

    ; draw upper playfield boundary
    lda #%11111111
    sta PF0
    sta PF1
    sta PF2

    lda #$0e
    sta COLUPF             ; set the cloud playfield color

WaitForVblankEnd
	lda INTIM
	bne WaitForVblankEnd

	sta WSYNC
    sta HMOVE
    sta VBLANK

; BEGIN
    ldx #UPPER_PLAYFIELD_HEIGHT
DrawUpperPlayfield
    dex
    sta WSYNC
    bne DrawUpperPlayfield
; END

    lda #0
    sta PF2 ;  disable middle part of playfield

    ; lda #$1e
    lda #BORDER_COLOR
    sta COLUPF             ; set the border playfield color

    lda TREE_SHAPE
    sta GRP0 ; apply the sprite shape

; BEGIN
    ldx #PLAYAREA_HEIGHT ; reinint counter, save a line at the bottom to handle playfield transition
Picture
    lda #%11110000
    sta PF0
    lda #%11100000
    sta PF1

    ; handle the HOLE
    cpx HOLE_START    ; 2
    bne SkipHoleStart ; 2
    lda #0            ; 2
    sta GRP0          ; 4
    jmp SkipHoleEnd   ; 3

SkipHoleStart
    cpx HOLE_END     ; 2
    bne SkipHoleEnd  ; 2
    lda TREE_SHAPE   ; 3
    sta GRP0         ; 3

SkipHoleEnd
    lda #%00110000
    sta PF0
    lda #%00000000
    sta PF1

    sta WSYNC
    dex

    lda #%11110000
    sta PF0
    lda #%11100000
    sta PF1

    txa
    sec
    sbc FLAP_Y
    adc #8 ; sprite height
    bcc SkipFlap

    tay
    lda (FLAP_CURRENT_FRAME),y
    sta GRP1
    jmp SkipHideFlap


SkipFlap
    lda #0
    sta GRP1

SkipHideFlap
    lda #%00110000
    sta PF0
    lda #%00000000
    sta PF1

    sta WSYNC
    dex

    bne Picture
; END

;BEGIN
    ; disable tree sprite
    lda #$00
    sta GRP0

    lda #$c8
    sta COLUPF             ; set the ground playfield color

    ; draw lower playfield boundary
    lda #%11111111
    sta PF0
    sta PF1
    sta PF2

    ldx #LOWER_PLAYFIELD_HEIGHT + 29 ; reinint counter
DrawLowerPlayfield
    sta WSYNC
    dex
    bne DrawLowerPlayfield
; END

    ; Game logic comes here

    lda #%01000010
    sta VBLANK          ; end of screen - enter blanking

    jmp MainLoop

WaitForSprite
    sta WSYNC
    sec                      ; 02     Set the carry flag so no borrow will be applied during the division.
Divideby15
    sbc #15                  ; 04     Waste the necessary amount of time dividing X-pos by 15!
    bcs Divideby15           ; 06/07  11/16/21/26/31/36/41/46/51/56/61/66
    tay
    lda fineAdjustTable,y    ; 13 -> Consume 5 cycles by guaranteeing we cross a page boundary
    sta HMP0,x
    sta RESP0,x              ; 21/ 26/31/36/41/46/51/56/61/66/71 - Set the rough position.
    rts

FlapFrame0
    .byte #%00111100;$1E
    .byte #%11111110;$1E
    .byte #%11111111;$1E
    .byte #%11111111;$1E
    .byte #%01111010;$1E
    .byte #%01111110;$1E
    .byte #%00111100;$1E
    .byte #%00011000;$1E

FlapFrame1
    .byte #%00111100;$1E
    .byte #%00111110;$1E 
    .byte #%01111111;$1E
    .byte #%11111111;$1E
    .byte #%11111010;$1E
    .byte #%11111110;$1E
    .byte #%00111100;$1E
    .byte #%00011000;$1E

    ORG $FE00
fineAdjustBegin
    DC.B %01110000 ; Left 7
    DC.B %01100000 ; Left 6
    DC.B %01010000 ; Left 5
    DC.B %01000000 ; Left 4
    DC.B %00110000 ; Left 3
    DC.B %00100000 ; Left 2
    DC.B %00010000 ; Left 1
    DC.B %00000000 ; No movement.
    DC.B %11110000 ; Right 1
    DC.B %11100000 ; Right 2
    DC.B %11010000 ; Right 3
    DC.B %11000000 ; Right 4
    DC.B %10110000 ; Right 5
    DC.B %10100000 ; Right 6
    DC.B %10010000 ; Right 7

fineAdjustTable EQU fineAdjustBegin - %11110001 ; NOTE: %11110001 = -15

    ORG $FFFA
InterruptVectors
    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END