UWORD PickToolData[] =
{
	0x0000,0x0800,0x0000,0x0800,0x0000,0x0800,0x0000,0x0800,
	0x393a,0x4800,0x2522,0x8800,0x3923,0x0800,0x2122,0x8800,
	0x213a,0x4800,0x0000,0x0800,0x0000,0x0800,0xffff,0xf800,
	0xffff,0xf000,0x8000,0x0000,0x8000,0x0000,0x8000,0x0000,
	0x8000,0x0000,0x8000,0x0000,0x8000,0x0000,0x8000,0x0000,
	0x8000,0x0000,0x8000,0x0000,0x8000,0x0000,0x0000,0x0000,
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
	0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
};


struct Image PickToolImage = {
	0x0,0x0, 0x0015, 0x000c, 0x0003, (UWORD *)PickToolData, 0x07,0x0, NULL
};