;***************************************************************
;*
;*	-Tracciamento dello schermo corrente
;*
;*	-Traccia il pavimento e il soffitto in texture mapping
;*	 convertendo i trattini verticali di pavimento in
;*	 trattini orizzontali.
;*
;*	-Traccia oggetti.
;*
;*	-E' una ottimizzazione di DrawScreen.asmD
;*
;*	-Ottimizzato il texture mapping
;*
;*	-Codice per permettere di alzare/abbassare lo sguardo
;*
;*	-Aggirato problema tremolio lowertexture adiacenti ad
;*	 ascensori o porte: ho sostituito le istruzioni
;*
;*		clr.w	d1
;*		divs.l	d6,d1		;d1=passo=(Dim.wall / Num.pixel)
;*
;*	 con:
;*
;*		move.l	-8(a2),d1
;*
;*	 In questo modo scompare il tremolio, ma il texture mapping
;*	 e' lievemente piu' impreciso. Per il futuro sarebbe
;*	 conveniente trovare un sistema migliore.
;*
;*	-Ottimizzazione del ciclo di riempimento OTable
;*
;*	-Ottimizzazione delle somme nei cicli di mapping:
;*	 sostituite le somme  adda.l d5,a1  con  adda.l ax,a1
;*
;***************************************************************


		include	'TMap.i'
		include	'MulDiv64.i'
		include	'System'

;ChunkyPointer	EQU	0

		xref	ChunkyPointer,ChunkyBuffer,CurrentBitmap
		xref	ChunkyBuffer,CurrentBitmap
		xref	Yoffset,YoffsetPlus4
		xref	source_width
		xref	window_width,window_height
		xref	window_width2,window_height2,window_size
		xref	windowYratio,SkyXratio,SkyYratio
		xref	vtable
		xref	RayDirTab
		xref	PlayerX,PlayerY,PlayerZ
		xref	PlayerBlock,PlayerBlockPun
		xref	SkyRotation
		xref	Textures,Objects,Blocks

;*********************************************************************

; \1 = Masking/tiling (with d7)
; d2.l must be 0
MFWINNERLOOP    MACRO
.loop\@	
                REPT    2
                IFEQ    __CPU-68060
                move.b	(a0,d0.w),d2
		addx.l	d1,d0
		move.b	(a3,d2.l),d2
                IFNE    \1
		and.w	d7,d0
                ENDC
                move.b  d2,(a1)
		adda.l	a4,a1
                ELSE
                move.b	(a0,d0.w),d2
		move.b	(a3,d2.w),(a1)
		addx.l	d1,d0
		adda.l	a4,a1
                IFNE \1
		and.w	d7,d0
                ENDC
                ENDC    ; 68060
                ENDR
                dbra	d6,.loop\@
                ENDM

MTCINNERLOOP    MACRO
                ;d0 = U
                ;d1 = V
                ;d2 = dUdX
                ;d3 = dVdX
                ;d4 = 0
                ;d5 = Free
		;d6 = $0fc0_0000 (63*64<<16)
		;d7 = $003f_ffff
                ;a3 = Lighting tab
                ;a4 = Chunkybuf
                ;a6 = Texture (64*64)

                IFEQ    __CPU-68060
                and.l	d7,d0
		move.l	d1,d5
		and.l	d6,d5
		or.l	d0,d5
		swap	d5
.loop\@         move.b	(a6,d5.w),d4
		add.l	d2,d0
		add.l	d3,d1
                and.l	d7,d0
		move.l	d1,d5
		and.l	d6,d5
		or.l	d0,d5
		swap	d5
		move.b	(a3,d4.l),(a4)+
                subq.w  #1,d6
                bpl     .loop\@

                ELSE ; 060
.loop\@		and.l	d7,d0
		move.l	d1,d5
		and.l	d6,d5
		or.l	d0,d5
		swap	d5
		move.b	(a6,d5.w),d4
		move.b	(a3,d4.w),(a4)+		;Write Pixel
		add.l	d2,d0			;d0+=DU
		add.l	d3,d1			;d1+=DV
		dbra	d6,.loop\@
                ENDC    ; 060
                ENDM

StretchUpperTexture	MACRO

		move.w	(a2),d2			;d2=brush column offset
		and.w	#63,d2			;d2=num. colonna brush
		move.l	4(a2),a0		;a0=pun. edge
		clr.l	d0
		btst	#0,ed_Attribute+1(a0)	;Test if upper texture is unpegged
		beq.s	MFWnounpegged\@
		move.l	ed_UpTexture(a0),a0	;a0=pun. brush
		move.w	(a0)+,d0		;d0=brush height
		move.w	d0,d5			;d5=brush height for tile test
		sub.w	d1,d0			;d0=brush height - dim.wall
		swap	d0
		bra.s	MFWunpegged\@
MFWnounpegged\@	move.l	ed_UpTexture(a0),a0	;a0=pun. brush
		move.w	(a0)+,d5		;d5=brush height for tile test
MFWunpegged\@
		cmp.w	d5,d1			;Dim.wall > (brush height) ?
		bgt.s	MFWtileon\@		;if true, do vertical tile
		moveq	#0,d5			;if false, reset vertical tile
MFWtileon\@
		swap	d1
		move.w	(a0)+,d1		;d1.w=shift height
		lsl.w	d1,d2			;moltiplica num.colonna brush per num.pixel per colonna
		move.l	(a0),a0
		add.w	d2,a0

		clr.w	d1
		divs.l	d6,d1		;d1=passo=(Dim.wall / Num.pixel)

		cmp.l	d3,d7		;Test se clip min y
		bgt.s	MFWnominclip\@
		move.l	d3,d2
		sub.l	d7,d2
		addq.l	#1,d2
		sub.l	d2,d6		;Corregge Num.pixel
		ble	MFWnext\@
		mulu.l	d1,d2
		add.l	d2,d0		;Corregge Start acc.
		move.l	d3,d7
		addq.l	#1,d7
MFWnominclip\@	
		move.l	a1,-(sp)

		move.l	Yoffset.w(a5,d7.w*4),a1
		add.l	ChunkyPointer(a5),a1		;a1=Pun. a video

		move.l	d3,d2
		sub.l	d7,d2
		move.l	d2,-(sp)	;-(Num.pixel ceiling)
		move.l	d3,-(sp)	;y1 ceiling
		move.l	d7,d2

		add.l	d6,d7
		sub.l	d4,d7		;Test se clip max y
		ble.s	MFWnomaxclip\@
		sub.l	d7,d6		;Corregge Num.pixel
		bgt.s	MFWnomaxclip\@
		move.l	d3,d1		;y1 ceiling
		move.l	d4,d6
		sub.l	d3,d6		;-(Num.pixel ceiling)
		addq.l	#8,sp
		move.l	(sp)+,a1	;Block pun.
		move.l	d4,d3
		bra	MFWfillceil\@
MFWnomaxclip\@
		add.l	d6,d2
		subq.l	#1,d2
		move.l	d2,d3

	;*** Ciclo di copia

		clr.l	d2

		tst.w	d5		;Test if vertical tile
		beq.s	MFWnotile2\@

			;***** Vertical tile
		move.w	d5,d7
		subq.w	#1,d7

		ror.l	#1,d6
		add.w	d1,d0
		swap	d1
		swap	d0
		and.w	d7,d0
		dbra	d6,MFWcopyloopT\@
		bra.s	MFWendstretch\@
		cnop	0,8
MFWcopyloopT\@	MFWINNERLOOP 1
                bra.s	MFWendstretch\@

			;***** No vertical tile
MFWnotile2\@
		ror.l	#1,d6
		add.w	d1,d0
		swap	d1
		swap	d0
		dbra	d6,MFWcopyloop\@
		bra.s	MFWendstretch\@
		cnop	0,8
MFWcopyloop\@	MFWINNERLOOP 0
MFWendstretch\@	tst.l	d6
		bpl.s	MFWfff\@
		move.b	(a0,d0.w),d2
		move.b	(a3,d2.l),(a1)
MFWfff\@

		move.l	(sp)+,d1	;y1
		move.l	(sp)+,d6	;-(Num.pixel)
		move.l	(sp)+,a1	;Block pun.
		neg.l	d6
MFWfillceil\@
		move.w	bl_CeilTexture(a1),d2
		bpl	FCnosky\@

				;*** Traccia cielo
		neg.w	d2
		move.l	Textures(a5),a0
		move.l	(a0,d2.w*4),a0
		move.l	4(a0),a0		;a0=Pun.texture
		move.l	SkyRotation(a5),d2
		clr.w	d2
		lsr.l	#4,d2			;d2=SkyRotation<<12
		move.w	currentx(a5),d0
		mulu	SkyXratio(a5),d0
		add.l	d2,d0			;d0=colonna dello sky brush da tracciare
		lsr.l	#4,d0
		clr.b	d0
		lsr.w	#1,d0
		move.b	(a0),d7			;d7=Colore dei pixel superiori
		add.w	d0,a0			;a0=Pun.colonna texture
		move.l	YoffsetPlus4.w(a5,d1.w*4),a1
		add.l	ChunkyPointer(a5),a1	;a1=Pun. a video
		subq.w	#1,d6

		move.l	LookHeight(a5),d0
		sub.l	d1,d0
		ble.s	FCnofixcolor\@
		cmp.w	d6,d0			;Aggiusta il numero di pixel da tracciare
		ble.s	FCcmpj1\@
		move.w	d6,d0
FCcmpj1\@	sub.w	d0,d6
		ror.l	#1,d0
		dbra	d0,FCloopfcS\@
		bra.s	FCendloopfcS\@
		cnop	0,8
FCloopfcS\@	move.b	d7,(a1)			;Ciclo per tracciare i pixel del cielo di un solo colore
		adda.l	a4,a1
		move.b	d7,(a1)
		adda.l	a4,a1
		dbra	d0,FCloopfcS\@
FCendloopfcS\@	tst.l	d0			;Traccio il pixel dispari ?
		bpl.s	FCd0\@
		move.b	d7,(a1)
		adda.l	a4,a1
FCd0\@		clr.l	d0
FCnofixcolor\@
		neg.l	d0		;Sottrae LookHeight (se il player abbassa la testa)
FCnolowlook\@	move.l	SkyYratio(a5),d1
		addq.l	#1,d0
		mulu.l	d1,d0
		ror.l	#1,d6
		add.w	d1,d0
		swap	d1
		swap	d0
		dbra	d6,FCloopS\@
		bra.s	FCendloopS\@
		cnop	0,8
FCloopS\@	move.b	(a0,d0.w),(a1)
		adda.l	a4,a1
		addx.l	d1,d0
		move.b	(a0,d0.w),(a1)
		adda.l	a4,a1
		addx.l	d1,d0
		dbra	d6,FCloopS\@
FCendloopS\@	tst.l	d6
		bpl.s	FCout\@
		move.b	(a0,d0.w),(a1)
		bra.s	FCout\@

FCnosky\@			;*** Riempie OTable
		subq.w	#2,d6
		blt.s	FCout\@
		lea	(OTablePun+4,pc,d1.w*4),a0
		move.l	currentx1(a5),d7
		move.w	bl_BlockNumber(a1),d7	;d7=((currentx-1)<<16) | BlockNumber
		move.w	currentx(a5),d2		;d2=currentx
		bra.s	FCloop\@
		cnop	0,8
FCloop\@	cmp.l	(a0)+,d7	;Test se le caratteristiche sono uguali
		bne.s	FCinitspan\@	;Se x diverse deve inizializzare una nuova struttura e quindi un nuovo trattino
		move.w	d2,-4(a0)	;Incrementa x2 della struttura corrente
		dbra	d6,FCloop\@
		bra.s	FCout\@
FCinitspan\@	move.l	800-4(a0),a1	;a1=Pun. alla struttura da terminare
		move.l	-4(a0),(a1)	;Copia le caratteristiche nella struttura da terminare
		addq.w	#6,a1		;salta alla prossima struttura
		move.l	a1,800-4(a0)	;scrive il pun. alla nuova struttura
		move.w	d2,-4(a0)	;Scrive x2 della nuova struttura
		move.w	d7,-2(a0)	;Scrive BlockNumber della nuova struttura
		move.w	d2,(a1)+	;Scrive x2
		move.w	d7,(a1)+	;Scrive BlockNumber
		move.w	d2,(a1)+	;Scrive x1
		dbra	d6,FCloop\@
FCout\@
MFWnext\@
		ENDM

;*********************************************************************

StretchLowerTexture	MACRO

		move.w	(a2),d2			;d2=brush column offset
		and.w	#63,d2			;d2=num. colonna brush
		move.l	4(a2),a0		;a0=pun. edge
		clr.l	d0
		btst	#1,ed_Attribute+1(a0)	;Test if lower texture is unpegged
		beq.s	MFWnounpegged\@
		move.l	ed_LowTexture(a0),a0	;a0=pun. brush
		move.w	(a0)+,d0		;d0=brush height
		move.w	d0,d5			;d5=brush height for tile test
		sub.w	d1,d0			;d0=brush height - dim.wall
		swap	d0
		bra.s	MFWunpegged\@
MFWnounpegged\@	move.l	ed_LowTexture(a0),a0	;a0=pun. brush
		move.w	(a0)+,d5		;d5=brush height for tile test
MFWunpegged\@
		cmp.w	d5,d1			;Dim.wall > (brush height) ?
		bgt.s	MFWtileon\@		;if true, do vertical tile
		moveq	#0,d5			;if false, reset vertical tile
MFWtileon\@
		swap	d1
		move.w	(a0)+,d1		;d1.w=shift height
		lsl.w	d1,d2			;moltiplica num.colonna brush per num.pixel per colonna
		move.l	(a0),a0
		add.w	d2,a0

;		clr.w	d1
;		divs.l	d6,d1		;d1=passo=(Dim.wall / Num.pixel)
		move.l	-8(a2),d1	;d1=passo=distance

		cmp.l	d3,d7		;Test se clip min y
		bgt.s	MFWnominclip\@
		move.l	d3,d2
		sub.l	d7,d2
		addq.l	#1,d2
		sub.l	d2,d6		;Corregge Num.pixel
		ble	MFWfillfloor1\@
		mulu.l	d1,d2
		add.l	d2,d0		;Corregge Start acc.
		move.l	d3,d7
		addq.l	#1,d7
MFWnominclip\@	
		move.l	a1,-(sp)

		move.l	Yoffset.w(a5,d7.w*4),a1
		add.l	ChunkyPointer(a5),a1		;a1=Pun. a video

		move.l	d7,d2

		add.l	d6,d7
		sub.l	d4,d7		;Test se clip max y
		ble.s	MFWnomaxclip\@
		sub.l	d7,d6		;Corregge Num.pixel
		bgt.s	MFWnomaxclip\@
		addq.l	#4,sp
		bra	MFWnext\@
MFWnomaxclip\@
		neg.l	d7		;d7=-d7
		move.l	d7,-(sp)	;Num.pixel floor
		move.l	d4,-(sp)	;y1 floor
		move.l	d2,d4

	;*** Ciclo di copia

		clr.l	d2

		tst.w	d5		;Test if vertical tile
		beq.s	MFWnotile2\@

			;***** Vertical tile
		exg.l	d5,d7
		subq.w	#1,d7

		ror.l	#1,d6
		add.w	d1,d0
		swap	d1
		swap	d0
		and.w	d7,d0
		dbra	d6,MFWcopyloopT\@
		bra.s	MFWendstretch\@
		cnop	0,8
MFWcopyloopT\@	MFWINNERLOOP 1
                bra.s	MFWendstretch\@

			;***** No vertical tile
MFWnotile2\@
		ror.l	#1,d6
		add.w	d1,d0
		swap	d1
		swap	d0
		dbra	d6,MFWcopyloop\@
		bra.s	MFWendstretch\@
		cnop	0,8
MFWcopyloop\@	MFWINNERLOOP 0
MFWendstretch\@	tst.l	d6
		bpl.s	MFWfff\@
		move.b	(a0,d0.w),d2
		move.b	(a3,d2.w),(a1)
MFWfff\@

		move.l	(sp)+,d1	;y1
		move.l	(sp)+,d6	;Num.pixel
		move.l	(sp)+,a1	;Block pun.
		bra.s	MFWfillfloor2\@
MFWfillfloor1\@	move.l	d4,d1
		move.l	d4,d6
		sub.l	d3,d6
		subq.l	#1,d6
		move.l	d3,d4
MFWfillfloor2\@	subq.w	#1,d6
		blt.s	FFout\@
		lea	(OTablePun,pc,d1.w*4),a0
		move.l	currentx1(a5),d7
		move.w	bl_BlockNumber(a1),d7	;d7=((currentx-1)<<16) | BlockNumber
		move.w	currentx(a5),d2		;d2=currentx
		bra.s	FFloop\@
		cnop	0,8
FFloop\@	cmp.l	-(a0),d7	;Test se le caratteristiche sono uguali
		bne.s	FFinitspan\@	;Se x diverse deve inizializzare una nuova struttura e quindi un nuovo trattino
		move.w	d2,(a0)		;Incrementa x2 della struttura corrente
		dbra	d6,FFloop\@
		bra.s	FFout\@
FFinitspan\@	move.l	800(a0),a1	;a1=Pun. alla struttura da terminare
		move.l	(a0),(a1)	;Copia le caratteristiche nella struttura da terminare
		addq.w	#6,a1		;salta alla prossima struttura
		move.l	a1,800(a0)	;scrive il pun. alla nuova struttura
		move.w	d2,(a0)		;Scrive x2 della nuova struttura
		move.w	d7,2(a0)	;Scrive BlockNumber della nuova struttura
		move.w	d2,(a1)+	;Scrive x2
		move.w	d7,(a1)+	;Scrive BlockNumber
		move.w	d2,(a1)+	;Scrive x1
		dbra	d6,FFloop\@
FFout\@
MFWnext\@

		ENDM

;*********************************************************************

StretchNormalTexture	MACRO

		move.w	(a2),d0		;d0=brush column offset
		and.w	#63,d0		;d0=num. colonna brush

		move.w	(a0)+,d5	;d5=brush height
		cmp.w	d5,d1		;Dim.wall > (brush height) ?
		bgt.s	MFWtileon\@	;if true, do vertical tile
		moveq	#0,d5		;if false, reset vertical tile
MFWtileon\@
		swap	d1		;d1.hi=Dim.Wall
		move.w	(a0)+,d1	;d1.lo=shift height
		lsl.w	d1,d0		;moltiplica num.colonna brush per num.pixel per colonna
		move.l	(a0),a0
		add.w	d0,a0		;a0=pun. brush

		clr.w	d1
		divs.l	d6,d1		;d1=passo=(Dim.wall / Num.pixel)

		clr.l	d0

		cmp.l	d3,d7		;Test se clip min y
		bgt.s	MFWnominclip\@
		move.l	d3,d2
		sub.l	d7,d2
		addq.l	#1,d2
		sub.l	d2,d6		;Corregge Num.pixel
		ble	MFWnext\@
		mulu.l	d1,d2
		add.l	d2,d0		;Corregge Start acc.
		move.l	d3,d7
		addq.l	#1,d7
MFWnominclip\@	
		move.l	Yoffset.w(a5,d7.w*4),a1
		add.l	ChunkyPointer(a5),a1		;a1=Pun. a video

		add.l	d6,d7
		sub.l	d4,d7		;Test se clip max y
		ble.s	MFWnomaxclip\@
		sub.l	d7,d6		;Corregge Num.pixel
;		bgt.s	MFWnomaxclip\@
		ble	MFWnext\@
MFWnomaxclip\@

	;*** Ciclo di copia

		clr.l	d2

		tst.w	d5		;Test if vertical tile
		beq.s	MFWnotile2\@

			;***** Vertical tile
		move.w	d5,d7
		subq.w	#1,d7

		ror.l	#1,d6
		add.w	d1,d0
		swap	d1
		swap	d0
		and.w	d7,d0
		dbra	d6,MFWcopyloopT\@
		bra.s	MFWendstretch\@
		cnop	0,8
MFWcopyloopT\@	MFWINNERLOOP 1
		bra.s	MFWendstretch\@

			;***** No vertical tile
MFWnotile2\@
		ror.l	#1,d6
		add.w	d1,d0
		swap	d1
		swap	d0
		dbra	d6,MFWcopyloop\@
		bra.s	MFWendstretch\@
		cnop	0,8
MFWcopyloop\@	MFWINNERLOOP 0
MFWendstretch\@	tst.l	d6
		bpl.s	MFWntnext\@
		move.b	(a0,d0.w),d2
		move.b	(a3,d2.l),(a1)
		bra.s	MFWntnext\@

MFWnext\@
		addq.l	#1,d3
		sub.l	d3,d4
		ble.s	MFWntnext\@

		IFNE	DEBUG
		WAITDEBUG $a0,6	;Test per verificare se questa parte viene eseguita
		ENDC
MFWntnext\@

		ENDM

;*********************************************************************

FillCeiling	MACRO

		move.w	bl_CeilTexture(a1),d1
		bpl	FCnosky\@

				;*** Traccia cielo
		neg.w	d1
		move.l	Textures(a5),a0
		move.l	(a0,d1.w*4),a0
		move.l	4(a0),a0		;a0=Pun.texture
		cmp.l	d4,d7
		blt.s	FCnoclipS\@
		move.l	d4,d7
		subq.l	#1,d7
FCnoclipS\@	move.l	d7,d6
		sub.l	d3,d6		;d6=Num.pixel
		ble	MFWtestfloor	;Se striscia tutta al di sopra di d3, esce
		move.l	SkyRotation(a5),d1
		clr.w	d1
		lsr.l	#4,d1			;d1=SkyRotation<<12
		move.w	currentx(a5),d0
		mulu	SkyXratio(a5),d0
		add.l	d1,d0			;d0=colonna dello sky brush da tracciare
		lsr.l	#4,d0
		clr.b	d0
		lsr.w	#1,d0
		move.l	d3,d1
		move.l	d7,d3
		move.b	(a0),d7			;d7=Colore dei pixel superiori
		add.w	d0,a0			;a0=Pun.colonna texture
		move.l	YoffsetPlus4.w(a5,d1.w*4),a1
		add.l	ChunkyPointer(a5),a1	;a1=Pun. a video

		move.l	LookHeight(a5),d0
		sub.l	d1,d0
		ble.s	FCnofixcolor\@
		cmp.w	d6,d0			;Aggiusta il numero di pixel da tracciare
		ble.s	FCcmpj1\@
		move.w	d6,d0
FCcmpj1\@	sub.w	d0,d6
		ror.l	#1,d0
		dbra	d0,FCloopfcS\@
		bra.s	FCendloopfcS\@
		cnop	0,8
FCloopfcS\@	move.b	d7,(a1)			;Ciclo per tracciare i pixel del cielo di un solo colore
		adda.l	a4,a1
		move.b	d7,(a1)
		adda.l	a4,a1
		dbra	d0,FCloopfcS\@
FCendloopfcS\@	tst.l	d0			;Traccio il pixel dispari ?
		bpl.s	FCd0\@
		move.b	d7,(a1)
		adda.l	a4,a1
FCd0\@		clr.l	d0
FCnofixcolor\@
		neg.l	d0		;Sottrae LookHeight (se il player abbassa la testa)
FCnolowlook\@	move.l	SkyYratio(a5),d1
		addq.l	#1,d0
		mulu.l	d1,d0
		ror.l	#1,d6
		add.w	d1,d0
		swap	d1
		swap	d0
		dbra	d6,FCloopS\@
		bra.s	FCendloopS\@
		cnop	0,8
FCloopS\@	move.b	(a0,d0.w),(a1)
		adda.l	a4,a1
		addx.l	d1,d0
		move.b	(a0,d0.w),(a1)
		adda.l	a4,a1
		addx.l	d1,d0
		dbra	d6,FCloopS\@
FCendloopS\@	tst.l	d6
		bpl.s	FCout\@
		move.b	(a0,d0.w),(a1)
		bra.s	FCout\@

FCnosky\@			;*** Riempie OTable
		cmp.l	d4,d7
		blt.s	FCnoclip\@
		move.l	d4,d7
		subq.l	#1,d7
FCnoclip\@	move.l	d7,d6
		sub.l	d3,d6		;d6=Num.pixel
		ble	MFWtestfloor	;Se striscia tutta al di sopra di d3, esce
		subq.w	#1,d6
		lea	(OTablePun+4,pc,d3.w*4),a0
		move.l	d7,d3
		move.l	currentx1(a5),d7
		move.w	bl_BlockNumber(a1),d7	;d7=((currentx-1)<<16) | BlockNumber
		move.w	currentx(a5),d1		;d1=currentx
		bra.s	FCloop\@
		cnop	0,8
FCloop\@	cmp.l	(a0)+,d7	;Test se le caratteristiche sono uguali
		bne.s	FCinitspan\@	;Se x diverse deve inizializzare una nuova struttura e quindi un nuovo trattino
		move.w	d1,-4(a0)	;Incrementa x2 della struttura corrente
		dbra	d6,FCloop\@
		bra.s	FCout\@
FCinitspan\@	move.l	800-4(a0),a1	;a1=Pun. alla struttura da terminare
		move.l	-4(a0),(a1)	;Copia le caratteristiche nella struttura da terminare
		addq.w	#6,a1		;salta alla prossima struttura
		move.l	a1,800-4(a0)	;scrive il pun. alla nuova struttura
		move.w	d1,-4(a0)	;Scrive x2 della nuova struttura
		move.w	d7,-2(a0)	;Scrive BlockNumber della nuova struttura
		move.w	d1,(a1)+	;Scrive x2
		move.w	d7,(a1)+	;Scrive BlockNumber
		move.w	d1,(a1)+	;Scrive x1
		dbra	d6,FCloop\@
FCout\@
		ENDM




FillFloor	MACRO

		cmp.l	d3,d7
		bgt.s	FFnoclip\@
		move.l	d3,d7
		addq.l	#1,d7
FFnoclip\@	move.l	d4,d6
		sub.l	d7,d6		;d6=Num.pixel
		ble	MFWnofloor	;Se striscia tutta al di sotto di d4, esce
		subq.w	#1,d6
		lea	(OTablePun,pc,d7.w*4),a0
		move.l	d7,d4
		move.l	currentx1(a5),d7
		move.w	bl_BlockNumber(a1),d7	;d7=((currentx-1)<<16) | BlockNumber
		move.w	currentx(a5),d1		;d1=currentx
		bra.s	FFloop\@
		cnop	0,8
FFloop\@	cmp.l	(a0)+,d7	;Test se le caratteristiche sono uguali
		bne.s	FFinitspan\@	;Se x diverse deve inizializzare una nuova struttura e quindi un nuovo trattino
		move.w	d1,-4(a0)	;Incrementa x2 della struttura corrente
		dbra	d6,FFloop\@
		bra.s	FFout\@
FFinitspan\@	move.l	800-4(a0),a1	;a1=Pun. alla struttura da terminare
		move.l	-4(a0),(a1)	;Copia le caratteristiche nella struttura da terminare
		addq.w	#6,a1		;salta alla prossima struttura
		move.l	a1,800-4(a0)	;scrive il pun. alla nuova struttura
		move.w	d1,-4(a0)	;Scrive x2 della nuova struttura
		move.w	d7,-2(a0)	;Scrive BlockNumber della nuova struttura
		move.w	d1,(a1)+	;Scrive x2
		move.w	d7,(a1)+	;Scrive BlockNumber
		move.w	d1,(a1)+	;Scrive x1
		dbra	d6,FFloop\@
FFout\@
		ENDM

;*********************************************************************
; Spara a video i muri in texture mapping leggendo da vtable
;

		xdef	MakeFrame

MakeFrame
;		jsr	ClearScreen

		lea	OTablePun(pc),a0
		lea	OTableList,a1
		move.l	#(6<<5),d0
		move.l	#$fffefffe,d1
		move.w	window_height2+2(a5),d7
		subq.w	#1,d7
Oinitloop	move.l	d1,(a0)+
		move.l	a1,800-4(a0)
		add.l	d0,a1
		move.l	d1,(a0)+
		move.l	a1,800-4(a0)
		add.l	d0,a1
		dbra	d7,Oinitloop


	;***** Make Walls

		lea	vtable-8,a2
		move.l	a2,-(sp)	;Salva sullo stack pun. corrente a vtable

		move.l	#ObjVTable,ObjVTablePun(a5)

		move.l	ChunkyBuffer(a5),ChunkyPointer(a5)	;Init pun. fake chunky
		move.l	source_width(a5),a4	;valore di somma per destinazione

		move.l	#0,currentx(a5)
		move.w	#-1,currentx1(a5)

		subq.w	#4,sp			;Riserva nello stack una long per il puntatore al blocco precedente
		bra.s	MFWloopx

MFWdivisionByZero		;*** Gestione errore divisione per zero
		move.w	#10000,d2
MFWdbz		IFNE	DEBUG
		move.w	#$a00,$dff180
		move.w	#0,$dff180
		ENDC
;		dbra	d2,MFWdbz
		addq.l	#4,a2
		bra.s	MFWloopc

MFWloopx
		move.l	PlayerBlockPun(a5),a6	;Pun. al blocco su cui si trova il player
		moveq	#-1,d3			;d3=clipymin
		move.l	window_height(a5),d4	;d4=clipymax
MFWloopc
		addq.l	#8,a2		;Salta la longword non letta la volta precedente
		move.l	a6,(sp)		;Salva pun. blocco
		addq.l	#1,d3
		cmp.l	d3,d4
		ble	MFWnext
		subq.l	#1,d3
		move.l	a6,a1		;a1=pun. blocco precedente
MFWloope	move.l	(a2)+,d2	;d2=distance
		beq.s	MFWdivisionByZero
		move.l	(a2),a6		;a6=block pointer
					;Notare che il brush column offset non viene letto qui, ma all'interno delle macro di Stretching delle texture

		move.w	d4,(a2)+	;Salva clipymax per il clipping degli oggetti
		move.w	d3,(a2)+	;Salva clipymin per il clipping degli oggetti


		move.l	d2,d1
		add.l	d1,d1
		MULU64	windowYratio(a5),d0,d1,d2,d3,d4	;Aggiusta la distanza in base alle dimensioni della finestra
		move.b	bl_Illumination(a1),d1
		extb.l	d1
		add.l	d1,d0			;d0=Indice lighting table
		move.l	GlobalLight(a5),d1
		tst.b	bl_Illumination+1(a1)	;Test flag nebbia
		lea	LightingTable(a5),a3	;a3=Pun. alla lighting table
		bpl.s	MFWnofog		;Se non c' nebbia, salta
		lea	8192(a3),a3		;Se c' nebbia, passa alla lighting table per la nebbia
		moveq	#0,d1			;Azzera global light
MFWnofog	add.l	d1,d0			;Somma global light
		bmi.s	MFWlitout		;Se negativo usa la prima tabella (colori di base)
		cmp.w	#31,d0			;Se troppo grande, usa l'ultima tabella (massimo dell'oscurit o della nebbia)
		ble.s	MFWlitok
		lea	(31<<8)(a3),a3
		bra.s	MFWlitout
MFWlitok	lsl.l	#8,d0
		add.l	d0,a3
MFWlitout


		move.l	(a6),d6		;d6.h=Floor Height; d6.l=Ceil. Height
		move.l	(a1),d7		;d7.h=Floor Height; d7.l=Ceil. Height
		cmp.w	d7,d6		;compare ceiling heights
		bne.s	MFWuppertexture
		move.w	bl_CeilTexture(a6),d1
		cmp.w	bl_CeilTexture(a1),d1
		bne.s	MFWuppertexture
		move.w	bl_Illumination(a6),d1
		cmp.w	bl_Illumination(a1),d1
		beq	MFWnoceil

;*** Draw upper texture
MFWuppertexture
		move.w	PlayerY(a5),d0
		sub.w	d0,d6
		neg.w	d6
		move.l	d6,d1			;conserva in d1 per calcolo dimensioni muro
		swap	d6
		clr.w	d6
		divs.l	d2,d6			;d6=yl=posizione y a video del punto piu' basso
		move.l	d6,Tempd7(a5)		;Memorizza per un eventuale uso da parte della normal texture

		sub.w	d0,d7
		neg.w	d7
		sub.l	d7,d1			;d1=Dim.wall
		swap	d7
		clr.w	d7
		divs.l	d2,d7			;d7=yh=posizione y a video del punto piu' alto

		sub.l	d7,d6			;d6=num. pixel=ABS(yl - yh)
		bgt	MFWUnpok
		add.l	window_height2(a5),d7
		add.l	LookHeight(a5),d7
		FillCeiling
;		move.l	d7,d3
		bra	MFWtestfloor
MFWUnpok	add.l	window_height2(a5),d7
		add.l	LookHeight(a5),d7

		StretchUpperTexture
		move.l	-8(a2),d2	;d2=distance






MFWtestfloor	move.l	(sp),a1		;recupera pun. blocco precedente
		move.l	(a6),d6		;d6.h=Floor Height; d6.l=Ceil. Height
		move.l	(a1),d7		;d7.h=Floor Height; d7.l=Ceil. Height
MFWnoceil	swap	d7
		swap	d6
		cmp.w	d7,d6
		bne.s	MFWlowertexture
		move.w	bl_FloorTexture(a6),d1
		cmp.w	bl_FloorTexture(a1),d1
		bne.s	MFWlowertexture
		move.w	bl_Illumination(a6),d1
		cmp.w	bl_Illumination(a1),d1
		beq	MFWnofloor

;*** Draw lower texture
MFWlowertexture
		exg	d6,d7
		move.w	PlayerY(a5),d0
		sub.w	d0,d6
		neg.w	d6
		move.l	d6,d1			;conserva in d1 per calcolo dimensioni muro
		swap	d6
		clr.w	d6
		divs.l	d2,d6			;d6=yl=posizione y a video del punto piu' basso

		sub.w	d0,d7
		neg.w	d7
		sub.l	d7,d1			;d1=Dim.wall
		swap	d7
		clr.w	d7
		divs.l	d2,d7			;d7=yh=posizione y a video del punto piu' alto
		move.l	d7,Tempd6(a5)		;Memorizza per un eventuale uso da parte della normal texture

		sub.l	d7,d6			;d6=num. pixel=ABS(yl - yh)
		bgt.s	MFWLnpok
		add.l	window_height2(a5),d7
		add.l	LookHeight(a5),d7
		add.l	d6,d7
		FillFloor
;		move.l	d7,d4
		bra	MFWnofloor
MFWLnpok	add.l	window_height2(a5),d7
		add.l	LookHeight(a5),d7

		StretchLowerTexture
		move.l	-8(a2),d2	;d2=distance




MFWnofloor
		move.l	4(a2),a0		;a0=pun. edge
		move.l	ed_NormTexture(a0),d1	;d1=pun. brush
		beq	MFWloopc

MFWnormtexture
		move.l	d1,a0

		move.w	bl_CeilHeight(a6),d1
		sub.w	bl_FloorHeight(a6),d1	;d1=dim. wall
		move.l	Tempd6(a5),d6		;d6=yl=posizione y a video del punto piu' basso
		move.l	Tempd7(a5),d7		;d7=yh=posizione y a video del punto piu' alto

		sub.l	d7,d6			;d6=num. pixel=ABS(yl - yh)
		ble	MFWnonormtex
		add.l	window_height2(a5),d7
		add.l	LookHeight(a5),d7

		StretchNormalTexture
MFWnonormtex
		subq.l	#8,a2
		bra.s	MFWntj

MFWnext
		move.w	d4,4(a2)	;Salva clipymax per il clipping degli oggetti
		move.w	d3,6(a2)	;Salva clipymin per il clipping degli oggetti
MFWntj
		move.l	ObjVTablePun(a5),a0
		move.l	a2,(a0)+		;Salva pun. alla coda della lista
		move.l	a0,ObjVTablePun(a5)

		move.l	4(sp),a2
		add.l	#vtsize*MAX_BLOCK_VIEW,a2
		move.l	a2,4(sp)

		addq.l	#1,ChunkyPointer(a5)

		move.w	currentx(a5),d7
		move.w	d7,currentx1(a5)
		addq.w	#1,d7
		move.w	d7,currentx(a5)
;		move.w	d7,currentx+2(a5)
		cmp.w	window_width+2(a5),d7
		blt	MFWloopx

		addq.w	#8,sp


	;***** Aggiusta ultimi trattini di ogni riga

		lea	OTablePun(pc),a0
		move.w	window_height2+2(a5),d7
		subq.w	#1,d7
Oadjloop	move.l	(a0)+,d0	;d0=caratteristiche dell'ultimo trattino della riga
		move.l	800-4(a0),a1	;a1=pun. all'ultimo trattino della riga
		move.l	d0,(a1)		;Scrive caratteristiche
		move.l	(a0)+,d0	;d0=caratteristiche dell'ultimo trattino della riga
		move.l	800-4(a0),a1	;a1=pun. all'ultimo trattino della riga
		move.l	d0,(a1)		;Scrive caratteristiche
		dbra	d7,Oadjloop



;		tst.w	CeilingType(a5)
;		beq.s	MakeTextCeiling
;		bsr	MakeCeiling
;		bra	TestFloorType

	;***** Make Textured Ceiling
MakeTextCeiling
		lea	OTablePun+800(pc),a0
		lea	RayDirTab(a5),a2
		move.l	ChunkyBuffer(a5),ChunkyPointer(a5)	;Init pun. fake chunky
		move.l	window_height2(a5),d7
		add.l	LookHeight(a5),d7
		ble	MTFnoceil
		move.l	d7,d6
		cmp.l	window_height(a5),d6
		ble.s	MTChok
		move.l	window_height(a5),d6
MTChok		move.l	d6,-(sp)
		neg.l	d7
		move.l	d7,-(sp)		;Mette nello stack, il contatore delle righe
		move.l	#$fc00000,d6
		move.l	#$3fffff,d7

MTCloopy	move.l	(a0)+,a1		;a1=Pun. alle strutture della riga
MTCloopx	move.w	(a1)+,d6		;d6=x2
;		bmi	MTCnexty
		clr.l	d4
		move.w	(a1)+,d4		;d4=Block number
		move.w	(a1)+,d1		;d1=x1
	tst.w	d6
	bmi	MTCnexty
		sub.w	d1,d6			;d6=num. pixel - 1

		move.l	Blocks(a5),a3
		lsl.l	#5,d4
		add.l	d4,a3			;a3=Block pointer
		move.w	bl_CeilTexture(a3),d0	;d0=Texture number
		move.w	bl_CeilHeight(a3),d4	;d4=Height

		move.l	Textures(a5),a6
		move.l	(a6,d0.w*4),a6
		move.l	4(a6),a6		;a6=Pun.texture

		move.l	ChunkyPointer(a5),a4
		add.w	d1,a4			;a4=pun. screen chunky

		swap	d4
		clr.w	d4
		sub.l	PlayerY(a5),d4
		divs.l	(sp),d4		;d4=T

		move.l	8(a2,d1.w*8),d2
		FIXMUL	d4,d5,d2,d0,d1,d3,d6,d7
		;d2=U2

		move.l	12(a2,d1.w*8),d3
		FIXMUL	d4,d5,d3,d0,d1,d2,d6,d7
		;d3=V2

		move.l	(a2,d1.w*8),d0
		FIXMUL	d4,d5,d0,d1,d2,d3,d6,d7
		;d0=U1

		move.l	4(a2,d1.w*8),d1
		FIXMUL	d4,d5,d1,d0,d2,d3,d6,d7
		;d1=V1


		sub.l	d0,d2		;d2=DU
		sub.l	d1,d3		;d3=DV
		sub.l	PlayerX(a5),d0	;d0=U1
		sub.l	PlayerZ(a5),d1	;d1=V1

		neg.l	d4
		add.l	d4,d4
		MULU64	windowYratio(a5),d5,d4,d0,d1,d2	;Aggiusta la distanza in base alle dimensioni della finestra
		move.b	bl_Illumination(a3),d4
		extb.l	d4
		add.l	d4,d5			;d5=Indice lighting table
		move.l	GlobalLight(a5),d4
		tst.b	bl_Illumination+1(a3)	;Test flag nebbia
		lea	LightingTable(a5),a3	;a3=Pun. alla lighting table
		bpl.s	MTCnofog		;Se non c' nebbia, salta
		lea	8192(a3),a3		;Se c' nebbia, passa alla lighting table per la nebbia
		moveq	#0,d4			;Azzera global light
MTCnofog	add.l	d4,d5			;Somma global light
		bmi.s	MTClitout		;Se negativo usa la prima tabella (colori di base)
		cmp.w	#31,d5			;Se troppo grande, usa l'ultima tabella (massimo dell'oscurit o della nebbia)
		ble.s	MTClitok
		lea	(31<<8)(a3),a3
		bra.s	MTClitout
MTClitok	lsl.l	#8,d5
		add.l	d5,a3
MTClitout

		lsl.l	#6,d1
		lsl.l	#6,d3
		clr.l	d4

                MTCINNERLOOP

		lea	-12(a1),a1
		bra	MTCloopx
MTCnexty
		move.l	source_width(a5),d0
		add.l	d0,ChunkyPointer(a5)
		addq.l	#1,(sp)
		subq.l	#1,4(sp)
		bgt	MTCloopy

		addq.w	#8,sp
MTFnoceil


TestFloorType
;		tst.w	FloorType(a5)
;		beq.s	MakeTextFloor
;		bsr	MakeFloor
;		rts

	;***** Make Textured Floor
MakeTextFloor
		move.l	window_height(a5),d0
		lea	OTablePun+800(pc),a0
		lea	(a0,d0.w*4),a0
		lea	RayDirTab(a5),a2

		move.l	window_height(a5),d0
		subq.l	#1,d0
		move.l	Yoffset.w(a5,d0.w*4),d0
		add.l	ChunkyBuffer(a5),d0
		move.l	d0,ChunkyPointer(a5)	;Init pun. fake chunky

		move.l	window_height2(a5),d7
		sub.l	LookHeight(a5),d7
		ble	MTFnofloor
		move.l	d7,d6
		cmp.l	window_height(a5),d6
		ble.s	MTFlp
		move.l	window_height(a5),d6
MTFlp		move.l	d6,-(sp)
		move.l	d7,-(sp)		;Mette nello stack, il contatore delle righe
		move.l	#$fc00000,d6
		move.l	#$3fffff,d7

MTFloopy	move.l	-(a0),a1		;a1=Pun. alle strutture della riga
MTFloopx	move.w	(a1)+,d6		;d6=x2
;		bmi	MTFnexty
		clr.l	d4
		move.w	(a1)+,d4		;d4=Block number
		move.w	(a1)+,d1		;d1=x1
	tst.w	d6
	bmi	MTFnexty
		sub.w	d1,d6			;d6=num. pixel - 1

		move.l	Blocks(a5),a3
		lsl.l	#5,d4
		add.l	d4,a3			;a3=Block pointer
		move.w	bl_FloorTexture(a3),d0	;d0=Texture number
		move.w	bl_FloorHeight(a3),d4	;d4=Height

		move.l	Textures(a5),a6
		move.l	(a6,d0.w*4),a6
		move.l	4(a6),a6		;a6=Pun.texture

		move.l	ChunkyPointer(a5),a4
		add.w	d1,a4			;a4=pun. screen chunky

		swap	d4
		clr.w	d4
		sub.l	PlayerY(a5),d4
		divs.l	(sp),d4		;d4=T

		move.l	8(a2,d1.w*8),d2
		FIXMUL	d4,d5,d2,d0,d1,d3,d6,d7
		;d2=U2

		move.l	12(a2,d1.w*8),d3
		FIXMUL	d4,d5,d3,d0,d1,d2,d6,d7
		;d3=V2

		move.l	(a2,d1.w*8),d0
		FIXMUL	d4,d5,d0,d1,d2,d3,d6,d7
		;d0=U1

		move.l	4(a2,d1.w*8),d1
		FIXMUL	d4,d5,d1,d0,d2,d3,d6,d7
		;d1=V1


		sub.l	d0,d2		;d2=DU
		sub.l	d1,d3		;d3=DV
		sub.l	PlayerX(a5),d0	;d0=U1
		sub.l	PlayerZ(a5),d1	;d1=V1

		neg.l	d4
		add.l	d4,d4
		MULU64	windowYratio(a5),d5,d4,d0,d1,d2	;Aggiusta la distanza in base alle dimensioni della finestra
		move.b	bl_Illumination(a3),d4
		extb.l	d4
		add.l	d4,d5			;d5=Indice lighting table
		move.l	GlobalLight(a5),d4
		tst.b	bl_Illumination+1(a3)	;Test flag nebbia
		lea	LightingTable(a5),a3	;a3=Pun. alla lighting table
		bpl.s	MTFnofog		;Se non c' nebbia, salta
		lea	8192(a3),a3		;Se c' nebbia, passa alla lighting table per la nebbia
		moveq	#0,d4			;Azzera global light
MTFnofog	add.l	d4,d5			;Somma global light
		bmi.s	MTFlitout		;Se negativo usa la prima tabella (colori di base)
		cmp.w	#31,d5			;Se troppo grande, usa l'ultima tabella (massimo dell'oscurit o della nebbia)
		ble.s	MTFlitok
		lea	(31<<8)(a3),a3
		bra.s	MTFlitout
MTFlitok	lsl.l	#8,d5
		add.l	d5,a3
MTFlitout

		lsl.l	#6,d1
		lsl.l	#6,d3
		clr.l	d4

                MTCINNERLOOP

		lea	-12(a1),a1
		bra	MTFloopx
MTFnexty
		move.l	source_width(a5),d0
		sub.l	d0,ChunkyPointer(a5)
		subq.l	#1,(sp)
		subq.l	#1,4(sp)
		bgt	MTFloopy

		addq.w	#8,sp
MTFnofloor

		rts



;*********************************************************************

;ClearScreen
;		move.l	ChunkyBuffer(a5),a0	;a0=pun. fake chunky
;		move.l	#$f7f7f7f7,d0		;d0=colore soffitto
;		move.l	#$f7f7f7f7,d1		;d1=colore pavimento
;;		move.l	#0,d0			;d0=colore soffitto
;;		move.l	#0,d1			;d1=colore pavimento
;		move.l	window_size(a5),d7
;		lsr.l	#5,d7
;		subq.w	#1,d7
;		move.w	d7,d6
;CSloop1		move.l	d0,(a0)+
;		move.l	d0,(a0)+
;		move.l	d0,(a0)+
;		move.l	d0,(a0)+
;		dbra	d7,CSloop1
;CSloop2		move.l	d1,(a0)+
;		move.l	d1,(a0)+
;		move.l	d1,(a0)+
;		move.l	d1,(a0)+
;		dbra	d6,CSloop2
;
;		rts

;*********************************************************************
;*** Non spostare OTablePun

		xdef	OTablePun

                DEVPAD

OTablePun	ds.l	WINDOW_MAX_HEIGHT<<1	;Lista di pun. a liste di trattini orizzontali


;*********************************************************************

		section	TABLES,BSS

		cnop	0,4

;Formato delle strutture della OTableList:
;
; x2		.W	x finale del trattino orizzontale
; block		.W	Numero del blocco
; x1		.W	x iniziale del trattino orizzontale

		xdef	OTableList

OTableList	ds.b	WINDOW_MAX_HEIGHT*6*32	;Memoria per 200 liste di 32 strutture ognuna. Ogni struttura e' di 8 byte. Ogni lista e' puntata dai puntatori di otable.

		cnop	0,4

;*********************************************************************

		xdef	ObjVTable

ObjVTable	ds.l	WINDOW_MAX_WIDTH+1	;Lista di max 320 puntatori alla vtable. Usata per il clipping degli oggetti.

;*********************************************************************

		section	__MERGED,BSS

		cnop	0,4


Tempd6		ds.l	1	;Usato per il tracciamento delle normal texture
Tempd7		ds.l	1	;Usato per il tracciamento delle normal texture

ObjVTablePun	ds.l	1

		xdef	GlobalLight

GlobalLight	ds.l	1	;Valore di illuminazione globale

		xdef	LightingTable

LightingTable	ds.b	8192	;Lighting table
		ds.b	8192	;Lighting table fog

;		incbin	"LightingTable"
;		incbin	"LightingTableFog"

		cnop	0,4

currentx1	ds.l	1
currentx	ds.w	2

	xdef	LookHeight

LookHeight	ds.l	1	Altezza dello sguardo


	xdef	CeilingType,FloorType
CeilingType	ds.w	1	;0=Textured;  1=Non textured
FloorType	ds.w	1	;0=Textured;  1=Non textured
