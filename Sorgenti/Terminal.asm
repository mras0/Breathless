;****************************************************************************
;*
;*	Terminal.asm
;*
;*		Routines di gestione del terminale
;*
;*
;****************************************************************************

		include 'System'
		include 'TMap.i'

;****************************************************************************

		xref	gfxbase,intuitionbase
		xref	screen_viewport
		xref	joyup,joydown,joyfire1
		xref	ScrSprites
		xref	pause,VBTimer2
		xref	Escape,EscKey
		xref	KeyQueueIndex1,KeyQueueIndex2
		xref	PlayerCredits,PlayerCreditsFL
		xref	GlobalSound0,GlobalSound1,GlobalSound2,GlobalSound3
		xref	GlobalSound4,GlobalSound5,GlobalSound6,GlobalSound7
		xref	GlobalSound8,GlobalSound9,GlobalSound10
		xref	ScreenActive,OldScreenActive
		xref	ProgramState
		xref	ForwardKey,BackwardKey,RotateLeftKey,RotateRightKey
		xref	SideLeftKey,SideRightKey,FireKey,AccelKey
		xref	ForceSideKey,LookUpKey,ResetLookKey,LookDownKey
		xref	SwitchKey
		xref	LevelCodeASC,FirstMatchLevel
		xref	P61_Master,P61_Play
		xref	Sprites
		xref	ShowCredits,StartGame
		xref	ActiveControl,MouseSensitivity
		xref	ActiveKeyConfig,KeyboardKeyConfig,MouseKeyConfig
		xref	PlayerWalkSpeed,PlayerRunSpeed
		xref	PlayerRotWalkSpeed,PlayerRotRunSpeed
		xref	PlayerAccel,PlayerRotAccel

		xref	SprDelayPrint,SprPrint
		xref	CheckEmptySprBuffer
		xref	ReadKey
		xref	CollectItem,CollectWeapon,BoostWeapon,PanelRefresh
		xref	PlaySoundFX
		xref	TurnOffSprites,TurnOnSprites,InitSight
		xref	InitAudio2
		xref	CheckAccessCode
		xref	TestChangeScreen
		xref	SecurityCode1,SecurityCode2
		xref	WriteConfig

;****************************************************************************

		xdef	Terminal

Terminal

Textloop
		tst.w	InitPageInput(a5)	;Deve inizializzare l'input ?
		beq.s	Tloop			; Se no, salta

		clr.w	InitPageInput(a5)

		move.w	ChoiceItem1(a5),d6
		move.w	ChoiceItem2(a5),d7
		clr.w	joyup(a5)
		clr.w	joydown(a5)

		move.w	d6,d5
		bsr	DrawSelectionBox

			;*** Inizializza coda tasti premuti
		clr.l	KeyQueueIndex1(a5)
		clr.l	KeyQueueIndex2(a5)

Tloop
		tst.l	terminal(a5)		;Il terminale  ancora attivo ?
		beq	Tlogout			; Se no, esce

		jsr	TestChangeScreen

		GFXBASE
		CALLSYS	WaitTOF

                UPDATE_TERMINAL

		tst.w	joyup(a5)
		bne.s	Tkeyup
		tst.w	joydown(a5)
		bne.s	Tkeydown

		lea	KeyQueueIndex1(a5),a0
		move.l	(a0)+,d1		;d1=KeyQueueIndex1
		cmp.l	(a0)+,d1		;Confronta con KeyQueueIndex2
		beq	Tloop			;Se sono uguali, allora la coda  vuota
		move.w	(a0,d1.l),d0		;d0=scancode tasto
		addq.l	#2,d1			;Sposta l'indice
		and.w	#$7f,d1			;Assicura la circolarit dell'indice
		move.l	d1,KeyQueueIndex1(a5)	;Memorizza l'indice

		cmp.w	#($4c),d0		;Premuto tasto up ?
		beq.s	Tkeyup
		cmp.w	#($4d),d0		;Premuto tasto down ?
		beq.s	Tkeydown
		cmp.w	#$44,d0			;Premuto tasto RETURN ?
		beq.s	Tselect
		cmp.w	#$40,d0			;Premuto tasto SPACE ?
		beq.s	Tselect
;		cmp.w	#($45+$80),d0		;Premuto tasto ESC ?
;		beq.s	Tlogout
		bra.s	Tloop

			;*** Attende un certo numero di 50esimi
			;*** per evitare una ripetizione troppo
			;*** veloce dei tasti
;Twait		move.l	VBTimer2(a5),d0
;		add.l	#8,d0
;Twaitloop	cmp.l	VBTimer2(a5),d0
;		bne.s	Twaitloop
;		bra.s	Tloop

Twait		moveq	#5,d2
		GFXBASE
Twaitloop	CALLSYS	WaitTOF
		dbra	d2,Twaitloop
		bra.s	Tloop

Tkeyup
		bsr	DrawSelectionBox
		subq.w	#1,d5
		cmp.w	d6,d5			;Puo' andare in alto ?
		bge.s	Tkuok			; Se si, salta
		move.w	d7,d5			; Altrimenti va sull'ultimo item
Tkuok		bsr	DrawSelectionBox
		bra.s	Twait

Tkeydown
		bsr	DrawSelectionBox
		addq.w	#1,d5
		cmp.w	d7,d5			;Puo' andare in basso ?
		ble.s	Tkdok			; Se si, salta
		move.w	d6,d5			; Altrimenti va sul primo item
Tkdok		bsr	DrawSelectionBox
		bra.s	Twait


Tselect
		move.w	d5,d0
		sub.w	d6,d0
		bsr	DoSelection
		bne	Textloop		;Salta se selezione rifiutata
		move.l	GlobalSound2(a5),a0
		moveq	#0,d1
		jsr	PlaySoundFX
		bra	Textloop



Tlogout
		tst.l	terminal(a5)		;Test se terminale o configurazione
		bgt.s	Tnoconf			; Se terminale, salta
		bsr	AdjustConfigVars
Tnoconf


		moveq	#0,d0
		moveq	#0,d1
		lea	clearterminal(pc),a0
		jsr	SprDelayPrint

		clr.l	terminal(a5)

		tst.b	ProgramState(a5)	;Test se terminale durante il gioco
		beq.s	Tloncp			; Se no, salta
		clr.w	pause(a5)
Tloncp
                ; Make sure delayed console is cleared
                tst.b   RTGFlag(a5)
                beq     .NoRTG
.WaitMsg
		jsr	CheckEmptySprBuffer
		bne.s	.WaitMsg
                UPDATE_TERMINAL
.NoRTG
		rts

;****************************************************************************
;* Effettua selezione di un item
;* Richiede:
;*	d0 = Numero dell'item selezionato (=>0)
;*
;* Restituisce Flag Z=1 se la selezione viene accettata

		xdef	DSprotoffs

DoSelection
;		tst.b	Protection(a5)		;Test se protezione
;DSprotoffs	bne	DSprotection
		tst.l	terminal(a5)		;Test se menu configurazione
		bmi	DSconfig		; Se si, salta
		move.w	CurrentPageNum(a5),d1
		beq.s	DSmainpage	;Page 0
		subq.w	#1,d1
		beq.s	DSweapon	;Page 1
		subq.w	#1,d1
		beq.s	DSboost		;Page 2
		subq.w	#1,d1
		beq.s	DSaccess	;Page 3
		rts


DSmainpage
		cmp.w	#3,d0			;Selezionato exit ?
		bne.s	DSmpnoexit		; Se no, salta
		clr.l	terminal(a5)
		moveq	#0,d0
		rts
DSmpnoexit	lea	TermPages(pc),a0
		move.l	4(a0,d0.w*4),a1		;a1=Pun. alla nuova pagina
		bra	DSdisplaypage		;Visualizza la pagina


	;*** Gestione pagina Weapon
DSweapon
		cmp.w	#5,d0			;Selezionato exit ?
		bne.s	DSwenoexit		; Se no, salta
		move.l	TermPages(pc),a1	;a1=pun. alla main page
		bra	DSdisplaypage		;Visualizza la pagina
DSwenoexit	move.l	CurrentPage(a5),a0
		move.l	6(a0,d5.w*4),a0		;a0=pun. alla stringa corrispondente alla riga selezionata
		moveq	#0,d1
		move.w	8(a0),d1		;d1=credits necessari
		move.l	PlayerCredits(a5),d2	;d2=credits posseduti
		sub.l	d1,d2			;Sottrae crediti
		bmi	DSnobuy			;Se non bastano, segnala errore
		move.l	d2,a4
		addq.w	#1,d0
		jsr	CollectWeapon
		bra.s	DSbuy


	;*** Gestione pagina Weapon boost
DSboost
		cmp.w	#6,d0			;Selezionato exit ?
		bne.s	DSbsnoexit		; Se no, salta
		move.l	TermPages(pc),a1	;a1=pun. alla main page
		bra	DSdisplaypage		;Visualizza la pagina
DSbsnoexit	move.l	CurrentPage(a5),a0
		move.l	6(a0,d5.w*4),a0		;a0=pun. alla stringa corrispondente alla riga selezionata
		moveq	#0,d1
		move.w	8(a0),d1		;d1=credits necessari
		bmi.s	DSnobuy			; Se<0, non si pu acquistare
		move.l	PlayerCredits(a5),d2	;d2=credits posseduti
		sub.l	d1,d2			;Sottrae crediti
		bmi.s	DSnobuy			;Se non bastano, segnala errore
		move.l	d2,a4
		jsr	BoostWeapon
		bra.s	DSbuy


	;*** Gestione pagina Accessories
DSaccess
		cmp.w	#7,d0			;Selezionato exit ?
		bne.s	DSacnoexit		; Se no, salta
		move.l	TermPages(pc),a1	;a1=pun. alla main page
		bra	DSdisplaypage		;Visualizza la pagina
DSacnoexit	move.l	CurrentPage(a5),a0
		move.l	6(a0,d5.w*4),a0		;a0=pun. alla stringa corrispondente alla riga selezionata
		moveq	#0,d1
		move.w	8(a0),d1		;d1=credits necessari
		move.l	PlayerCredits(a5),d2	;d2=credits posseduti
		sub.l	d1,d2			;Sottrae crediti
		bmi.s	DSnobuy			;Se non bastano, segnala errore
		move.l	d2,a4
		move.w	d0,d4
		cmp.w	#3,d4
		blt.s	DSacj1
		addq.w	#1,d4
DSacj1		move.w	10(a0),d2		;Qt da sommare
		jsr	CollectItem




	;*** Gestione acquisto di un oggetto
DSbuy
		tst.w	d0			;Tutto ok ?
		bmi.s	DSnobuy			; Se no, salta
		move.l	a4,PlayerCredits(a5)
		st	PlayerCreditsFL(a5)
;		move.l	GlobalSound2(a5),a0
;		moveq	#0,d1
;		jsr	PlaySoundFX
		jsr	PanelRefresh
		moveq	#0,d0
		rts


	;*** Segnala errore quando non si puo' acquistare l'oggetto
DSnobuy
		moveq	#1,d0
		rts



;--------------------

DSconfig
		move.w	CurrentPageNum(a5),d1
		beq.s	DSCMmainpage	;Page 0
		subq.w	#1,d1
		beq	DSCMwindow	;Page 1
		subq.w	#1,d1
		beq	DSCMsound	;Page 2
		subq.w	#1,d1
		beq	DSCMkeyboard	;Page 3
		subq.w	#1,d1
		beq	DSCMcontrol	;Page 4
		subq.w	#1,d1
		beq	DSCMgameopt	;Page 5
		rts


DSCMmainpage
		moveq	#5,d1			;d1=indice scelta quit game durante il gioco
		tst.b	ProgramState(a5)	;Test se configurazione durante il gioco
		bne.s	DSCMmpdg		; Se si, salta
		moveq	#7,d1			;d1=indice scelta quit game nei menu
		cmp.w	#6,d0			;Selezionato, pag. credits ?
		bne.s	DSCMmpdg		; Se no, salta
		st	ShowCredits(a5)		;Segnala di visualizzare credits
		bra.s	DSCMrtg			; ed esce dal menu
DSCMmpdg	tst.w	d0			;Selezionato, return to game / start game ?
		bne.s	DSCMnortg		; Se no, salta
		st	StartGame(a5)
		bra.s	DSCMrtg
DSCMnortg	cmp.w	d1,d0			;Selezionato quit game ?
		bne.s	DSCMmpnoexit		; Se no, salta
		move.l	GlobalSound2(a5),a0
		moveq	#0,d1
		jsr	PlaySoundFX
		moveq	#10,d0			;x
		moveq	#20,d1			;y
		moveq	#1,d2			;color
		lea	askquit(pc),a0		;Chiede se si vuole davvero uscire
		jsr	SprDelayPrint
DSCMmptqg	jsr	TestChangeScreen
                UPDATE_TERMINAL
		jsr	ReadKey			;Legge un tasto dalla tastiera
		ext.w	d0
		tst.w	d0
		bmi.s	DSCMmptqg		;Salta se nessun tasto
		cmp.b	#$36,d0			;Premuto 'N' ?
		beq.s	DSCMrtg			; Se si, salta
		cmp.b	#$15,d0			;Premuto 'Y' ?
		bne.s	DSCMmptqg		; Se no, salta
		st	Escape(a5)
		st	EscKey(a5)
DSCMrtg		clr.l	terminal(a5)
		moveq	#0,d0
		rts
DSCMmpnoexit	lea	ConfPages(pc),a0
		move.l	(a0,d0.w*4),a1		;a1=Pun. alla nuova pagina
		bra	DSdisplaypage		;Visualizza la pagina


	;*** Gestione pagina Window
DSCMwindow
		cmp.w	#3,d0			;Selezionato exit ?
		bne.s	DSCMwinoexit		; Se no, salta
		move.l	ConfPages(pc),a1	;a1=pun. alla main page
		bra	DSdisplaypage		;Visualizza la pagina
DSCMwinoexit	bsr	DSCMgest
		tst.b	ProgramState(a5)	;Test se attivo gioco
		ble.s	DSCMwinois		; Se no, non inizializza mirino
		jsr	InitSight		;Init mirino
DSCMwinois	moveq	#0,d0
		rts


	;*** Gestione pagina Sound
DSCMsound
		cmp.w	#3,d0			;Selezionato exit ?
		bne.s	DSCMsonoexit		; Se no, salta
		move.l	ConfPages(pc),a1	;a1=pun. alla main page
		bra	DSdisplaypage		;Visualizza la pagina
DSCMsonoexit	bsr	DSCMgest
		tst.b	ProgramState(a5)	;Test se attivo gioco
		ble.s	DSCMsonoia		; Se no, non inizializza audio
		jsr	InitAudio2
DSCMsonoia	moveq	#0,d0
		rts


	;*** Gestione pagina Keyboard
DSCMkeyboard
		cmp.w	#13,d0			;Selezionato exit ?
		bne.s	DSCMkenoexit		; Se no, salta
		bsr	CopyFromActualConfig	;Copia config. tastiera
		move.l	ConfPages(pc),a1	;a1=pun. alla main page
		bra	DSdisplaypage		;Visualizza la pagina
DSCMkenoexit	move.l	GlobalSound2(a5),a0
		moveq	#0,d1
		jsr	PlaySoundFX
		move.l	CurrentPage(a5),a0
		move.l	6(a0,d5.w*4),a3		;a3=pun. alla stringa corrispondente alla riga selezionata
		move.w	8(a3),d0		;d0=x
		move.w	10(a3),d1		;d1=y
		move.l	12(a3),a1		;a1=pun. alla lista di stringhe selezionabili
		move.l	16(a3),a2		;a2=pun. allo scan code attuale
		move.w	(a2),d2			;Legge scancode
		lea	(a1,d2.w*4),a0		;a0=Pun. vecchia stringa selezionata
		moveq	#-1,d3			;d3=color
		jsr	SprPrint		;Cancella vecchia stringa
DSCMkeloop	jsr	TestChangeScreen
		jsr	ReadKey			;Legge un tasto dalla tastiera
		ext.w	d0
		tst.w	d0
		bmi.s	DSCMkeloop		;Salta se nessun tasto
		lea	(a1,d0.w*4),a0		;a0=Pun. alla nuova stringa selezionata
		tst.l	(a0)			;Test se il tasto  utilizzabile
		bne.s	DSCMkeok		; Se si, salta
		move.w	d2,d0
		lea	(a1,d0.w*4),a0		;a0=Pun. alla stringa precedente
DSCMkeok	move.w	d0,d2
		move.w	d0,(a2)			;Scrive nuovo indice
		move.w	8(a3),d0		;d0=x
		moveq	#1,d3			;d3=color
		jsr	SprPrint		;Scrive nuova stringa
		moveq	#0,d0
		rts


	;*** Gestione pagina control
DSCMcontrol
		cmp.w	#8,d0			;Selezionato exit ?
		bne.s	DSCMctnoexit		; Se no, salta
		bsr	CopyToActualConfig	;Copia config. tastiera
		move.l	ConfPages(pc),a1	;a1=pun. alla main page
		bra	DSdisplaypage		;Visualizza la pagina
DSCMctnoexit	bsr	DSCMgest
		moveq	#0,d0
		rts


	;*** Gestione pagina game options
DSCMgameopt
		cmp.w	#3,d0			;Selezionato exit ?
		bne.s	DSCMgonoexit		; Se no, salta
		move.l	ConfPages(pc),a1	;a1=pun. alla main page
		bra	DSdisplaypage		;Visualizza la pagina
DSCMgonoexit	cmp.w	#1,d0			;Selezionato reset code ?
		bne.s	DSCMgonorc		; Se no, salta
		lea	LevelCodeASC(a5),a1
		move.l	#'181C',(a1)+
		move.l	#'EIGG',(a1)+
		move.l	#'LJRJ',(a1)+
		move.l	#'SE2T',(a1)
		move.l	CurrentPage(a5),a1
		bra	DSdisplaypage		;Visualizza la pagina corrente
;		moveq	#0,d0
;		rts
DSCMgonorc	cmp.w	#2,d0			;Selezionato save config.?
		bne.s	DSCMgonosaco		; Se no, salta
		bsr	AdjustConfigVars
		jsr	WriteConfig		;Salva configurazione
		moveq	#0,d0
		rts
DSCMgonosaco	move.l	CurrentPage(a5),a0
		move.l	6(a0,d5.w*4),a3		;a3=pun. alla stringa corrispondente alla riga selezionata

		move.l	12(a3),a1		;a1=pun. alla stringa destinazione
		move.l	16(a3),a2		;a2=pun. al buffer di input
		move.w	8(a3),d0		;d0=x
		move.w	10(a3),d1		;d1=y
		moveq	#-1,d3			;d3=color
		move.l	a1,a0
		jsr	SprPrint		;Cancella stringa
		move.l	a2,a0
DSCMgocopy1	tst.b	(a1)+
		beq.s	DSCMgocpj1
		move.b	#'_',(a0)+		;Inizializza buffer input
		bra.s	DSCMgocopy1
DSCMgocpj1	clr.b	(a0)
		lea	keytable(pc),a4
		move.l	a2,a1			;a1=pun. al carattere corrente
DSCMgoloop1	move.l	a2,a0
		move.w	8(a3),d0		;d0=x
		move.w	10(a3),d1		;d1=y
		moveq	#1,d3			;d3=color
		jsr	SprPrint		;Scrive nuova stringa
DSCMgoloop2	jsr	TestChangeScreen
		jsr	ReadKey			;Legge un tasto dalla tastiera
		ext.w	d0
		move.w	d0,d4
		bmi.s	DSCMgoloop2		;Salta se nessun tasto
		move.l	a2,a0
		move.w	8(a3),d0		;d0=x
		move.w	10(a3),d1		;d1=y
		moveq	#-1,d3			;d3=color
		jsr	SprPrint		;Cancella stringa
		cmp.b	#$41,d4			;Premuto backspace ?
		bne.s	DSCMgoj1
		cmp.l	a2,a1
		beq.s	DSCMgoloop1
		move.b	#'_',-(a1)
		bra.s	DSCMgoloop1
DSCMgoj1	cmp.b	#$44,d4			;Premuto return ?
		beq.s	DSCMgoret
		cmp.b	#$45,d4			;Premuto esc ?
		beq.s	DSCMgoout
		tst.b	(a1)			;Siamo a fine stringa ?
		beq.s	DSCMgoloop1		; Se si, salta
		move.b	(a4,d4.w),d0		;Legge codice ASCII
		beq.s	DSCMgoloop1
		move.b	d0,(a1)+
		bra.s	DSCMgoloop1
DSCMgoret	move.l	12(a3),a1		;a1=pun. stringa destinazione
DSCMgocopy2	move.b	(a2)+,(a1)+		;Copia buffer input nella stringa destinazione
		bne.s	DSCMgocopy2
		bsr	CheckAccessCode		;Controlla correttezza codice
		bne.s	DSCMgonogood		; Se codice errato, salta
DSCMgoout	move.l	12(a3),a0
		move.w	8(a3),d0		;d0=x
		move.w	10(a3),d1		;d1=y
		moveq	#0,d3			;d3=color
		jsr	SprPrint		;Scrive nuova stringa
DSCMgoclloop	jsr	ReadKey			;Svuota il buffer della tastiera
		tst.w	d0
		bpl.s	DSCMgoclloop
		moveq	#0,d0
		rts
DSCMgonogood
		moveq	#16,d0			;x
		moveq	#90,d1			;y
		moveq	#1,d2			;color
		lea	badcode(pc),a0		;Segnala codice errato
		jsr	SprDelayPrint
		bra.s	DSCMgoout



	;*** Gestione pagine configurazione
DSCMgest
		move.l	CurrentPage(a5),a0
		move.l	6(a0,d5.w*4),a3		;a3=pun. alla stringa corrispondente alla riga selezionata
		move.w	8(a3),d0		;d0=x
		move.w	10(a3),d1		;d1=y
		move.l	12(a3),a1		;a1=pun. alla lista di pun. alle stringhe selezionabili
		move.l	16(a3),a2		;a2=pun. all'indice
		move.w	(a2),d2			;Legge indice
		move.l	(a1,d2.w*4),a0		;a0=Pun. vecchia stringa selezionata
		moveq	#-1,d3			;d3=color
		jsr	SprPrint		;Cancella vecchia stringa
		addq.w	#1,d2			;Sposta indice sulla nuova stringa
		move.l	(a1,d2.w*4),d3		;d3=Pun. alla nuova stringa selezionata
		bne.s	DSCMnowrap		;Salta se non ha superato l'ultima stringa della lista
		moveq	#0,d2
		move.l	(a1),d3
DSCMnowrap	move.w	d2,(a2)			;Scrive nuovo indice
		move.l	d3,a0			;a0=Pun. stringa
		moveq	#1,d3			;d3=color
		jsr	SprPrint		;Scrive nuova stringa
		rts



;--------------------
    IFEQ 1	;*** !!!PROTEZIONE!!!

		xdef	DSprotection,DSprotectionEnd

DSprotection
		cmp.w	#4,d0			;Selezionato exit ?
		bne.s	DSprotnoexit		; Se no, salta
		move.b	ProtCode1+1(a5),d0
		lsl.l	#8,d0
		move.b	ProtCode2+1(a5),d0
		lsl.l	#8,d0
		move.b	ProtCode3+1(a5),d0
		lsl.l	#8,d0
		move.b	ProtCode4+1(a5),d0
		move.l	d0,InSecCode(a5)	;Codice appena immesso
		move.l	SecCodeCol(a5),d1
		sub.w	#64,d1
		move.l	SecCodeRow(a5),d2
		bsr	SecurityCode1		;Calcola il codice richiesto
		lea	prot_page(pc),a1
		cmp.l	InSecCode(a5),d0	;Confronta con quello immesso
;PROT.REMOVED	bne.s	DSdisplaypage
		clr.b	Protection(a5)
		clr.l	terminal(a5)
		moveq	#0,d0
		rts
DSprotnoexit	bsr	DSCMgest
		moveq	#0,d0
		rts
DSprotectionEnd

    ENDIF	;*** !!!FINE PROTEZIONE!!!


;--------------------


	;*** Visualizza la pagina puntata da a1
	;*** ed esce da DoSelection
DSdisplaypage
;		moveq	#0,d0
;		moveq	#0,d1
;		lea	clearterminal(pc),a0
;		jsr	SprDelayPrint
		bsr	PrintTerminalPage
		moveq	#0,d0
		rts


;****************************************************************************
;* Traccia/Cancella il box di selezione degli item del menu
;* Richiede:
;*	d5 = Indice nella lista di pun. alle stringhe della pagina corrente

DrawSelectionBox

DSBwait		jsr	TestChangeScreen
		jsr	CheckEmptySprBuffer	;Attende che il buffer sia vuoto
		bne.s	DSBwait

		move.l	CurrentPage(a5),a0
		move.l	6(a0,d5.w*4),a0		;a0=pun. alla stringa corrispondente alla riga selezionata
		move.w	2(a0),d1		;d1=y
		subq.w	#1,d1

		lea	ScrSprites(a5),a1
		lsl.w	#4,d1		;d1=y*16

		moveq	#-1,d0
		move.l	#$80000000,d2
		moveq	#1,d3

		move.l	(a1)+,a0
		add.w	d1,a0		;a0=Pun. al primo sprite
		move.l	(a1)+,a1
		add.w	d1,a1		;a1=Pun. al secondo sprite

		eor.l	d0,(a0)+
		eor.l	d0,(a0)+
		addq.l	#8,a0
		eor.l	d0,(a1)+
		eor.l	d0,(a1)+
		lea	12(a1),a1

		move.w	#SPRMON_CHARHEIGHT-1,d4
DSBloop1	eor.l	d2,(a0)+
		eor.l	d3,(a1)+
		lea	12(a0),a0
		lea	12(a1),a1
		dbra	d4,DSBloop1

		eor.l	d0,(a0)+
		eor.l	d0,(a0)+
		eor.l	d0,-4(a1)
		eor.l	d0,(a1)+

		rts


;****************************************************************************
;* Inizializzazione di alcune variabili di configurazione.
;* Da eseguire nella fase di inizializzazione del terminale (InitTerminal).

InitConfigVars

		move.w	PlayerWalkSpeed(a5),d0
		lsr.w	#4,d0
		subq.w	#4,d0
		move.w	d0,WalkSpeed(a5)

		move.w	PlayerRunSpeed(a5),d0
		lsr.w	#4,d0
		subq.w	#4,d0
		move.w	d0,PWalkSpeed(a5)

		move.w	PlayerRotWalkSpeed(a5),d0
		subq.w	#8,d0
		lsr.w	#2,d0
		move.w	d0,RotSpeed(a5)

		move.w	PlayerRotRunSpeed(a5),d0
		subq.w	#8,d0
		lsr.w	#2,d0
		move.w	d0,PRotSpeed(a5)

		move.w	PlayerAccel(a5),d0
		lsr.w	#1,d0
		subq.w	#1,d0
		move.w	d0,WalkInertia(a5)

		move.w	PlayerRotAccel(a5),d0
		lsr.w	#1,d0
		move.w	d0,RotInertia(a5)

		rts

;****************************************************************************
;* Ricalcolo di alcune variabili di configurazione, in base alle
;* selezioni dell'utente.
;* Da eseguire all'uscita dal menu di configurazione.

AdjustConfigVars

		move.w	WalkSpeed(a5),d0
		addq.w	#4,d0
		lsl.w	#4,d0
		move.w	d0,PlayerWalkSpeed(a5)

		move.w	PWalkSpeed(a5),d0
		addq.w	#4,d0
		lsl.w	#4,d0
		move.w	d0,PlayerRunSpeed(a5)

		move.w	RotSpeed(a5),d0
		lsl.w	#2,d0
		addq.w	#8,d0
		move.w	d0,PlayerRotWalkSpeed(a5)

		move.w	PRotSpeed(a5),d0
		lsl.w	#2,d0
		addq.w	#8,d0
		move.w	d0,PlayerRotRunSpeed(a5)

		move.w	WalkInertia(a5),d0
		lsl.w	#1,d0
		bne.s	ACVwinz
		moveq	#1,d0
ACVwinz		addq.w	#2,d0
		move.w	d0,PlayerAccel(a5)

		move.w	RotInertia(a5),d0
		clr.l	d1
		bset	d0,d1
		move.w	d1,PlayerRotAccel(a5)

		rts

;****************************************************************************
;* Copia configurazione tastiera da quella attuale a quella keyboard/mouse

CopyFromActualConfig

		movem.l	d0/a0-a1,-(sp)

		lea	ActiveKeyConfig,a0

		lea	KeyboardKeyConfig,a1
		tst.w	ActiveControl(a5)
		beq.s	CFACj1
		lea	MouseKeyConfig,a1
CFACj1

CFACloop	move.w	(a0)+,d0
		cmp.w	#$8180,d0
		beq.s	CFACend
		move.w	d0,(a1)+
		bra.s	CFACloop
CFACend
		movem.l	(sp)+,d0/a0-a1
		rts

;****************************************************************************
;* Copia configurazione tastiera da quella keyboard/mouse a quella attuale 

		xdef	CopyToActualConfig
CopyToActualConfig

		movem.l	d0/a0-a1,-(sp)

		lea	ActiveKeyConfig,a1

		lea	KeyboardKeyConfig,a0
		tst.w	ActiveControl(a5)
		beq.s	CTACj1
		lea	MouseKeyConfig,a0
CTACj1

CTACloop	move.w	(a0)+,d0
		cmp.w	#$8180,d0
		beq.s	CTACend
		move.w	d0,(a1)+
		bra.s	CTACloop
CTACend
		movem.l	(sp)+,d0/a0-a1
		rts

;****************************************************************************
;* Inizializza terminale

		xdef	InitTerminal

InitTerminal	movem.l	d0-d2/a0-a1/a4/a6,-(sp)

                tst.b   RTGFlag(a5)
                beq     .NoRTG
                bsr     RTGInitTerminal
.NoRTG

		lea	term_page0(pc),a1

		bsr	InitConfigVars		;Inizializza variabili configurazione

    IFEQ 1	;*** !!!PROTEZIONE!!!
		tst.b	Protection(a5)		;Test se protezione
		beq.s	ITnoprot		; Se no, salta
		bsr	SetTermPos
		clr.l	ProtCode1(a5)
		clr.l	ProtCode3(a5)
		lea	pp0_s5(pc),a1
		move.b	SecCodeCol+3(a5),8(a1)
		lea	prot_page(pc),a1
		bra.s	ITnoconf
    ENDIF	;*** !!!FINE PROTEZIONE!!!

ITnoprot	tst.l	terminal(a5)		;Test se terminale o configurazione
		bgt.s	ITnoconf		; Se terminale, salta

;		bsr	InitConfigVars		;Inizializza variabili configurazione

		GFXBASE

		tst.b	ProgramState(a5)	;Test se configurazione durante il gioco
		bne.s	ITgameconf		; Se si, salta
		bsr	SetTermPos
		lea	conf_page0p(pc),a1
		bra.s	ITj1
ITgameconf
		lea	conf_page0(pc),a1
ITj1
		lea	ConfPages(pc),a0
		move.l	a1,(a0)			;Scrive pun. al menu di configurazione

ITnoconf
		bsr	PrintTerminalPage

		movem.l	(sp)+,d0-d2/a0-a1/a4/a6
		rts



;***** Posiziona terminale a centro schermo

SetTermPos
		move.l	screen_viewport(a5),a0
		move.l	Sprites+(6<<2)(a5),a1	;SimpleSprite pointer
		moveq	#96,d0			;x
		moveq	#80,d1			;y
		CALLSYS	MoveSprite
		move.l	screen_viewport(a5),a0
		move.l	Sprites+(7<<2)(a5),a1	;SimpleSprite pointer
		move.l	#160,d0			;x
		moveq	#80,d1			;y
		CALLSYS	MoveSprite
		rts

;****************************************************************************
;* Inizializza e stampa una pagina del terminale
;* Richiede:
;*	a1 = Pun. alla pagina da stampare

PrintTerminalPage

		move.l	a1,CurrentPage(a5)
		move.w	(a1)+,CurrentPageNum(a5)
		move.w	(a1)+,ChoiceItem1(a5)
		move.w	(a1)+,ChoiceItem2(a5)
		move.w	#1,InitPageInput(a5)

PTPloop		move.l	(a1)+,d0
		beq	PTPout
		move.l	d0,a0
		move.w	(a0)+,d0	;x
		move.w	(a0)+,d1	;y
		move.w	(a0)+,d2	;color
		move.w	(a0)+,d3	;type
		beq.s	PTPp1		;Salta se type=0
		bmi.s	PTPp2		;Salta se type<0
		cmp.w	#2,d3
		bge.s	PTPp3		;Salta se type=2 o type=3 o type=4
		move.l	(a0)+,a2
		move.l	(a2),d4		;d4=numero da convertire
		jsr	ConvertNumber
		bra.s	PTPp1
PTPp3		lea	12(a0),a0	;Salta dati selezione
		bra.s	PTPp1
PTPp2		addq.l	#4,a0		;Salta numero crediti e value
PTPp1		jsr	SprDelayPrint

		cmp.w	#2,d3
		bne.s	PTPp4		;Salta se type<>2
		lea	-12(a0),a0
		move.w	(a0)+,d0	;x
		move.w	(a0)+,d1	;y
		move.l	(a0)+,a2	;a2=Pun. alla lista dei pun. alle stringhe selezionabili
		move.l	(a0)+,a0
		move.w	(a0),d3		;d3=indice stringa selezionata
		move.l	(a2,d3.w*4),a0	;a0=pun. alla stringa selezionata
		moveq	#1,d2		;color
		jsr	SprDelayPrint
		bra.s	PTPloop

PTPp4		cmp.w	#3,d3
		bne.s	PTPp5		;Salta se type<>3
		lea	-12(a0),a0
		move.w	(a0)+,d0	;x
		move.w	(a0)+,d1	;y
		move.l	(a0)+,a2	;a2=Pun. alla lista dei nomi dei tasti
		move.l	(a0)+,a0
		move.w	(a0),d3		;d3=codice tasto selezionato
		lea	(a2,d3.w*4),a0	;a0=pun. alla stringa selezionata
		moveq	#1,d2		;color
		jsr	SprDelayPrint
		bra.s	PTPloop

PTPp5		cmp.w	#4,d3
		bne.s	PTPloop		;Salta se type<>4
		lea	-12(a0),a0
		move.w	(a0)+,d0	;x
		move.w	(a0)+,d1	;y
		move.l	(a0)+,a2	;a2=Pun. alla stringa destinazione
		move.l	(a0)+,a3	;a3=Pun. al buffer di input
		move.l	a2,a0
PTPp5loop	move.b	(a2)+,(a3)+	;Copia la stringa iniziale nel buffer di input (compreso lo zero finale)
		bne.s	PTPp5loop
		moveq	#0,d2		;color
		jsr	SprDelayPrint
		bra	PTPloop
PTPout
		rts

;****************************************************************************
;* Converte un numero in formato stringa
;* Richiede:
;*	d4 = Numero da convertire
;*	a0 = Pun. alla stringa di output (l'unico char=0 deve essere quello di terminazione della stringa)

ConvertNumber	movem.l	d2-d4/a0-a1,-(sp)

			;*** Cerca il char di terminazione della stringa
			;*** e abblenca stringa
		move.l	a0,a1
CNloops		tst.b	(a0)
		beq.s	CNsrcout
		move.b	#32,(a0)+
		bra.s	CNloops
CNsrcout

			;*** Converte il numero
		moveq	#10,d2

CNloopc		divul.l	d2,d3:d4
		beq.s	CNend
		cmp.l	a1,a0		;Se il numero non entra nella stringa
		beq.s	CNerror		; errore!
		add.w	#48,d3		;Trasforma in ASCII
		move.b	d3,-(a0)	;Inserisce nella stringa
		bra.s	CNloopc
CNend
		cmp.l	a1,a0		;Se il numero non entra nella stringa
		beq.s	CNerror		; errore!
		add.w	#48,d3		;Trasforma in ASCII
		move.b	d3,-(a0)	;Inserisce nella stringa
CNout
		movem.l	(sp)+,d2-d4/a0-a1
		rts

CNerror
			;*** Riempie la stringa di '!'
CNloope		tst.b	(a1)
		beq.s	CNout
		move.b	#'!',(a1)+
		bra.s	CNloope

;****************************************************************************
;* Ogni pagina e' formata da una lista di pun. (terminata da zero)
;* alle stringhe che compongono la pagina stessa.
;* Subito prima della lista di pun. ci sono 2 word, che indicano
;* la prima e l'ultima scelta nel menu.
;* In pratica queste due word sono degli indici all'interno della
;* lista di puntatori.
;* Ancora prima c'e' una word indicante il numero della pagina (=>0).
;* Ogni scelta del menu deve essere rappresentata da una sola stringa.
;* Ogni stringa e' formata dai seguenti dati:
;*	x	 W	coordinata x in pixel (0-127)
;*	y	 W	coordinata y in pixel (0-123)
;*	color	 W	colore (0/1/2)
;*	type	 W	tipo ( -1:menu item; 0:stringa; 1:numero; 2:cycle selector; 3:key selector; 4:levelcode input)
;*	numpun	 L	presente solo se type=1,  il pun. a una long
;*			contenente il numero da stampare
;*	credits  W	presente solo se type=-1,  il num. di crediti
;*			necessario per acquistare l'oggetto
;*	value	 W	presente solo se type=-1,  la quantit
;*			che si acquista
;*	cyclex	 W	presente solo se type=2 o 3 o 4,  la coordinata x della stringa di selezione (o di input)
;*	cycley	 W	presente solo se type=2 o 3 o 4,  la coordinata y della stringa di selezione (o di input)
;*	cyclepun L	presente solo se type=2,  il pun. alla struttura che
;*			contiene i pun. alle stringhe selezionabili
;*	cyclesel L	presente solo se type=2,  il pun. alla word
;*			che contiene l'indice, all'interno della struttura
;*			puntata da cyclepun, della stringa selezionata
;*	keypun	 L	presente solo se type=3,  il pun. alla lista dei nomi
;*			dei tasti della tastiera, ordinati per scancode.
;*			Ogni nome  una stringa di 3 char, terminata con uno zero.
;*	keysel	 L	presente solo se type=3,  il pun. alla word
;*			che contiene lo scancode del tasto selezionato
;*	destpun  L	presente solo se type=4,  il pun. alla stringa null term. che contiene il
;*			valore iniziale della stringa di input e che, finito l'input,
;*			contiene i caratteri immessi dall'utente
;*	inputpun L	presente solo se type=4,  il pun. al buffer di input
;*	string	 B	null terminated string. Se type=1, deve essere
;*			costituita da un numero di spazi sufficiente
;*			a contenere il numero da stampare.


term_page0	dc.w	0	;Numero pagina
		dc.w	5,8	;Prima e ultima scelta del menu

		dc.l	tp0_s1, tp0_s2, tp0_s3, tp0_s4, tp0_s5, tp0_s6
		dc.l	tp0_s7, tp0_s8, tp0_s9
		dc.l	0

tp0_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

tp0_s2		dc.w	7, 6,0,0		;x, y, color, type
		dc.b	'YOU ARE CONNECTED TO',0

tp0_s3		dc.w	13,12,0,0
		dc.b	'TERMINAL NUMBER',0

tp0_s4		dc.w	100,12,1,1
		dc.l	terminal
		dc.b	'   ',0

tp0_s5		dc.w	37,24,1,0
		dc.b	'MAIN PAGE',0

tp0_s6		dc.w	3,40,1,0
		dc.b	'-',-4,0,' WEAPONS',0

tp0_s7		dc.w	3,48,1,0
		dc.b	'-',-4,0,' WEAPONS BOOST',0

tp0_s8		dc.w	3,56,1,0
		dc.b	'-',-4,0,' ACCESSORIES',0

tp0_s9		dc.w	3,64,1,0
		dc.b	'-',-4,0,' EXIT',0


;----------------------------------------------------------------------------

term_page1	dc.w	1	;Numero pagina
		dc.w	2,7	;Prima e ultima scelta del menu

		dc.l	tp1_s1, tp1_s2, tp1_s3, tp1_s4, tp1_s5
		dc.l	tp1_s6, tp1_s7, tp1_s8
		dc.l	0

tp1_s1		dc.w	0,0,0,0
		dc.b	-1,24,0

tp1_s2		dc.w	43,24,1,0
		dc.b	'WEAPONS',0

tp1_s3		dc.w	3,47,1,-1,4000,1
		dc.b	'-',-4,0,'FIREBALLS_____ ',-4,1,'_4000',0

tp1_s4		dc.w	3,54,1,-1,9000,1
		dc.b	'-',-4,0,'PLASMA_GUN____ ',-4,1,'_9000',0

tp1_s5		dc.w	3,61,1,-1,13000,1
		dc.b	'-',-4,0,'FLAME-THROWER_ ',-4,1,'13000',0

tp1_s6		dc.w	3,68,1,-1,20000,1
		dc.b	'-',-4,0,'MAGNETIC_GUN__ ',-4,1,'20000',0

tp1_s7		dc.w	3,75,1,-1,35000,1
		dc.b	'-',-4,0,'DEATH_MACHINE_ ',-4,1,'35000',0

tp1_s8		dc.w	3,82,1,-1,0,0
		dc.b	'-',-4,0,'EXIT',0

;----------------------------------------------------------------------------

term_page2	dc.w	2	;Numero pagina
		dc.w	2,8	;Prima e ultima scelta del menu

		dc.l	tp2_s1, tp2_s2, tp2_s3, tp2_s4, tp2_s5
		dc.l	tp2_s6, tp2_s7, tp2_s8, tp2_s9
		dc.l	0


tp2_s1		dc.w	0,0,0,0
		dc.b	-1,24,0

tp2_s2		dc.w	26,24,1,0
		dc.b	'WEAPONS BOOST',0

tp2_s3		dc.w	3,40,1,-1,1500,1
		dc.b	'-',-4,0,'SIMPLE_SHOT___ ',-4,1,'_1500',0

tp2_s4		dc.w	3,47,1,-1,2000,1
		dc.b	'-',-4,0,'FIREBALLS_____ ',-4,1,'_2000',0

tp2_s5		dc.w	3,54,1,-1,5000,1
		dc.b	'-',-4,0,'PLASMA_GUN____ ',-4,1,'_5000',0

tp2_s6		dc.w	3,61,1,-1,-1,1
		dc.b	'-',-4,0,'FLAME-THROWER_ ',-4,1,'__N_A ',0

tp2_s7		dc.w	3,68,1,-1,20000,1
		dc.b	'-',-4,0,'MAGNETIC_GUN__ ',-4,1,'20000',0

tp2_s8		dc.w	3,75,1,-1,20000,1
		dc.b	'-',-4,0,'DEATH_MACHINE_ ',-4,1,'20000',0

tp2_s9		dc.w	3,82,1,-1,0,0
		dc.b	'-',-4,0,'EXIT',0

;----------------------------------------------------------------------------

term_page3	dc.w	3	;Numero pagina
		dc.w	2,9	;Prima e ultima scelta del menu

		dc.l	tp3_s1, tp3_s2, tp3_s3, tp3_s4, tp3_s5, tp3_s6
		dc.l	tp3_s7, tp3_s8, tp3_s9, tp3_s10
		dc.l	0

tp3_s1		dc.w	0,0,0,0
		dc.b	-1,24,0

tp3_s2		dc.w	31,24,1,0
		dc.b	'ACCESSORIES',0

tp3_s3		dc.w	3,40,1,-1,200,10
		dc.b	'-',-4,0,' HEALTH_+10_____',-4,1,'_200',0

tp3_s4		dc.w	3,47,1,-1,150,10
		dc.b	'-',-4,0,' SHIELDS_+10____',-4,1,'_150',0

tp3_s5		dc.w	3,54,1,-1,200,100
		dc.b	'-',-4,0,' ENERGY_+100____',-4,1,'_200',0

tp3_s6		dc.w	3,61,1,-1,5000,1
		dc.b	'-',-4,0,' GREEN_KEY______',-4,1,'5000',0

tp3_s7		dc.w	3,68,1,-1,5000,1
		dc.b	'-',-4,0,' YELLOW_KEY_____',-4,1,'5000',0

tp3_s8		dc.w	3,75,1,-1,5000,1
		dc.b	'-',-4,0,' RED_KEY________',-4,1,'5000',0

tp3_s9		dc.w	3,82,1,-1,5000,1
		dc.b	'-',-4,0,' BLUE_KEY_______',-4,1,'5000',0

tp3_s10		dc.w	3,89,1,-1,0,0
		dc.b	'-',-4,0,' EXIT',0


;****************************************************************************

		cnop	0,4

TermPages	dc.l	term_page0,term_page1,term_page2,term_page3

;****************************************************************************
;*** Pagine del menu di configurazione

conf_page0	dc.w	0	;Numero pagina
		dc.w	2,7	;Prima e ultima scelta del menu

		dc.l	cp0_s1, cp0_s2, cp0_s3, cp0_s4, cp0_s5, cp0_s6
		dc.l	cp0_s7, cp0_s8
		dc.l	0

cp0_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

cp0_s2		dc.w	11,12,1,0
		dc.b	'CONFIGURATION MENU',0

cp0_s3		dc.w	24,24,0,0
		dc.b	'RETURN TO GAME',0

cp0_s4		dc.w	46,34,0,0
		dc.b	'WINDOW',0

cp0_s5		dc.w	49,44,0,0
		dc.b	'SOUND',0

cp0_s6		dc.w	40,54,0,0
		dc.b	'KEYBOARD',0

cp0_s7		dc.w	40,64,0,0
		dc.b	'CONTROLS',0

cp0_s8		dc.w	38,74,0,0
		dc.b	'QUIT GAME',0

;----------------------------------------------------------------------------
;* Menu di configurazione durante la presentazione

conf_page0p	dc.w	0	;Numero pagina
		dc.w	2,9	;Prima e ultima scelta del menu

		dc.l	cp0p_s1, cp0p_s2, cp0p_s3, cp0p_s4, cp0p_s5, cp0p_s6
		dc.l	cp0p_s7, cp0p_s8, cp0p_s9, cp0p_s10
		dc.l	0

cp0p_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

cp0p_s2		dc.w	11,12,1,0
		dc.b	'CONFIGURATION MENU',0

cp0p_s3		dc.w	35,24,0,0
		dc.b	'START GAME',0

cp0p_s4		dc.w	46,34,0,0
		dc.b	'WINDOW',0

cp0p_s5		dc.w	49,44,0,0
		dc.b	'SOUND',0

cp0p_s6		dc.w	40,54,0,0
		dc.b	'KEYBOARD',0

cp0p_s7		dc.w	40,64,0,0
		dc.b	'CONTROLS',0

cp0p_s8		dc.w	29,74,0,0
		dc.b	'GAME OPTIONS',0

cp0p_s9		dc.w	43,84,0,0
		dc.b	'CREDITS',0

cp0p_s10	dc.w	38,94,0,0
		dc.b	'QUIT GAME',0

;----------------------------------------------------------------------------

conf_page1	dc.w	1	;Numero pagina
		dc.w	2,5	;Prima e ultima scelta del menu

		dc.l	cp1_s1, cp1_s2, cp1_s3, cp1_s4, cp1_s5
		dc.l	cp1_s6
		dc.l	0

cp1_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

cp1_s2		dc.w	5,12,1,0
		dc.b	'WINDOW CONFIGURATION',0

cp1_s3		dc.w	4,34,0,2,82,34
		dc.l	windowsizelist,WindowSize
		dc.b	'WINDOW_SIZE',0

cp1_s4		dc.w	4,44,0,2,94,44
		dc.l	pixelsizelist,PixelSize
		dc.b	'PIXEL_SIZE',0

cp1_s5		dc.w	4,54,0,2,94,54
		dc.l	onofflist,SightState
		dc.b	'SIGHT',0

cp1_s6		dc.w	38,74,0,0
		dc.b	'MAIN PAGE',0


windowsizelist	dc.l	ws0,ws1,ws2,ws3,ws4,ws5,ws6,ws7,0
ws0		dc.b	'_96*60',0
ws1		dc.b	'128*80',0
ws2		dc.b	'160*100',0
ws3		dc.b	'192*120',0
ws4		dc.b	'224*140',0
ws5		dc.b	'256*160',0
ws6		dc.b	'288*180',0
ws7		dc.b	'320*200',0

pixelsizelist	dc.l	ps0,ps1,ps2,ps3,0
ps0		dc.b	'1*1',0
ps1		dc.b	'2*1',0
ps2		dc.b	'1*2',0
ps3		dc.b	'2*2',0

;----------------------------------------------------------------------------

conf_page2	dc.w	2	;Numero pagina
		dc.w	2,5	;Prima e ultima scelta del menu

		dc.l	cp2_s1, cp2_s2, cp2_s3, cp2_s4, cp2_s5, cp2_s6
		dc.l	0

cp2_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

cp2_s2		dc.w	8,12,1,0
		dc.b	'SOUND CONFIGURATION',0

cp2_s3		dc.w	4,24,0,2,118,24
		dc.l	musicvollist,MusicVolume
		dc.b	'MUSIC_VOLUME',0

cp2_s4		dc.w	4,34,0,2,106,34
		dc.l	onofflist,MusicOnOff
		dc.b	'MUSIC_STATE',0

cp2_s5		dc.w	4,44,0,2,106,44
		dc.l	onofflist,FilterState
		dc.b	'AUDIO FILTER',0

cp2_s6		dc.w	38,54,0,0
		dc.b	'MAIN PAGE',0


musicvollist	dc.l	mv1,mv2,mv3,mv4,0
mv1		dc.b	'1',0
mv2		dc.b	'2',0
mv3		dc.b	'3',0
mv4		dc.b	'4',0

onofflist	dc.l	fl0,fl1,0
fl0		dc.b	'OFF',0
fl1		dc.b	'_ON',0

;----------------------------------------------------------------------------

conf_page3	dc.w	3	;Numero pagina
		dc.w	2,15	;Prima e ultima scelta del menu

		dc.l	cp3_s1, cp3_s2, cp3_s3, cp3_s4, cp3_s5
		dc.l	cp3_s6, cp3_s7, cp3_s8, cp3_s9, cp3_s10
		dc.l	cp3_s11, cp3_s12, cp3_s13, cp3_s14, cp3_s15, cp3_s16
		dc.l	0

cp3_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

cp3_s2		dc.w	11,0,1,0
		dc.b	'KEYS CONFIGURATION',0

cp3_s3		dc.w	4,12,0,3,106,12
		dc.l	keylist,ForwardKey
		dc.b	'FORWARDS',0

cp3_s4		dc.w	4,20,0,3,106,20
		dc.l	keylist,BackwardKey
		dc.b	'BACKWARDS',0

cp3_s5		dc.w	4,28,0,3,106,28
		dc.l	keylist,RotateLeftKey
		dc.b	'ROTATE LEFT',0

cp3_s6		dc.w	4,36,0,3,106,36
		dc.l	keylist,RotateRightKey
		dc.b	'ROTATE RIGHT',0

cp3_s7		dc.w	4,44,0,3,106,44
		dc.l	keylist,SideLeftKey
		dc.b	'SIDESTEP LEFT',0

cp3_s8		dc.w	4,52,0,3,106,52
		dc.l	keylist,SideRightKey
		dc.b	'SIDESTEP RIGHT',0

cp3_s9		dc.w	4,60,0,3,106,60
		dc.l	keylist,FireKey
		dc.b	'FIRE',0

cp3_s10		dc.w	4,68,0,3,106,68
		dc.l	keylist,AccelKey
		dc.b	'ACCELERATION',0

cp3_s11		dc.w	4,76,0,3,106,76
		dc.l	keylist,ForceSideKey
		dc.b	'FORCE SIDESTEP',0

cp3_s12		dc.w	4,84,0,3,106,84
		dc.l	keylist,LookUpKey
		dc.b	'LOOK UP',0

cp3_s13		dc.w	4,92,0,3,106,92
		dc.l	keylist,ResetLookKey
		dc.b	'RESET LOOK',0

cp3_s14		dc.w	4,100,0,3,106,100
		dc.l	keylist,LookDownKey
		dc.b	'LOOK DOWN',0

cp3_s15		dc.w	4,108,0,3,106,108
		dc.l	keylist,SwitchKey
		dc.b	'SWITCH',0

cp3_s16		dc.w	38,120,0,0
		dc.b	'MAIN PAGE',0



keylist		dc.b	'_`_',0		;0
		dc.l	0		;1	1
		dc.l	0		;2	2
		dc.l	0		;3	3
		dc.l	0		;4	4
		dc.l	0		;5	5
		dc.l	0		;6	6
		dc.b	'_7_',0		;7
		dc.b	'_8_',0		;8
		dc.b	'_9_',0		;9
		dc.b	'_0_',0		;A
		dc.b	'_-_',0		;B
		dc.b	'_=_',0		;C
		dc.b	'_\_',0		;D
		dc.b	'___',0		;E
		dc.b	'NP0',0		;F
		dc.b	'_Q_',0		;10
		dc.b	'_W_',0		;11
		dc.b	'_E_',0		;12
		dc.b	'_R_',0		;13
		dc.b	'_T_',0		;14
		dc.b	'_Y_',0		;15
		dc.b	'_U_',0		;16
		dc.b	'_I_',0		;17
		dc.b	'_O_',0		;18
		dc.l	0		;19	P
		dc.b	'_[_',0		;1A
		dc.b	'_]_',0		;1B
		dc.b	'___',0		;1C
		dc.b	'NP1',0		;1D
		dc.b	'NP2',0		;1E
		dc.b	'NP3',0		;1F
		dc.b	'_A_',0		;20
		dc.b	'_S_',0		;21
		dc.b	'_D_',0		;22
		dc.b	'_F_',0		;23
		dc.b	'_G_',0		;24
		dc.b	'_H_',0		;25
		dc.b	'_J_',0		;26
		dc.b	'_K_',0		;27
		dc.b	'_L_',0		;28
		dc.b	'_;_',0		;29
		dc.b	'_''_',0	;2A
		dc.b	'___',0		;2B
		dc.b	'___',0		;2C
		dc.b	'NP4',0		;2D
		dc.b	'NP5',0		;2E
		dc.b	'NP6',0		;2F
		dc.b	'_<_',0		;30
		dc.b	'_Z_',0		;31
		dc.b	'_X_',0		;32
		dc.b	'_C_',0		;33
		dc.b	'_V_',0		;34
		dc.b	'_B_',0		;35
		dc.b	'_N_',0		;36
		dc.b	'_M_',0		;37
		dc.b	'_,_',0		;38
		dc.b	'_._',0		;39
		dc.b	'_/_',0		;3A
		dc.b	'___',0		;3B
		dc.b	'NP.',0		;3C
		dc.b	'NP7',0		;3D
		dc.b	'NP8',0		;3E
		dc.b	'NP9',0		;3F
		dc.b	'SPC',0		;40
		dc.b	'___',0		;41
		dc.l	0		;42	TAB
		dc.b	'ENT',0		;43
		dc.b	'RET',0		;44
		dc.l	0		;45	ESC
		dc.b	'DEL',0		;46
		dc.b	'___',0		;47
		dc.b	'___',0		;48
		dc.b	'___',0		;49
		dc.l	0		;4A	NP-
		dc.b	'___',0		;4B
		dc.b	'_UP',0		;4C
		dc.b	'DWN',0		;4D
		dc.b	'RGT',0		;4E
		dc.b	'LFT',0		;4F
		dc.l	0		;50	F1
		dc.l	0		;51	F2
		dc.l	0		;52	F3
		dc.l	0		;53	F4
		dc.l	0		;54	F5
		dc.l	0		;55	F6
		dc.b	'_F7',0		;56
		dc.b	'_F8',0		;57
		dc.b	'_F9',0		;58
		dc.b	'F10',0		;59
		dc.l	0		;5A	NP{
		dc.l	0		;5B	NP}
		dc.l	0		;5C	NP/
		dc.l	0		;5D	NP*
		dc.l	0		;5E	NP+
		dc.b	'HLP',0		;5F
		dc.b	'LSH',0		;60
		dc.b	'RSH',0		;61
		dc.b	'___',0		;62
		dc.b	'CTR',0		;63
		dc.b	'LAL',0		;64
		dc.b	'RAL',0		;65
		dc.b	'LAM',0		;66
		dc.b	'RAM',0		;67

;----------------------------------------------------------------------------

conf_page4	dc.w	4	;Numero pagina
		dc.w	4,12	;Prima e ultima scelta del menu

		dc.l	cp4_s1, cp4_s2, cp4_s3, cp4_s4, cp4_s5
		dc.l	cp4_s6, cp4_s7, cp4_s8, cp4_s9, cp4_s10
		dc.l	cp4_s11, cp4_s12, cp4_s13
		dc.l	0

cp4_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

cp4_s2		dc.w	2,2,1,0
		dc.b	'CONTROL CONFIGURATION',0

cp4_s3		dc.w	1,54,1,0
		dc.b	'ACCEL. KEY NOT PRESSED',0

cp4_s4		dc.w	12,84,1,0
		dc.b	'ACCEL. KEY PRESSED',0

cp4_s5		dc.w	4,14,0,2,76,14
		dc.l	ctrllist,ActiveControl
		dc.b	'CONTROL',0

cp4_s6		dc.w	4,22,0,2,118,22
		dc.l	mousesenslist,MouseSensitivity
		dc.b	'MOUSE_SENSITIVITY',0

cp4_s7		dc.w	4,34,0,2,100,34
		dc.l	inertialist,WalkInertia
		dc.b	'WALKING INERTIA',0

cp4_s8		dc.w	4,42,0,2,100,42
		dc.l	inertialist,RotInertia
		dc.b	'ROTATING INERTIA',0

cp4_s9		dc.w	4,64,0,2,118,64
		dc.l	walkspeedlist,WalkSpeed
		dc.b	'WALKING SPEED',0

cp4_s10		dc.w	4,72,0,2,118,72
		dc.l	rotspeedlist,RotSpeed
		dc.b	'ROTATING SPEED',0

cp4_s11		dc.w	4,94,0,2,118,94
		dc.l	walkspeedlist,PWalkSpeed
		dc.b	'WALKING SPEED',0

cp4_s12		dc.w	4,102,0,2,118,102
		dc.l	rotspeedlist,PRotSpeed
		dc.b	'ROTATING SPEED',0

cp4_s13		dc.w	38,120,0,0
		dc.b	'MAIN PAGE',0


ctrllist	dc.l	ctr0,ctr1,0
ctr0		dc.b	'KEYBOARD',0
ctr1		dc.b	'___MOUSE',0

mousesenslist	dc.l	ms0,ms1,ms2,ms3,ms4,ms5,ms6,ms7,ms8,0
ms0		dc.b	'0',0
ms1		dc.b	'1',0
ms2		dc.b	'2',0
ms3		dc.b	'3',0
ms4		dc.b	'4',0
ms5		dc.b	'5',0
ms6		dc.b	'6',0
ms7		dc.b	'7',0
ms8		dc.b	'8',0

walkspeedlist	dc.l	wsp0,wsp1,wsp2,wsp3,0
wsp0		dc.b	'1',0
wsp1		dc.b	'2',0
wsp2		dc.b	'3',0
wsp3		dc.b	'4',0

rotspeedlist	dc.l	rs0,rs1,rs2,rs3,rs4,rs5,0
rs0		dc.b	'1',0
rs1		dc.b	'2',0
rs2		dc.b	'3',0
rs3		dc.b	'4',0
rs4		dc.b	'5',0
rs5		dc.b	'6',0

inertialist	dc.l	is0,is1,is2,0
is0		dc.b	'HIGH',0
is1		dc.b	'_MID',0
is2		dc.b	'_LOW',0

;----------------------------------------------------------------------------

conf_page5	dc.w	5	;Numero pagina
		dc.w	3,6	;Prima e ultima scelta del menu

		dc.l	cp5_s1, cp5_s2, cp5_s3, cp5_s4, cp5_s5
		dc.l	cp5_s6, cp5_s7
		dc.l	0

cp5_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

cp5_s2		dc.w	29,12,1,0
		dc.b	'GAME OPTIONS',0

cp5_s3		dc.w	32,24,0,0
		dc.b	'ACCESS CODE',0

cp5_s4		dc.w	16,34,0,4,16,34
		dc.l	LevelCodeASC,inbuffer
		dc.b	0

cp5_s5		dc.w	15,46,0,0
		dc.b	'RESET ACCESS CODE',0

cp5_s6		dc.w	11,56,0,0
		dc.b	'SAVE CONFIGURATION',0

cp5_s7		dc.w	38,74,0,0
		dc.b	'MAIN PAGE',0

;----------------------------------------------------------------------------

		cnop	0,4

ConfPages	dc.l	conf_page0,conf_page1,conf_page2,conf_page3
		dc.l	conf_page4,conf_page5

;****************************************************************************
;* Pagina di input codice protezione

    IFEQ 1	;*** !!!PROTEZIONE!!!

prot_page	dc.w	0	;Numero pagina
		dc.w	5,9	;Prima e ultima scelta del menu

		dc.l	pp0_s1, pp0_s2, pp0_s3, pp0_s4, pp0_s5
		dc.l	pp0_s6,pp0_s7, pp0_s8, pp0_s9, pp0_s10
		dc.l	0

pp0_s1		dc.w	0,0,0,0
		dc.b	-1,0,0

pp0_s2		dc.w	9,12,1,0
		dc.b	'ENTER SECURITY CODE',0

pp0_s3		dc.w	48,21,1,1
		dc.l	SecCodeRow
		dc.b	'  ',0

pp0_s4		dc.w	64,21,1,0
		dc.b	'-',0

pp0_s5		dc.w	74,21,1,0
		dc.b	' ',0

pp0_s6		dc.w	49,36,0,2,73,36
		dc.l	protcharlist,ProtCode1
		dc.b	'1_-_',0

pp0_s7		dc.w	49,46,0,2,73,46
		dc.l	protcharlist,ProtCode2
		dc.b	'2_-_',0

pp0_s8		dc.w	49,56,0,2,73,56
		dc.l	protcharlist,ProtCode3
		dc.b	'3_-_',0

pp0_s9		dc.w	49,66,0,2,73,66
		dc.l	protcharlist,ProtCode4
		dc.b	'4_-_',0

pp0_s10		dc.w	58,86,0,0
		dc.b	'OK',0


protcharlist	dc.l	pr0,pr1,pr2,pr3,pr4,pr5,pr6,pr7,pr8,pr9,0
pr0		dc.b	'a',0
pr1		dc.b	'b',0
pr2		dc.b	'c',0
pr3		dc.b	'd',0
pr4		dc.b	'e',0
pr5		dc.b	'f',0
pr6		dc.b	'g',0
pr7		dc.b	'h',0
pr8		dc.b	'i',0
pr9		dc.b	'j',0

    ENDIF	;*** !!!FINE PROTEZIONE!!!

;****************************************************************************

clearterminal	dc.b	-1,0,0

askquit		dc.b	-1,0,'REALLY QUIT ? (Y/N)',0

badcode		dc.b	'BAD ACCESS CODE !',-2,127,-3,90,0


	;Tabella di conversione da scancode a ascii.
	;Basta accedere alla tabella usando lo scancode come indice.

keytable	dc.b	00,49,50,51,52,53,54,55,56,57,48,45,43,92,00,48	;$00
		dc.b	81,87,69,82,84,89,85,73,79,80,91,93,00,49,50,51	;$10
		dc.b	65,83,68,70,71,72,74,75,76,00,00,00,00,52,53,54 ;$20
		dc.b	00,90,88,67,86,66,78,77,44,46,47,00,46,55,56,57 ;$30
		dc.b	32,08,00,00,13,00,00,00,00,00,45,00,00,00,00,00 ;$40
		dc.b	00,00,00,00,00,00,00,00,00,00,00,00,00,00,43,00	;$50
		dc.b	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00	;$60


		cnop	0,4


;****************************************************************************

	section	__MERGED,BSS

		cnop	0,4

		xdef	terminal,Protection

terminal	ds.l	1	;Se<>0, contiene il num. del terminale attivo
				;Se<0,  il menu di configurazione

CurrentPage	ds.l	1	;Pagina corrente
CurrentPageNum	ds.w	1	;Numero pagina corrente
InitPageInput	ds.w	1	;Se<>0, deve inizializzare l'input sulla pagina

ChoiceItem1	ds.w	1	;Prima scelta del menu
ChoiceItem2	ds.w	1	;Ultima scelta del menu

Protection	ds.b	1	;Se=TRUE,  attivo l'input del codice di protezione

		ds.b	3	;Usato per allineare

		xdef	WindowSize,PixelSize,SightState
		xdef	MusicVolume,FilterState,MusicOnOff

WindowSize	ds.w	1
PixelSize	ds.w	1
SightState	ds.w	1
MusicVolume	ds.w	1
FilterState	ds.w	1
MusicOnOff	ds.w	1
WalkSpeed	ds.w	1
RotSpeed	ds.w	1
PWalkSpeed	ds.w	1
PRotSpeed	ds.w	1
WalkInertia	ds.w	1
RotInertia	ds.w	1

		xdef	SecCodeRow,SecCodeCol,InSecCode

;*** !!! ATTENZIONE !!! non spostare i seguenti dati

SecCodeRow	ds.l	1
SecCodeCol	ds.l	1
ProtCode1	ds.w	1
ProtCode2	ds.w	1
ProtCode3	ds.w	1
ProtCode4	ds.w	1
InSecCode	ds.l	1

inbuffer	ds.b	24	;Buffer di input

		cnop	0,4
