;****************************************************************************
;*
;*	TMap.asm
;*
;*	Main program per un gioco di esplorazione di dungeon in
;*	texture mapping
;*
;*	Titolo :  Breathless
;*
;*
;* - Nuova custom copper list
;* - Eliminato supporto PicassoII
;* - Risolto problema overscan
;*
;****************************************************************************


	include 'System'
	include 'MulDiv64.i'
;	include 'Picasso/Picasso'
	include 'TMap.i'
        include 'graphics/gfxbase.i'

;	include	'misc/easystart.i'


;... Definizioni esterne


		xref	TMapMain
		xref	c2p8_init
		xref	IntuitionOff,IntuitionOn

		xref	ReadMainGLD,ReadTexturesDir,ReadObjectsDir
		xref	ReadSoundsDir,ReadGfxDir
		xref	CheckDisk

		xref	source_width
		xref	planes_bitmap1,planes_bitmap2,planes_bitmap3
		xref	window_width,window_height,window_size
		xref	pixel_type
		xref	rndseed
		xref	LastBSSdata

		xref	LoadPalette,Rnd

;* Inizio del programma ********************************

STACK_SIZE=16*1024-20 ; 8K seems to work, but let's play it safe

entry
		GETDBASE ; Let's get this out of the way (move.l ....,var is optimized to a5 relative so be careful)

                ; Clear small data BSS
                move.l  #__BSSBAS,a2
                move.l  #__BSSLEN,d0
		subq.w	#1,d0
clrbss		clr.l	(a2)+
		dbra	d0,clrbss

                move.l  $4.w,a6
                move.l  #ErrMsgOSVer,ErrorMessage(a5)
                cmp.w   #39,LIB_VERSION(a6) ; ChangeVPBitMap etc requires v39
                blo     .error
                sub.l   a2,a2           ; a2 = stack swap pointer
                sub.l   a3,a3           ; a3 = wb message

                move.l  ThisTask(a6),a4
                tst.l   pr_CLI(a4)
                bne     .notwb
                ; Get startup message
                lea     pr_MsgPort(a4),a0
                jsr     _LVOWaitPort(a6)
                lea     pr_MsgPort(a4),a0
                jsr     _LVOGetMsg(a6)
                move.l  d0,a3
.notwb:
                move.l  #STACK_SIZE+12,d0
                move.l  TC_SPUPPER(a4),d1
                sub.l   TC_SPLOWER(a4),d1
                cmp.l   d0,d1
                bhs     .stackok
                moveq   #1,d1
                move.l  #ErrMsgAlloc,ErrorMessage(a5)
                jsr     _LVOAllocMem(a6)
                tst.l   d0
                beq     .error
                move.l  d0,a0
                move.l  d0,a2
                add.l   #12,d0
                move.l  d0,(a0)
                add.l   #STACK_SIZE,d0
                move.l  d0,4(a0)
                move.l  d0,8(a0)
                jsr     _LVOStackSwap(a6)
.stackok:
                movem.l  a2/a3,-(sp)
                bsr     _start
                movem.l (sp)+,d2/a3
                move.l  $4.w,a6
                tst.l   d2
                beq     .nostackswap
                move.l  d2,a0
                jsr     _LVOStackSwap(a6)
                move.l  d2,a1
                move.l  #STACK_SIZE+12,d0
                jsr     _LVOFreeMem(a6)
.nostackswap:
                tst.l   a3
                beq     .out
                jsr     _LVOForbid(a6)
                move.l  a3,a1
                jsr     _LVOReplyMsg(a6)
.out:
                moveq   #0,d0
                rts
.error:
                bsr     ShowError
                moveq   #-1,d0
                rts

ShowError
		movem.l	d0-d7/a0-a6,-(sp)
                lea     IntuitionName(pc),a1
                move.l  $4.w,a6
                jsr     _LVOOldOpenLibrary(a6)
                tst.l   d0
                beq     .out
                move.l  d0,a6
                move.l  ErrorMessage(a5),a0
                moveq   #0,d1
                move.w  (a0)+,d1
                jsr     _LVODisplayAlert(a6)
                move.l  a6,a1
                move.l  $4.w,a6
                jsr     _LVOCloseLibrary(a6)
.out:
		movem.l	(sp)+,d0-d7/a0-a6
                rts

_start
		movem.l	d0-d7/a0-a6,-(sp)

                IFD     USEFPU
                ; Load some commonly used constants into registers
                fmove.s #$4F800000,fp6  ; 1<<32
                fmove.s #$37800000,fp7  ; 1/65536
                ENDC

                move.l  #ErrMsgGeneric,ErrorMessage(a5)

		move.l	4,execbase(a5)
;		move.l	sp,savesp(a5)

		clr.l	d0
		move.w	$dff006,d0
		mulu.l	#$4c27839,d0
		move.l	d0,rndseed(a5)

		EXECBASE
		sub.l	a1,a1
		CALLSYS	FindTask
		move.l	d0,myTask(a5)
		move.l	d0,a1
		move.l	pr_WindowPtr(a1),SaveWindowPtr(a5)
		move.l	#-1,pr_WindowPtr(a1)	;Inibisce requester di sistema
		moveq	#1,d0
;		CALLSYS	SetTaskPri

		moveq	#-1,d0
		move.l	d0,sigbit1(a5)
		move.l	d0,sigbit2(a5)

		OPENLIB	GraphicsName(pc),gfxbase
		OPENLIB	DosName(pc),dosbase
		OPENLIB	IntuitionName(pc),intuitionbase


                move.l  #ErrMsgAlloc,ErrorMessage(a5)
		ALLOCMEMORY #ie_SIZEOF,MEMF_PUBLIC|MEMF_CLEAR,myInputEvent
		ALLOCMEMORY #CHUNKY_SIZE,MEMF_CLEAR,FakeChunkyPun
		ALLOCMEMORY #MAPMEM_SIZE,MEMF_CLEAR,MapPun
		ALLOCMEMORY #GFX_SIZE,MEMF_CLEAR,GfxPun
		ALLOCMEMORY #MAPOBJECTS_SIZE,MEMF_CLEAR,Objects
		ALLOCMEMORY #CHUNKY_SIZE,MEMF_CHIP|MEMF_CLEAR,c2pBuffer1
		ALLOCMEMORY #CHUNKY_SIZE,MEMF_CHIP|MEMF_CLEAR,c2pBuffer2
		ALLOCMEMORY #SOUNDS_SIZE,MEMF_CHIP|MEMF_CLEAR,SndPun
		ALLOCMEMORY #32,MEMF_CHIP|MEMF_CLEAR,nullbytes
		ALLOCMEMORY #ucl_SIZEOF,MEMF_PUBLIC|MEMF_CLEAR,myCopList1
		ALLOCMEMORY #ucl_SIZEOF,MEMF_PUBLIC|MEMF_CLEAR,myCopList2

		bsr	OpenAll		;Apre e inizializza tutte le risorse
		tst.l	d0		;Tutto ok ?
		bne	ErrorQuit

                move.l  #ErrMsgLoad,ErrorMessage(a5)

		jsr	CheckDisk	;Test se il caricamento avviene da floppy

		jsr	ReadMainGLD	;Legge Main GLD
		tst.b	d0
		bne.s	ErrorQuit

		jsr	ReadGfxDir	;Legge palettes e Gfx Dir
		tst.b	d0
		bne.s	ErrorQuit

;		jsr	ReadTexturesDir	;Legge Textures Dir
;		tst.b	d0
;		bne.s	ErrorQuit
;
;		jsr	ReadObjectsDir	;Legge Objects Dir
;		tst.b	d0
;		bne.s	ErrorQuit

		jsr	ReadSoundsDir	;Legge Sounds Dir
		tst.b	d0
		bne.s	ErrorQuit

                move.l  #ErrMsgUnknown,ErrorMessage(a5)

	;-----------------------------

		jsr	TMapMain

;		WAITDEBUG $a00,7

	;-----------------------------

		bsr	PrepareCleanup
		bsr	CleanupResources

		move.l	myTask(a5),a0
		move.l	SaveWindowPtr(a5),pr_WindowPtr(a0)

;		move.l	savesp(a5),sp
		movem.l	(sp)+,d0-d7/a0-a6
		rts



;********************************************************************

ErrorQuit
		bsr	CleanupResources
                bsr     ShowError
		movem.l	(sp)+,d0-d7/a0-a6
		rts

;********************************************************************

OpenAll

; Open output screen

		bsr	OpenAgaScreen
		tst.l	d0			; error?
		bne	OAerror
OAopenscrok
                move.l  #ErrMsgGeneric,ErrorMessage(a5)

		move.l	screen_bitmap1(a5),a0
		lea	bm_Planes(a0),a0
		move.l	a0,planes_bitmap1(a5)

		move.l	screen_bitmap2(a5),a0
		lea	bm_Planes(a0),a0
		move.l	a0,planes_bitmap2(a5)

		move.l	screen_bitmap3(a5),a0
		lea	bm_Planes(a0),a0
		move.l	a0,planes_bitmap3(a5)

		move.l	myDBufInfo(a5),a0
		move.l	#0,dbi_DispMessage+MN_REPLYPORT(a0)

; Get hardware sprites

			;*** Alloca sprite mouse pointer
		GFXBASE
		move.l	screen_bitmap1(a5),a2
		lea	spritetaglist0,a1
		CALLSYS	AllocSpriteDataA	;Alloca memoria per lo sprite
		move.l	d0,Sprites(a5)
		beq	OAerror

		bsr	TurnOffMousePointer



			;*** Alloca sprites per sprite screen
		GFXBASE
		lea	Sprites(a5),a3
		moveq	#8,d6			;Posizione x degli sprite
		moveq	#6,d7
OAspritesloop1	move.l	screen_bitmap1(a5),a2
		lea	spritetaglist1,a1
		CALLSYS	AllocSpriteDataA	;Alloca memoria per lo sprite
		move.l	d0,(a3,d7.w*4)
		beq	OAerror
		move.l	d0,a2
		lea	spritetaglist3,a1
		move.l	d7,4(a1)
		CALLSYS	GetExtSpriteA		;Tenta di allocare lo sprite
		tst.w	d0			;C'e' riuscito ?
		bmi	OAerror
		move.l	screen_viewport(a5),a0
		move.l	a2,a1		;SimpleSprite pointer
		move.l	d6,d0		;x
		moveq	#0,d1		;y
		CALLSYS	MoveSprite

		add.w	#64,d6
		addq.w	#1,d7
		cmp.w	#7,d7
		ble.s	OAspritesloop1

			;*** Alloca sprite a 16 colori per mirino
		GFXBASE
		lea	Sprites(a5),a3
		moveq	#4,d7
OAspritesloop2	move.l	screen_bitmap1(a5),a2
		lea	spritetaglist2,a1
		CALLSYS	AllocSpriteDataA	;Alloca memoria per lo sprite
		move.l	d0,(a3,d7.w*4)
		beq	OAerror
		move.l	d0,a2
		lea	spritetaglist3,a1
		move.l	d7,4(a1)
		CALLSYS	GetExtSpriteA		;Tenta di allocare lo sprite
		tst.w	d0			;C'e' riuscito ?
		bmi	OAerror
		move.l	screen_viewport(a5),a0
		move.l	a2,a1		;SimpleSprite pointer
		move.l	#128,d0		;x
		moveq	#96,d1		;y
		CALLSYS	MoveSprite

		addq.w	#1,d7
		cmp.w	#5,d7
		ble.s	OAspritesloop2
				;*** Setta i bit per lo sprite attached
		move.l	(5<<2)(a3),a0
		move.l	(a0),a0
		bset	#7,3(a0)
		bset	#7,5(a0)
		bset	#7,9(a0)


			;*** Alloca null-sprite
		GFXBASE
		lea	Sprites(a5),a3
		lea	NullSprites(a5),a4
		moveq	#7,d7
OAspritesloop3	tst.l	(a3)+
		beq.s	OAsprnext
		move.l	screen_bitmap1(a5),a2
		lea	spritetaglist0,a1
		CALLSYS	AllocSpriteDataA	;Alloca memoria per lo sprite
		move.l	d0,(a4)
		beq	OAerror
OAsprnext	addq.w	#4,a4
		dbra	d7,OAspritesloop3


    IFEQ 1	;*** !!!PROTEZIONE!!!
; Calcola riga e colonna per il primo codice di sicurezza

		xref	SecCodeRow,SecCodeCol

		lea	SecCodeRow-$228(a5),a1
		moveq	#36,d1
		jsr	Rnd
		addq.w	#1,d0
		move.w	d0,a0
		move.l	a0,$228(a1)		;SecCodeRow
		moveq	#10,d1
		jsr	Rnd
		add.w	#65,d0
		move.w	d0,a0
		move.l	a0,$228+4(a1)		;SecCodeCol
    ENDIF	;*** !!!FINE PROTEZIONE!!!



; Open timer device

		lea	timername(pc),a0		; device name
		moveq	#0,d0				; unit #
		lea	TimerIO(a5),a1			; iorequest
		moveq	#0,d1				; flags
		EXECBASE
		CALLSYS	OpenDevice
		tst.l	d0				; error?
		bne	OAerror

		lea	NewEClock(a5),a0
		move.l	TimerIO+IO_DEVICE(a5),a6	; get library pointer
		CALLSYS	ReadEClock			; now, NewEClock=64 bit value
		move.l	#(1000000>>16),d2
		move.l	#(1000000<<16),d1
		divu.l	d0,d2:d1				;d1=micros per eclock
		move.l	d1,MicrosPerEClock(a5)


; Add input handler

		move.l	TMapScreen(a5),-(sp)
		move.l	intuitionbase(a5),-(sp)
		pea	KeyQueueIndex2
		jsr	IntuitionOff
		lea	12(sp),sp
		tst.l	d0
		bne	OAerror


; Allocate audio channels

		EXECBASE
		CALLSYS	CreateMsgPort
		move.l	d0,AudioPort(a5)
		beq	OAerror

		lea	AudioIO(a5),a0
		move.l	d0,MN_REPLYPORT(a0)
		move.b	#127,LN_PRI(a0)
		move.w	#ADCMD_ALLOCATE,IO_COMMAND(a0)
		move.b	#ADIOF_NOWAIT,IO_FLAGS(a0)
		move.w	#0,ioa_AllocKey(a0)
		move.l	#ChannelMask,ioa_Data(a0)
		moveq	#1,d1
		move.l	d1,ioa_Length(a0)

		lea	audioname(pc),a0		; device name
		moveq	#0,d0				; unit #
		lea	AudioIO(a5),a1			; iorequest
		moveq	#0,d1				; flags
		EXECBASE
		CALLSYS	OpenDevice
		tst.l	d0				; error?
		bne	OAerror


		moveq	#0,d0
		rts
OAerror
		moveq	#1,d0
		rts

;****************************************************************************
;* Alloca sprite del puntatore del mouse e lo rende invisibile
;* Richiede GFXBASE in a6

		xdef	TurnOffMousePointer
TurnOffMousePointer
;		st	ResetMousePos(a5)	;Segnala di riposizionare il mouse

;		CALLSYS	WaitTOF
;		CALLSYS	WaitTOF
;		CALLSYS	WaitTOF
;		CALLSYS	WaitTOF

		moveq	#0,d0
		CALLSYS	FreeSprite

		move.l	Sprites(a5),a2
		lea	spritetaglist3,a1
		clr.l	4(a1)
		CALLSYS	GetExtSpriteA		;Tenta di allocare lo sprite

		rts

;********************************************************************

OpenAgaScreen
                move.l  #ErrMsgAGA,ErrorMessage(a5)
                move.l  #SETCHIPREV_AA,d0
                move.l  d0,d2
                GFXBASE
                CALLSYS SetChipRev
                and.l   d2,d0
                cmp.l   d2,d0
                bne     OAGAerror

                move.l  #ErrMsgScreen,ErrorMessage(a5)
		INTUITIONBASE
		CALLSYS	ViewAddress
		move.l	d0,IntuitionView(a5)


; Work out right horizontal screen position

		; Open useful screen.
		sub.l	a0,a0
		lea	usescreentaglist(pc),a1
		INTUITIONBASE
		CALLSYS	OpenScreenTagList
		move.l	d0,d7
		beq	OAGAerror

		GFXBASE
		CALLSYS	WaitTOF
		CALLSYS	WaitTOF

		move.l	IntuitionView(a5),a0
		move.w	#$81,d0
		sub.w	v_DxOffset(a0),d0
		ext.l	d0
		move.l	d0,screentaglist+4

		CALLSYS	WaitTOF
		CALLSYS	WaitTOF

		move.l	d7,a0
		INTUITIONBASE
		CALLSYS	CloseScreen



; now, we must allocate 3 bitmap for the main triple buffered screen
		GFXBASE
		move.l	#SCREEN_WIDTH,d0
		move.l	#SCREEN_HEIGHT+1,d1
		move.l	#SCREEN_DEPTH,d2
		move.l	#BMF_DISPLAYABLE|BMF_CLEAR,d3
		sub.l	a0,a0
		CALLSYS	AllocBitMap
		move.l	d0,bm_tag+4
		move.l	d0,screen_bitmap1(a5)
		beq	OAGAerror

		move.l	#SCREEN_WIDTH,d0
		move.l	#SCREEN_HEIGHT-PANEL_HEIGHT,d1
		move.l	#SCREEN_DEPTH,d2
		move.l	#BMF_DISPLAYABLE|BMF_CLEAR,d3
		sub.l	a0,a0
		CALLSYS	AllocBitMap
		move.l	d0,screen_bitmap2(a5)
		beq	OAGAerror

		move.l	#SCREEN_WIDTH,d0
		move.l	#SCREEN_HEIGHT-PANEL_HEIGHT,d1
		move.l	#SCREEN_DEPTH,d2
		move.l	#BMF_DISPLAYABLE|BMF_CLEAR,d3
		sub.l	a0,a0
		CALLSYS	AllocBitMap
		move.l	d0,screen_bitmap3(a5)
		beq	OAGAerror

; test interleaved state
		move.l	screen_bitmap1(a5),a0	; a0=bitmap
		move.l	#BMA_FLAGS,d1		; get bitmap flags
		CALLSYS	GetBitMapAttr		; test interleaved state
		btst	#BMB_INTERLEAVED,d0	; is interleaved?
		bne	OAGAerror		; bomb out if interleaved

		move.l	screen_bitmap2(a5),a0	; a0=bitmap
		move.l	#BMA_FLAGS,d1		; get bitmap flags
		CALLSYS	GetBitMapAttr		; test interleaved state
		btst	#BMB_INTERLEAVED,d0	; is interleaved?
		bne	OAGAerror		; bomb out if interleaved

		move.l	screen_bitmap3(a5),a0	; a0=bitmap
		move.l	#BMA_FLAGS,d1		; get bitmap flags
		CALLSYS	GetBitMapAttr		; test interleaved state
		btst	#BMB_INTERLEAVED,d0	; is interleaved?
		bne	OAGAerror		; bomb out if interleaved

; now, initialize a rastport for drawing into the canvas bitmap
		lea	screen_rport(a5),a1
		CALLSYS	InitRastPort
		move.l	screen_bitmap1(a5),screen_rport+rp_BitMap(a5)


; Calculate panel bitplane pointers

		lea	PanelBitplanes(a5),a1
		move.l	screen_bitmap1(a5),a0
		lea	bm_Planes(a0),a0

		moveq	#7,d7
PanelPtrLoop	move.l	(a0)+,d0
		add.l	#8000,d0
		move.l	d0,(a1)+
		dbra	d7,PanelPtrLoop



; Open screen.
		sub.l	a0,a0			; no NewScreen structure, just tags
		lea	screentaglist(pc),a1	; screen attributes
		INTUITIONBASE
		CALLSYS	OpenScreenTagList
		move.l	d0,TMapScreen(a5)
		beq	OAGAerror


; Get ViewPort pointer

		move.l	TMapScreen(a5),a0
		lea	sc_ViewPort(a0),a1
		move.l	a1,screen_viewport(a5)

; Set video and sprites type

		GFXBASE
		move.l	screen_viewport(a5),a3
		move.l	vp_ColorMap(a3),a0
		lea	vctags(pc),a1
		CALLSYS	VideoControl

		GFXBASE
		CALLSYS	WaitTOF
		CALLSYS	WaitTOF

;		move.l	IntuitionView(a5),a0
;		move.l	screen_viewport(a5),a1
;		CALLSYS	MakeVPort
;		move.l	IntuitionView(a5),a1
;		CALLSYS	MrgCop

; Double pixel height with a custom copper list

		bsr	CustomCopList

; Setup copper and load view

		move.l	IntuitionView(a5),a4
		move.l	a4,a0
		move.l	screen_viewport(a5),a1
		CALLSYS	MakeVPort
		move.l	a4,a1
		CALLSYS	MrgCop
		move.l	a4,a1
		CALLSYS	LoadView

		GFXBASE
		CALLSYS	WaitTOF
		CALLSYS	WaitTOF

; Set 256 colors Palette

		move.l	screen_viewport(a5),a0
		lea	PaletteRGB32,a1
		GFXBASE
		CALLSYS	LoadRGB32

; Get signals for chunky to planar conversion

		jsr	Get_Signals
		tst.l	d0
		bne	OAGAerror

; Create MsgPort for double buffering

		EXECBASE
		CALLSYS	CreateMsgPort
		move.l	d0,DBufSafePort(a5)
		beq	OAGAerror

		EXECBASE
		CALLSYS	CreateMsgPort
		move.l	d0,DBufDispPort(a5)
		beq	OAGAerror

; Allocate DBufInfo structure

		GFXBASE
		move.l	screen_viewport(a5),a0
		CALLSYS	AllocDBufInfo
		move.l	d0,myDBufInfo(a5)
		beq	OAGAerror

		move.l	d0,a0
		move.l	DBufSafePort(a5),dbi_SafeMessage+MN_REPLYPORT(a0)
		move.l	DBufDispPort(a5),dbi_DispMessage+MN_REPLYPORT(a0)

; Init chunky to planar conversion

		move.l	FakeChunkyPun(a5),a0	;a0=pun. to chunky
		move.l	pixel_type(a5),a1	;a1=conversion mode
		move.l	sigbit1(a5),d2
		moveq	#1,d0
		lsl.l	d2,d0			;d0=1 << sigbit1
		move.l	sigbit2(a5),d2
		moveq	#1,d1
		lsl.l	d2,d1			;d1=1 << sigbit2
		move.l	window_width(a5),d2	;d2=width
		move.l	window_height(a5),d3	;d3=height
		move.l	#0,d4			;d4=byte offset
		move.l	c2pBuffer1(a5),d5	;d5=pun. to buffer1
		move.l	c2pBuffer2(a5),d6	;d6=pun. to buffer2
		move.l	#SCREEN_WIDTH,d7		;d7=screen width
		move.l	gfxbase(a5),a3		;a3=GfxBase
		jsr	c2p8_init


		move.l	FakeChunkyPun(a5),ChunkyBuffer(a5)
		move.l	window_width(a5),source_width(a5)

		moveq	#0,d0
		rts
OAGAerror
		moveq	#1,d0
		rts

;********************************************************************
; Crea custom copper list

CustomCopList

	;*** Copper list per normal pixel height

		GFXBASE
		move.l	myCopList1(a5),a0
		move.l	a0,a2
		move.l	#640,d0
		CALLSYS	UCopperListInit

		moveq	#0,d6
		move.l	#99,d7
CCLloop0	CWAIT	a2,d6,#8
		CMOVE	a2,#$108,#$fff8
		CMOVE	a2,#$10a,#$fff8
		addq.w	#1,d6
		CWAIT	a2,d6,#8
		CMOVE	a2,#$108,#$fff8
		CMOVE	a2,#$10a,#$fff8
		addq.w	#1,d6
		dbra	d7,CCLloop0

		CWAIT	a2,d6,#8
		CMOVE	a2,#$108,#$fff8
		CMOVE	a2,#$10a,#$fff8

;		CWAIT	a2,#200,#8
		CMOVE	a2,#$100,#$0201	;Disabilita display

		lea	PanelBitplanes(a5),a3
		moveq	#7,d7
		move.l	#$e0,d2
CCLloop1	move.l	(a3)+,d4
		move.l	d4,d3
		clr.w	d3
		swap	d3
		CMOVE	a2,d2,d3	;Parte alta del pun. al bitplane
		addq.l	#2,d2
		swap	d4
		clr.w	d4
		swap	d4
		CMOVE	a2,d2,d4	;Parte bassa del pun. al bitplane
		addq.l	#2,d2
		dbra	d7,CCLloop1

		CWAIT	a2,#201,#8
		CMOVE	a2,#$100,#$0211	;Abilita display

		CEND	a2


	;*** Copper list per Double pixel height

		GFXBASE
		move.l	myCopList2(a5),a0
		move.l	a0,a2
		move.l	#640,d0
		CALLSYS	UCopperListInit

		moveq	#0,d6
		move.l	#99,d7
CCLloop2	CWAIT	a2,d6,#8
		CMOVE	a2,#$108,#$ffd0
		CMOVE	a2,#$10a,#$ffd0
		addq.w	#1,d6
		CWAIT	a2,d6,#8
		CMOVE	a2,#$108,#$20
		CMOVE	a2,#$10a,#$20
		addq.w	#1,d6
		dbra	d7,CCLloop2

		CWAIT	a2,d6,#8
		CMOVE	a2,#$108,#$fff8
		CMOVE	a2,#$10a,#$fff8


		CMOVE	a2,#$100,#$0201	;Disabilita display

		lea	PanelBitplanes(a5),a3
		moveq	#7,d7
		move.l	#$e0,d2
CCLloop3	move.l	(a3)+,d4
		move.l	d4,d3
		clr.w	d3
		swap	d3
		CMOVE	a2,d2,d3	;Parte alta del pun. al bitplane
		addq.l	#2,d2
		swap	d4
		clr.w	d4
		swap	d4
		CMOVE	a2,d2,d4	;Parte bassa del pun. al bitplane
		addq.l	#2,d2
		dbra	d7,CCLloop3

		CWAIT	a2,#201,#8
		CMOVE	a2,#$100,#$0211	;Abilita display

		CEND	a2


	;*** Installa custom copper list

;		move.l	screen_viewport(a5),a3
;
;		EXECBASE
;		CALLSYS	Forbid
;
;		move.l	myCopList1(a5),a2
;
;		move.l	pixel_type(a5),d0	;Test height of the pixel
;		btst	#1,d0
;		beq	CCLnodoub
;
;		move.l	myCopList2(a5),a2
;
;CCLnodoub	move.l	a2,vp_UCopIns(a3)
;
;		CALLSYS	Permit

		GFXBASE
		move.l	vp_ColorMap(a3),a0
		lea	uCopTags(pc),a1
		CALLSYS	VideoControl

CCLout
		rts

;********************************************************************

Get_Signals
		EXECBASE
		moveq	#-1,d0
		CALLSYS	AllocSignal	;Try to allocate sigbit1
		move.l	d0,sigbit1(a5)
		bmi	GSno
		moveq	#1,d1
		lsl.l	d0,d1	;d1=1 << sigbit1
		move.l	d1,d0
		CALLSYS	SetSignal

		moveq	#-1,d0
		CALLSYS	AllocSignal	;Try to allocate sigbit2
		move.l	d0,sigbit2(a5)
		bmi	GSno
		moveq	#1,d1
		lsl.l	d0,d1	;d1=1 << sigbit2
		move.l	d1,d0
		CALLSYS	SetSignal

		moveq	#0,d0		;Ok
		rts

GSno		moveq	#1,d0		;Problems
		rts



;********************************************************************

Free_Signals
		EXECBASE
		move.l	sigbit1(a5),d1
		bmi.s	FSno1
		moveq	#1,d0
		lsl.l	d1,d0
		CALLSYS	Wait
		move.l	sigbit1(a5),d0
		CALLSYS	FreeSignal
		moveq	#-1,d0
		move.l	d0,sigbit1(a5)
FSno1
		move.l	sigbit2(a5),d1
		bmi.s	FSno2
		moveq	#1,d0
		lsl.l	d1,d0
		CALLSYS	Wait
		move.l	sigbit2(a5),d0
		CALLSYS	FreeSignal
		moveq	#-1,d0
		move.l	d0,sigbit2(a5)
FSno2
		rts

;********************************************************************
; return d0=elapsed time in int.frac format
; trashes: a0/a1/d1-d4

	xdef	GetTime
GetTime
		lea	NewEClock(a5),a0
		move.l	TimerIO+IO_DEVICE(a5),a6	; get library pointer
		CALLSYS	ReadEClock			; now, NewEClock=64 bit value
		movem.l	LastEClock(a5),d1/d2/d3/d4	; d1/d2=old d3/d4=new
		movem.l	d3/d4,LastEClock(a5)
		tst.w	first_timer(a5)
		bne.s	second_time
		st	first_timer(a5)
		moveq	#0,d0
		rts
second_time:
		sub.l	d2,d4
		subx.l	d1,d3			; d3 now=elapsed time
		MULU64	MicrosPerEClock(a5),d3,d4,d0,d1,d2
		move.w	d3,d4
		swap	d4
		move.l	d4,d0

;		lsl.l	#3,d0
;		clr.w	d0
;		swap	d0			; d0=#ticks in (1/32768s)
;		divu.l	d0,d3:d4
;		move.l	d4,d0
		rts

;********************************************************************

CleanupResources

		EXECBASE

;		FREEMEMORY ObjectsDirPun,ObjectsDirLen(a5)
;		FREEMEMORY TexturesDirPun,TexturesDirLen(a5)
;		FREEMEMORY SoundsDirPun,SoundsDirLen(a5)
;		FREEMEMORY GfxDirPun,GfxDirLen(a5)
;		FREEMEMORY LevelsDirPun,LevelsDirLen(a5)
;		FREEMEMORY nullbytes,#32
;		FREEMEMORY SndPun,#SOUNDS_SIZE
;		FREEMEMORY c2pBuffer2,#CHUNKY_SIZE
;		FREEMEMORY c2pBuffer1,#CHUNKY_SIZE
;		FREEMEMORY Objects,#MAPOBJECTS_SIZE
;		FREEMEMORY GfxPun,#GFX_SIZE
;		FREEMEMORY MapPun,#MAPMEM_SIZE
;		FREEMEMORY FakeChunkyPun,#CHUNKY_SIZE
;		FREEMEMORY myInputEvent,#ie_SIZEOF


		tst.l	AudioIO+IO_DEVICE(a5)
		beq.s	CRnoaudiodevice
		lea	AudioIO(a5),a1
		EXECBASE
		CALLSYS	CloseDevice
CRnoaudiodevice

		move.l	AudioPort(a5),d0
		beq.s	CRnoaudioport
		move.l	d0,a0
		EXECBASE
		CALLSYS	DeleteMsgPort
CRnoaudioport


		tst.l	TimerIO+IO_DEVICE(a5)	; timer open ?
		beq.s	CRnotimer
		lea	TimerIO(a5),a1
		EXECBASE
		CALLSYS	CloseDevice
CRnotimer

; Free sprites

		GFXBASE
		lea	Sprites(a5),a3
		moveq	#7,d7
CRspritesloop	move.l	(a3)+,d0
		beq.s	CRspritenext
		move.l	d0,a2
		move.w	ss_num(a2),d0
		ext.l	d0
		CALLSYS	FreeSprite
		CALLSYS	FreeSpriteData
CRspritenext	dbra	d7,CRspritesloop


; Free null-sprite

		GFXBASE
		lea	NullSprites(a5),a3
		moveq	#7,d7
CRnspritesloop	move.l	(a3)+,d0
		beq.s	CRnspritenext
		move.l	d0,a2
		CALLSYS	FreeSpriteData
CRnspritenext	dbra	d7,CRnspritesloop


; Close output screen

		bsr	CloseAgaScreen

		jsr	IntuitionOn

		DOSBASE
		moveq	#100,d1
		CALLSYS	Delay

		EXECBASE
		FREEMEMORY ObjectsDirPun,ObjectsDirLen(a5)
		FREEMEMORY TexturesDirPun,TexturesDirLen(a5)
		FREEMEMORY SoundsDirPun,SoundsDirLen(a5)
		FREEMEMORY GfxDirPun,GfxDirLen(a5)
		FREEMEMORY LevelsDirPun,LevelsDirLen(a5)
		FREEMEMORY nullbytes,#32
		FREEMEMORY SndPun,#SOUNDS_SIZE
		FREEMEMORY c2pBuffer2,#CHUNKY_SIZE
		FREEMEMORY c2pBuffer1,#CHUNKY_SIZE
		FREEMEMORY Objects,#MAPOBJECTS_SIZE
		FREEMEMORY GfxPun,#GFX_SIZE
		FREEMEMORY MapPun,#MAPMEM_SIZE
		FREEMEMORY FakeChunkyPun,#CHUNKY_SIZE
		FREEMEMORY myInputEvent,#ie_SIZEOF


		CLOSELIB intuitionbase
		CLOSELIB dosbase
		CLOSELIB gfxbase

		rts


;***************************************************************************

CloseAgaScreen

	;* Installa user copper list 1 e libera la memoria da essa allocata

		move.l	screen_viewport(a5),d0
		beq.s	CASnovport
		move.l	d0,a3
		EXECBASE
		CALLSYS	Forbid
		move.l	myCopList1(a5),vp_UCopIns(a3)
		CALLSYS	Permit
		INTUITIONBASE
		CALLSYS	RethinkDisplay

		move.l	screen_viewport(a5),a0
		GFXBASE
		CALLSYS	FreeVPortCopLists

	;* Installa user copper list 2 e libera la memoria da essa allocata

		move.l	screen_viewport(a5),a3
		EXECBASE
		CALLSYS	Forbid
		move.l	myCopList2(a5),vp_UCopIns(a3)
		CALLSYS	Permit
		INTUITIONBASE
		CALLSYS	RethinkDisplay

		move.l	screen_viewport(a5),a0
		GFXBASE
		CALLSYS	FreeVPortCopLists


CASnovport	move.l	TMapScreen(a5),d0
		beq.s	CASnoscreen
		move.l	d0,a0
		INTUITIONBASE
		CALLSYS	CloseScreen
		clr.l	TMapScreen(a5)
CASnoscreen
		move.l	screen_bitmap1(a5),d0
		beq.s	CASnobitmap1
		move.l	d0,a0
		GFXBASE
		CALLSYS	FreeBitMap
CASnobitmap1
		move.l	screen_bitmap2(a5),d0
		beq.s	CASnobitmap2
		move.l	d0,a0
		GFXBASE
		CALLSYS	FreeBitMap
CASnobitmap2
		move.l	screen_bitmap3(a5),d0
		beq.s	CASnobitmap3
		move.l	d0,a0
		GFXBASE
		CALLSYS	FreeBitMap
CASnobitmap3

		move.l	myDBufInfo(a5),d0
		beq.s	CASnodbufinfo
		move.l	d0,a1
		GFXBASE
		CALLSYS	FreeDBufInfo
CASnodbufinfo

		move.l	DBufSafePort(a5),d0
		beq.s	CASnosafeport
		move.l	d0,a0
		EXECBASE
		CALLSYS	DeleteMsgPort
CASnosafeport
		move.l	DBufDispPort(a5),d0
		beq.s	CASnodispport
		move.l	d0,a0
		EXECBASE
		CALLSYS	DeleteMsgPort
CASnodispport

		jsr	Free_Signals

		rts

;***************************************************************************
; Resetta dati e strutture varie per prepararsi alla deallocazione

PrepareCleanup:

;		tst.l	ScrOutputType(a5)	;Test screen output type
;		bne.s	PCout			;Se non ? AGA, esce
;
; Reset 256 colors palette
;
;		lea	PaletteRGB32+4(pc),a0
;		move.w	#255,d7
;PCloopP		clr.l	(a0)+
;		dbra	d7,PCloopP
;
;		move.l	screen_viewport(a5),a0
;		lea	PaletteRGB32(pc),a1
;		GFXBASE
;		CALLSYS	LoadRGB32
;
;		CALLSYS	WaitTOF
;		CALLSYS	WaitTOF

PCout
		rts

;********************************************************************


;* Stampa una stringa il cui indirizzo e' in a2 *********************

StampaCLI	movem.l	d0-d7/a0-a6,-(sp)

		DOSBASE
		CALLSYS	Output
		move.l	d0,d6		;salva handle

		move.l	a2,d2		;d2=indirizzo buffer

		moveq	#0,d3		;d3=lun
		bra	SCSj1
SCSloop		addq.l	#1,d3
SCSj1		tst.b	(a2)+
		bne	SCSloop

		move.l	d6,d1		;d1=handle output video
		CALLSYS	Write

		movem.l	(sp)+,d0-d7/a0-a6
		rts

;***************************************************************************

GraphicsName	dc.b	'graphics.library',0
DosName		dc.b	'dos.library',0
IntuitionName	dc.b	'intuition.library',0
timername	dc.b	'timer.device',0
audioname	dc.b	'audio.device',0

;VilIntuiSupName	dc.b	'vilintuisup.library',0


		dc.b	"sselb0000"	;Codice identificativo di chi possiede la demo
					;Il codice deve essere inserito al posto dei 4 zeri

ChannelMask	dc.b	15

		cnop	0,4


screentaglist:
; list of attributes for the screen that we want to open
		dc.l	SA_Left,0
		dc.l	SA_Width,SCREEN_WIDTH,SA_Height,SCREEN_HEIGHT+1,SA_Depth,SCREEN_DEPTH
		dc.l	SA_Quiet,-1			; prevent gadgets, titlebar from appearing.
		dc.l	SA_Type,CUSTOMSCREEN
		dc.l	SA_DisplayID,PAL_MONITOR_ID
		dc.l	SA_Draggable,0
bm_tag:
		dc.l	SA_BitMap,0
		dc.l	TAG_END,0

	xdef	uCopTags
uCopTags	dc.l	VTAG_USERCLIP_SET,0
		dc.l	VTAG_END_CM,0


spritetaglist0:				;Tag per null-sprite
		dc.l	SPRITEA_Width,64
		dc.l	SPRITEA_XReplication,0
		dc.l	SPRITEA_YReplication,0
		dc.l	SPRITEA_OutputHeight,1
		dc.l	TAG_END,0

spritetaglist1:				;Tag per sprite monitor
		dc.l	SPRITEA_Width,64
		dc.l	SPRITEA_XReplication,0
		dc.l	SPRITEA_YReplication,0
		dc.l	SPRITEA_OutputHeight,SPRMON_HEIGHT
		dc.l	TAG_END,0

spritetaglist2:				;Tag per sprite mirino
		dc.l	SPRITEA_Width,64
		dc.l	SPRITEA_XReplication,0
		dc.l	SPRITEA_YReplication,0
		dc.l	SPRITEA_OutputHeight,32
		dc.l	SPRITEA_Attached,1
		dc.l	TAG_END,0

spritetaglist3:
		dc.l	GSTAG_SPRITE_NUM,0
		dc.l	TAG_END,0

vctags		;dc.l	VC_IntermediateCLUpdate,0
		dc.l	VTAG_SPRITERESN_SET,SPRITERESN_140NS
		dc.l	VTAG_SPODD_BASE_SET,48
		dc.l	VTAG_SPEVEN_BASE_SET,48
		dc.l	VTAG_END_CM,0


; Tag per lo schermo di comodo aperto per leggere v_DxOffset PAL
usescreentaglist:
		dc.l	SA_Width,SCREEN_WIDTH,SA_Height,16,SA_Depth,1
		dc.l	SA_Quiet,-1			; prevent gadgets, titlebar from appearing.
		dc.l	SA_Type,CUSTOMSCREEN
		dc.l	SA_DisplayID,PAL_MONITOR_ID
		dc.l	SA_Draggable,0
		dc.l	SA_Colors32,usescreencolors
		dc.l	TAG_END,0

usescreencolors	dc.l	$00020000
		dc.l	0,0,0
		dc.l	0,0,0
		dc.l	0


		xdef	PaletteRGB32

PaletteRGB32	dc.l	$01000000
		ds.l	256*3
		dc.l	0

;***************************************************************************

ERRMSG          MACRO
                dc.w    24                      ; Height
                dc.w    320-4*(.End\@-.Start\@) ; X
                dc.b    12                      ; Y
.Start\@
                dc.b    \1
.End\@
                dc.b    0       ; NUL-terminator
                dc.b    0       ; Continuation byte
                even
                ENDM


ErrMsgGeneric   ERRMSG  "Resource allocation failed"
ErrMsgOSVer     ERRMSG  "AmigaOS 3.0 or later required"
ErrMsgAlloc     ERRMSG  "Memory allocation failed"
ErrMsgAGA       ERRMSG  "AGA required"
ErrMsgScreen    ERRMSG  "Failed to open screen"
ErrMsgLoad      ERRMSG  "Failed to load data"
ErrMsgUnknown   ERRMSG  "Unknown error occured"

                even
;***************************************************************************
	section	TABLES,bss

	xdef stupid
stupid	ds.l 1

;***************************************************************************
	section	__MERGED,bss

	xdef	ChunkyPointer,ChunkyBuffer,Yoffset,YoffsetPlus4

        ; XXX FIXME Not located at (a5) since switching to vasm
ChunkyPointer	ds.l	1	;pun. al buffer chunky pixel. DEVE essere il primo, in modo che il suo offset rispetto ad a5 sia 0.
				; E' usato dalle routine di tracciamento.

ChunkyBuffer	ds.l	1	;pun. al primo byte del buffer chunky pixel corrente.
				;Se l'output ? AGA, corrisponde a FakeChunkyPun;
				;Se l'output ? un vero schermo chunky pixel, corrisponde al buffer corrente in chunky pixel.

Yoffset			ds.l	1
YoffsetPlus4	ds.l	WINDOW_MAX_HEIGHT-1	;Lista di offset alle righe dello schermo chunky pixel. DEVE avere offset rispetto ad a5 di massimo 127.


	xdef	execbase,gfxbase,dosbase,intuitionbase

execbase	ds.l	1
gfxbase		ds.l	1
dosbase		ds.l	1
intuitionbase	ds.l	1
savesp		ds.l	1

myTask		ds.l	1	;Indirizzo di questo task
SaveWindowPtr	ds.l	1

;	xdef	vilintuisupbase
;vilintuisupbase	ds.l	1	;Pun. libreria PicassoII

wbview		ds.l	1

chipmem		ds.l	1
othermem	ds.l	1

	xdef	KeyQueueIndex1,KeyQueueIndex2,KeyQueue
KeyQueueIndex1	ds.l	1	;Indice al prossimo carattere da leggere nella coda.
KeyQueueIndex2	ds.l	1	;Indice alla prima posizione libera nella coda di tasti premuti. E' la posizione a cui inserire il prossimo carattere premuto
KeyQueue	ds.w	64	;Coda circolare contenente i codici dei tasti premuti (max 64)

	xdef	ScrOutputType
ScrOutputType	ds.l	1	;Tipo di output a video:
				; 0 = AGA chipset
				; 1 = Picasso II
				; 2 = Other video card

	xdef	MapPun,GfxPun
	xdef	TexturesDirPun,TexturesDirLen
	xdef	ObjectsDirPun,ObjectsDirLen
	xdef	SoundsDirPun,SoundsDirLen,SndPun
	xdef	GfxDirPun,GfxDirLen
	xdef	LevelsDirPun,LevelsDirLen
	xdef	FakeChunkyPun,c2pBuffer1,c2pBuffer2
	xdef	FreeGfxPun,Objects

MapPun		ds.l	1	;pun. alla memoria per la mappa
GfxPun		ds.l	1	;pun. alla memoria per gfx, textures e objects
TexturesDirPun	ds.l	1	;pun. alla memoria per la directory delle textures
TexturesDirLen	ds.l	1	;Lunghezza in byte della memoria per la directory delle textures
ObjectsDirPun	ds.l	1	;pun. alla memoria per la directory degli oggetti
ObjectsDirLen	ds.l	1	;Lunghezza in byte della memoria per la directory degli oggetti
SoundsDirPun	ds.l	1	;pun. alla memoria per la directory dei sounds
SoundsDirLen	ds.l	1	;Lunghezza in byte della memoria per la directory dei sounds
GfxDirPun	ds.l	1	;pun. alla memoria per la directory gfx
GfxDirLen	ds.l	1	;Lunghezza in byte della memoria per la directory gfx
LevelsDirPun	ds.l	1	;pun. alla memoria per la directory dei livelli
LevelsDirLen	ds.l	1	;Lunghezza in byte della memoria per la directory dei livelli
Objects		ds.l	1	;Pun. alla memoria per le strutture degli oggetti presenti in mappa
FakeChunkyPun	ds.l	1	;pun. al fake chunky pixel.
c2pBuffer1	ds.l	1	;pun. al primo buffer usato per la conversione chunky to planar. Usato anche come buffer per i caricamenti.
c2pBuffer2	ds.l	1	;pun. al secondo buffer usato per la conversione chunky to planar. Usato anche come buffer per i caricamenti.
SndPun		ds.l	1	;pun. alla memoria chip dedicata ai sounds

FreeGfxPun	ds.l	1	;Pun. alla memoria libera per gfx, textures e objects.
				;Per allocare memoria per la grafica bisogna usare
				;questo pun. e non GfxPun.

	xdef	nullbytes

nullbytes	ds.l	1

	xdef	IntuitionView
	xdef	TMapScreen
	xdef	screen_bitmap1,screen_bitmap2,screen_bitmap3,screen_viewport
	xdef	myDBufInfo,myCopList1,myCopList2,Sprites,NullSprites
	xdef	PanelBitplanes,screen_rport,myInputEvent

IntuitionView	ds.l	1
TMapScreen	ds.l	1
screen_bitmap1	ds.l	1	;Bitmap struct or true chunky screen pointer
screen_bitmap2	ds.l	1	;Bitmap struct or true chunky screen pointer
screen_bitmap3	ds.l	1	;Bitmap struct or true chunky screen pointer
screen_viewport	ds.l	1
PanelBitplanes	ds.l	8	;Puntatori agli 8 bitplane del pannello punteggi
myDBufInfo	ds.l	1
screen_rport	ds.b	rp_SIZEOF
myCopList1	ds.l	1
myCopList2	ds.l	1
myInputEvent	ds.l	1

;*** Attenzione!!! Le routine TurnOffSprites e TurnOnSprites contenute
;*** in TMapMain.asm vogliono che i 16 puntatori a ExtSprite di
;*** seguito riportati non siano cambiati di dimensione o posizione
Sprites		ds.l	8	;Pun. alle strutture ExtSprite
NullSprites	ds.l	8	;Pun. a null-sprites

TimerIO		ds.b	IOTV_SIZE

AudioPort	ds.l	1
AudioIO		ds.b	ioa_SIZEOF

		cnop	0,2

first_timer	ds.w	1	; clear if get_elapsed_time hasn't been called yet

		xdef	ResetMousePos

ResetMousePos	ds.b	1	;Se=TRUE, comunica all'input handler di
				;resettare la posizione del mouse

		ds.b	1	;Usato per allineare

		cnop	0,4

; the following two must stay together
LastEClock	ds.l	2
NewEClock	ds.l	2
; the preceeding two must stay together

MicrosPerEClock	ds.l	1


		xdef	sigbit1,sigbit2

sigbit1		ds.l	1	;Used from c2p8
sigbit2		ds.l	1	;Used from c2p8

	xdef	DBufSafePort,DBufDispPort

DBufSafePort	ds.l	1
DBufDispPort	ds.l	1

ErrorMessage    ds.l    1

		xdef	Palette,RedPalette

Palette		ds.b	256*3
RedPalette	ds.b	256*3

		cnop	0,4
	end


