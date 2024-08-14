
// cycle tables, used to 

package cpu

// base cycles, reduced according to following tables
@(private)
cycles_65c816 := [256]u32 {
    8, 7, 8, 5, 7, 4, 7, 7, 3, 3, 2, 4, 8, 5, 8, 6,
    2, 7, 6, 8, 7, 5, 8, 7, 2, 6, 2, 2, 8, 6, 9, 6,
    6, 7, 8, 5, 4, 4, 7, 7, 4, 3, 2, 5, 5, 5, 8, 6,
    2, 7, 6, 8, 5, 5, 8, 7, 2, 6, 2, 2, 6, 6, 9, 6,
    7, 7, 2, 5, 7, 4, 7, 7, 4, 3, 2, 3, 3, 5, 8, 6,
    2, 7, 6, 8, 7, 5, 8, 7, 2, 6, 4, 2, 4, 6, 9, 6,
    6, 7, 6, 5, 4, 4, 7, 7, 5, 3, 2, 6, 5, 5, 8, 6,
    2, 7, 6, 8, 5, 5, 8, 7, 2, 6, 5, 2, 6, 6, 9, 6,
    3, 7, 4, 5, 4, 4, 4, 7, 2, 3, 2, 3, 5, 5, 5, 6,
    2, 7, 6, 8, 5, 5, 5, 7, 2, 6, 2, 2, 5, 6, 6, 6,
    3, 7, 3, 5, 4, 4, 4, 7, 2, 3, 2, 4, 5, 5, 5, 6,
    2, 7, 6, 8, 5, 5, 5, 7, 2, 6, 2, 2, 6, 6, 6, 6,
    3, 7, 3, 5, 4, 4, 7, 7, 2, 3, 2, 3, 5, 5, 8, 6,
    2, 7, 6, 8, 6, 5, 8, 7, 2, 6, 4, 3, 6, 6, 9, 6,
    3, 7, 3, 5, 4, 4, 7, 7, 2, 3, 2, 3, 5, 5, 8, 6,
    2, 7, 6, 8, 5, 5, 8, 7, 2, 6, 5, 2, 8, 6, 9, 6,
}

// cycle reduction when M flag == 1
@(private)
decCycles_flagM := [256]u32 {
	0, 1, 0, 1, 2, 1, 2, 1, 0, 1, 0, 0, 2, 1, 2, 1,
	0, 1, 1, 1, 2, 1, 2, 1, 0, 1, 0, 0, 2, 1, 2, 1,
	0, 1, 0, 1, 1, 1, 2, 1, 0, 1, 0, 0, 1, 1, 2, 1,
	0, 1, 1, 1, 1, 1, 2, 1, 0, 1, 0, 0, 1, 1, 2, 1,
	0, 1, 0, 1, 0, 1, 2, 1, 1, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 1, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 0, 1, 1, 1, 2, 1, 1, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 1, 1, 1, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1,
	0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1,
	0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1,
	0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1,
	0, 1, 0, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 1, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 0, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
	0, 1, 1, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 2, 1,
}

// cycle reduction when X flag == 1
@(private)
decCycles_flagX := [256]u32 {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0,
	0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0,
	0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 2, 1, 2, 0,
	1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0,
	1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0,
}

// cycle increase when DL (lo of D register) != 00
@(private)
incCycles_regDL_not00 := [256]u32 {
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
}


// cycle increase when px (page crossing) occured
@(private)
incCycles_PageCross := [256]u32 {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0,
}

