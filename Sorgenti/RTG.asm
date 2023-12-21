                include 'System'
                include 'TMap.i'

                xdef RTGLock
                xdef RTGUnlock
                xdef RTGShowPic
                xdef bmBytesPerRow
                xdef bmData

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

	        section	__MERGED,bss
bmLock          ds.l 1
bmBytesPerRow   ds.l 1
bmData          ds.l 1
