                include 'System'
                include 'TMap.i'

                xdef RTGLock
                xdef RTGUnlock
                xdef RTGShowPic
                xdef RTGChooseMode

                xdef bmBytesPerRow
                xdef bmData

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


; a0 = bitmap
RTGLock:
                move.l  a6,-(sp)
                move.l  cgxbase(a5),a6
                lea     lbmtags(pc),a1
                move.l  cgxbase(a5),a6
                jsr     _LVOLockBitMapTagList(a6)
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
                clr.l   bmLock(a5)
                move.l  d0,a0
                move.l  cgxbase(a5),a6
                move.l  a6,-(sp)
                jsr     _LVOUnLockBitMap(a6)
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


	        section	__MERGED,bss
bmLock          ds.l 1
bmBytesPerRow   ds.l 1
bmData          ds.l 1
