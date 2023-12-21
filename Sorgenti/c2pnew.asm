                include 'System'
                include 'tmap.i'

                xref c2p1x1_8_c5_bm_040
                xref c2p2x1_8_c5_bm
                xref c2p2x2_8_c5_bm
                xref RTGFlag,cgxbase
                xref panel_bitmap

; void __asm c2p8_init (register __a0 UBYTE *chunky,	// pointer to chunky data
;			register __a1 ULONG mode,	// conversion mode
;			register __d0 ULONG signals1,	// 1 << sigbit1
;			register __d1 ULONG signals2,	// 1 << sigbit2
;			register __d2 ULONG width,      // window width
;			register __d3 ULONG height,     // window height
;			register __d4 ULONG offset,     // byte offset into plane
;			register __d5 UBYTE *buff2,	// Chip buffer width*height
;			register __d6 UBYTE *buff3,	// Chip buffer width*height
;			register __d7 ULONG scrwidth,   // screen width
;			register __a3 struct GfxBase *GfxBase);

; Mode (a1) bit 0: double x, bit 1: double y
c2p8_init::
        move.l  a0,chunky
        move.l  d2,cwidth
        move.l  d3,cheight

        move.l  a1,d0
        btst.l  #0,d0
        beq     .nodblx
        add.l   d2,d2
.nodblx:
        btst.l  #1,d0
        beq     .nodbly
        add.l   d3,d3
.nodbly:
        move.l  #320,d0
        move.l  #200,d1

        sub.l   d2,d0
        sub.l   d3,d1
        lsr.l   #1,d0
        lsr.l   #1,d1
        move.l  d0,sxofs
        move.l  d1,syofs
        lea     .c2pfuncs(pc),a0
        tst.b   RTGFlag(a5)
        beq     .aga
        lea     .rtgfuncs(pc),a0
.aga
        move.l  a1,d0
        and.w   #3,d0
        move.l  (a0,d0.w*4),c2pfunc
        rts
.c2pfuncs:
        dc.l    c2p1x1_8_c5_bm_040      ; 1x1
        dc.l    c2p2x1_8_c5_bm          ; 2x1
        dc.l    c2p8_1x2                ; 1x2
        dc.l    c2p2x2_8_c5_bm          ; 2x2
.rtgfuncs:
        dc.l    rtg
        dc.l    rtg
        dc.l    rtg
        dc.l    rtg

c2p8_1x2:
        ; HACK: Double BytesPerRow per row (and restore)
        move.l  a1,a2
        lsl.l   (a2)
        jsr     c2p1x1_8_c5_bm_040
        lsr.r   (a2)
        rts

; void c2p8_go(register __a0 PLANEPTR *planes, // pointer to planes
;		);
c2p8_go::
        movem.l d2-d3/a2,-(sp)
        lea     -8(a0),a1              ; Move offset to bitmap
        movem.l cwidth(pc),d0-d3/a0/a2
        jsr     (a2)
        movem.l (sp)+,d2-d3/a2
        rts

c2p8_waitblitter::
        rts


; a0	chunkyscreen
; a1	BitMap
rtg:
        movem.l d2-d7/a2-a6,-(sp)
        move.l  a0,a2
        move.l  a1,a0
        move.l  a1,a4                           ; a4 = bitmap
        lea     lbmtags(pc),a1
        move.l  cgxbase(a5),a6
        jsr     _LVOLockBitMapTagList(a6)
        tst.l   d0
        beq     .out
        ; Preserve d0! for unlock

        move.l  bmData(pc),a1
        move.l  bmBytesPerRow(pc),d1

        add.l   sxofs(pc),a1
        move.l  syofs(pc),d2
        mulu.l  d1,d2
        add.l   d2,a1

        move.l  cheight(pc),d3
        ; a2 = src, a1 = dest
.y:
        move.l  a1,a3
        move.l  cwidth(pc),d4
        lsr.l   #2,d4
.x:
        move.l  (a2)+,(a3)+
        subq.w  #1,d4
        bne     .x
        add.l   d1,a1
        subq.w  #1,d3
        bne     .y

        move.l  d0,a0
        jsr     _LVOUnLockBitMap(a6)

        ; Panel

        move.l  panel_bitmap(a5),a0     ; SrcBitMap
        moveq   #0,d0                   ; SrcX
        moveq   #0,d1                   ; SrcY
        move.l  a4,a1                   ; DstBitMap
        moveq   #0,d2                   ; DstX
        move.w  #SCREEN_HEIGHT-PANEL_HEIGHT,d3 ; DstY
        move.w  #SCREEN_WIDTH,d4        ; SizeX
        move.w  #PANEL_HEIGHT,d5        ; SizeY
        move.w  #$C0,d6                 ; Minterm
        moveq   #-1,d7                  ; Mask
        sub.l   a2,a2                   ; TempA
        GFXBASE
        jsr     _LVOBltBitMap(a6)

.out:
        movem.l (sp)+,d2-d7/a2-a6
        rts

                cnop    0,4
; Keep in order of arguments for c2p routine
cwidth          ds.l    1
cheight         ds.l    1
sxofs           ds.l    1
syofs           ds.l    1
chunky          ds.l    1
c2pfunc         ds.l    1

bmBytesPerRow   ds.l 1
bmData          ds.l 1
lbmtags:
        dc.l    LBMI_BYTESPERROW,bmBytesPerRow
        dc.l    LBMI_BASEADDRESS,bmData
        dc.l    0 ; TAG_END
