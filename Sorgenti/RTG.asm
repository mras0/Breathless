                include 'System'
                include 'TMap.i'

                xdef RTGInit
                xdef RTGCleanup
                xdef RTGLock
                xdef RTGUnlock
                xdef RTGShowPic
                xdef RTGChooseMode
                xdef RTGInitTerminal
                xdef RTGUpdateTermainal

                xdef bmBytesPerRow
                xdef bmData

                xref SpriteFlag
                xref Sprites
                xref screen_viewport
                xref screen_bitmap1
;
; Parameters for LockBitMapTagList()
;

LBMI_WIDTH              EQU     ($84001001)
LBMI_HEIGHT             EQU     ($84001002)
LBMI_DEPTH              EQU     ($84001003)
LBMI_PIXFMT             EQU     ($84001004)
LBMI_BYTESPERPIX        EQU     ($84001005)
LBMI_BYTESPERROW        EQU     ($84001006)
LBMI_BASEADDRESS        EQU     ($84001007)

;
; FilterTags
;
CYBRMREQ_TB		EQU	(TAG_USER+$40000)

CYBRMREQ_MinDepth	EQU	(CYBRMREQ_TB+0)		; Minimum depth for displayed screenmode
CYBRMREQ_MaxDepth	EQU	(CYBRMREQ_TB+1)		; Maximum depth  "       "        "
CYBRMREQ_MinWidth	EQU	(CYBRMREQ_TB+2)		; Minumum width  "       "        "
CYBRMREQ_MaxWidth	EQU	(CYBRMREQ_TB+3)		; Maximum width  "       "        "
CYBRMREQ_MinHeight	EQU	(CYBRMREQ_TB+4)		; Minumum height "       "        "
CYBRMREQ_MaxHeight	EQU	(CYBRMREQ_TB+5)		; Minumum height "       "        "
CYBRMREQ_CModelArray	EQU	(CYBRMREQ_TB+6)		; Filters certain color models

CYBRMREQ_WinTitle	EQU	(CYBRMREQ_TB+20)
CYBRMREQ_OKText		EQU	(CYBRMREQ_TB+21)
CYBRMREQ_CancelText	EQU	(CYBRMREQ_TB+22)

CYBRMREQ_Screen		EQU	(CYBRMREQ_TB+30)	; Screen you wish the Requester to opened on

_LVOIsCyberModeID       EQU     -54     ; BOOL IsCyberModeID(ULONG displayID) (d0)
_LVOBestCModeIDTagList  EQU     -60     ; ULONG BestCModeIDTagList(struct TagItem * BestModeIDTags) (a0)
_LVOCModeRequestTagList EQU     -66     ; ULONG CModeRequestTagList(APTR ModeRequest, struct TagItem * ModeRequestTags) (a0,a1)
_LVOLockBitMapTagList   EQU     -168    ; APTR LockBitMapTagList(APTR BitMap, struct TagItem * TagList) (a0,a1)
_LVOUnLockBitMap        EQU     -174    ; void UnLockBitMap(APTR Handle) (a0)

RTGInit:
		move.l	#SCREEN_WIDTH,d0
		move.l	#SCREEN_HEIGHT,d1
		move.l	#SCREEN_DEPTH,d2
                moveq   #0,d3
                move.l  screen_bitmap1(a5),a0
		CALLSYS	AllocBitMap
		move.l	d0,backup_bitmap(a5)
		beq	.error
.ok
                moveq   #0,d0
                rts
.error
                moveq   #-1,d0
                rts

RTGCleanup:
                FREEBITMAP backup_bitmap
                rts

; a0 = bitmap
RTGLock:
                move.l  a6,-(sp)
                move.l  cgxbase(a5),a6
                lea     lbmtags(pc),a1
                move.l  cgxbase(a5),a6
                CALLSYS LockBitMapTagList
                move.l  d0,bmLock(a5)
                move.l  (sp)+,a6
                rts

lbmtags:
                dc.l    LBMI_BYTESPERROW,bmBytesPerRow
                dc.l    LBMI_BASEADDRESS,bmData
                dc.l    0 ; TAG_END


RTGUnlock:
                move.l  bmLock(a5),d0
                beq     .out
                tst.b   SpriteFlag(a5)
                beq     .nosprites
                move.l  d0,-(sp)
                bsr     RTGDrawSprites
                movem.l (sp)+,d0
.nosprites:
                clr.l   bmLock(a5)
                move.l  d0,a0
                move.l  a6,-(sp)
                move.l  cgxbase(a5),a6
                CALLSYS UnLockBitMap
                move.l  (sp)+,a6
.out:
                rts


                xref    PicPun
                xref    screen_bitmap1
RTGShowPic:
                move.l  screen_bitmap1(a5),a0
                bsr     RTGLock
                tst.l   d0
                beq     .out

                move.l  PicPun(a5),a4

                ;   0 UWORD ??
                ;   2 UWORD ??
                ;   4 UWORD XOffset
                ;   6 UWORD YOffset
                ;   8 UWORD Width
                ;  10 UWORD Height
                ;  12 UBYTE[256*3] Palette
                ; 780 UBYTE[] ChunkyData

                move.l  bmData(a5),a0
                move.w  4(a4),d0
                mulu.w  bmBytesPerRow+2(a5),d0
                add.l   d0,a0
                add.w   6(a4),a0


                lea     780(a4),a1
                move.w  10(a4),d0
.y:
                move.l  a0,a2
                move.w  8(a4),d1
                lsr.w   #2,d1
.x:
                move.l  (a1)+,(a2)+
                subq.w  #1,d1
                bne     .x
                add.l   bmBytesPerRow(a5),a0
                subq.w  #1,d0
                bne     .y

                bsr     RTGUnlock

.out            rts

RTGChooseMode:
                move.l  cgxbase(a5),d0
                bne     .RTG
                rts
.RTG
                move.l  d0,a6
                sub.l   a0,a0
                lea     modetaglist(pc),a1
                CALLSYS CModeRequestTagList

                ;move.l  #$50011000,d0   ; UAEGFX:320x240
                ;move.l  #$50091000,d0   ; UAEGFX:320x256
                ;move.l  #$50191000,d0   ; PISTORM:320x256
                ;moveq   #0,d0
                rts

modetaglist:
                dc.l    CYBRMREQ_WinTitle,modetitle
                dc.l    CYBRMREQ_MinWidth,SCREEN_WIDTH
                dc.l    CYBRMREQ_MaxWidth,SCREEN_WIDTH*2
                dc.l    CYBRMREQ_MinHeight,SCREEN_HEIGHT
                dc.l    CYBRMREQ_MaxHeight,SCREEN_HEIGHT*2
                dc.l    CYBRMREQ_MinDepth,SCREEN_DEPTH
                dc.l    CYBRMREQ_MaxDepth,SCREEN_DEPTH
                dc.l    0 ; TAG_END

modetitle:
                dc.b    'Choose RTG mode (cancel for AGA)',0
                EVEN

; The temrinal is made using sprites 6+7, each 4 colors and 64-bit wide
; The cross hair is made up of sprites 4+5 attached, 16 colors and 64-bit wide
; The base color registers are set both to 48


;       dc.w  sprpos, 0, 0, 0, sprctl, 0, 0, 0
;       dc.l  bpl1left, bpl1right, bpl2left, bpl2right
SPRLONG4        MACRO
                move.l  (a0)+,d0
                move.l  4(a0),d1
                moveq   #32-1,d6
                ; Skip if completely transparent
                move.l  d0,d2
                or.l    d1,d2
                bne     .x\@
                add.w   #32,a3
                bra     .out\@
.x\@
                moveq   #0,d2
                add.l   d1,d1
                addx.b  d2,d2
                add.l   d0,d0
                addx.b  d2,d2   ; Z only cleared if result is non-zero
                tst.b   d2
                beq     .next\@
                add.b   #48+12,d2       ; Hardcoded for sprites 6/7 w/ base=48
                move.b  d2,(a3)

.next\@         addq.w  #1,a3
                dbf     d6,.x\@
.out\@
                ENDM

Do4ColSprite:
                move.w  ss_height(a0),d7
                cmp.w   #1,d7
                bls     .out
                move.l  bmData(a5),a4
                add.w   ss_x(a0),a4
                move.l  bmBytesPerRow(a5),d0
                mulu.w  ss_y(a0),d0
                add.l   d0,a4
                move.l  ss_posctldata(a0),a0
                lea     16(a0),a0               ; Skip pos/control
.y:
                move.l  a4,a3
                SPRLONG4
                SPRLONG4
                addq.w  #8,a0   ; To next row
                add.l   bmBytesPerRow(a5),a4
                subq.w  #1,d7
                bne     .y
.out:
                rts

SPRLONG16       MACRO
                move.l  (a0)+,d0
                move.l  4(a0),d1
                move.l  (a1)+,d2
                move.l  4(a1),d3
                moveq   #32-1,d6
                ; Skip if completely transparent
                move.l  d0,d4
                or.l    d1,d4
                or.l    d2,d4
                or.l    d3,d4
                bne     .x\@
                add.w   #32,a3
                bra     .out\@
.x\@
                moveq   #0,d4
                add.l   d3,d3
                addx.b  d4,d4
                add.l   d2,d2
                addx.b  d4,d4
                add.l   d1,d1
                addx.b  d4,d4
                add.l   d0,d0
                addx.b  d4,d4
                tst.b   d4
                beq     .next\@
                add.b   #48,d4
                move.b  d4,(a3)

.next\@         addq.w  #1,a3
                dbf     d6,.x\@
.out\@
                ENDM

RTGDrawSprites:
                movem.l d2-d7/a2-a4,-(sp)

                move.l  Sprites+6*4(a5),a0
                bsr     Do4ColSprite
                move.l  Sprites+7*4(a5),a0
                bsr     Do4ColSprite

                ; 16-color sprite
                move.l  Sprites+4*4(a5),a0
                move.w  ss_height(a0),d7
                cmp.w   #1,d7
                bls     .out

                move.l  bmData(a5),a4
                add.w   ss_x(a0),a4
                move.l  bmBytesPerRow(a5),d0
                mulu.w  ss_y(a0),d0
                add.l   d0,a4
                move.l  ss_posctldata(a0),a0
                lea     16(a0),a0               ; Skip pos/control

                ; Get attached sprite
                move.l  Sprites+5*4(a5),a1
                move.l  ss_posctldata(a1),a1
                lea     16(a1),a1               ; skip pos/control
.y:
                move.l  a4,a3
                SPRLONG16
                SPRLONG16
                addq.w  #8,a0   ; To next row
                addq.w  #8,a1   ; To next row
                add.l   bmBytesPerRow(a5),a4
                subq.w  #1,d7
                bne     .y
.out:
                movem.l (sp)+,d2-d7/a2-a4
                rts

; a0=src, a1=dest
CopyTerminalPart:
                movem.l d2-d7/a2/a6,-(sp)
                move.l  Sprites+6*4(a5),a2
                move.w  ss_x(a2),d0             ; SrcX
                move.w  ss_y(a2),d1             ; SrcY
                move.w  d0,d2                   ; DstX
                move.w  d1,d3                   ; DstY
                move.w  #128,d4                 ; SizeX
                move.w  #SPRMON_HEIGHT,d5       ; SizeY
                move.w  #$C0,d6                 ; Minterm
                moveq   #-1,d7                  ; Mask
                sub.l   a2,a2                   ; TempA
                GFXBASE
                CALLSYS BltBitMap
                movem.l (sp)+,d2-d7/a2/a6
                rts

RTGInitTerminal:
		move.l	screen_viewport(a5),a0
                move.l  vp_RasInfo(a0),a0
                move.l  ri_BitMap(a0),a0
                move.l  backup_bitmap(a5),a1
                bra     CopyTerminalPart
                rts

RTGUpdateTermainal:
                movem.l a2/a6,-(sp)
		move.l	screen_viewport(a5),a0
                GFXBASE
                CALLSYS WaitBOVP
		move.l	screen_viewport(a5),a2
                move.l  vp_RasInfo(a2),a2
                move.l  ri_BitMap(a2),a2
                move.l  backup_bitmap(a5),a0
                move.l  a2,a1
                bsr     CopyTerminalPart
                move.l  a2,a0
                bsr     RTGLock
                bsr     RTGUnlock
                movem.l (sp)+,a2/a6
                rts


	        section	__MERGED,bss
bmLock          ds.l 1
bmBytesPerRow   ds.l 1
bmData          ds.l 1
backup_bitmap   ds.l 1
