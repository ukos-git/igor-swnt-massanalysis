#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "utilities-globalvar"

Function SMAorderAsc(minimum, maximum)
	Variable &minimum, &maximum

	Variable temp

	if(minimum < maximum)
		return 0
	endif
	temp = minimum
	minimum = maximum
	maximum = temp

	return 0
End

Function FindLevelWrapper(wv, level, [verbose])
	WAVE wv
	variable level, verbose

	verbose = ParamIsDefault(verbose) ? 0 : !!verbose

	FindLevel/Q/P wv, level
	if(V_flag == 1)
		if(verbose)
			print "no level found"
		endif
		return -1
	endif
	if(verbose)
		print "level found between ", floor(V_levelX), " and ", ceil(V_levelX), " in wave ", NameOfWave(wv)
	endif
	return V_levelX
End
