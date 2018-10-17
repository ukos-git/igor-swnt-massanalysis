#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

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

/// deprecated due to better solution using CoordinateFinder() with Extract
Function/WAVE CoordinateFinderV1(coordinates, xmin, xmax, ymin, ymax, [verbose])
	WAVE coordinates
	Variable xmin, xmax, ymin, ymax, verbose

	variable dim0, dim1
	variable Pstart, Pend, Qstart, Qend

	verbose = ParamIsDefault(verbose) ? 0 : !!verbose

	// get X coordinates
	dim0 = DimSize(coordinates, 0)
	Make/FREE/N=(dim0) indices = p
	Duplicate/FREE/R=[][0] coordinates, coordinateX
	Duplicate/FREE/R=[][1] coordinates, coordinateY
	Sort/R coordinateX, indices, coordinateX, coordinateY
	Pend = ceil(FindLevelWrapper(coordinateX, xmax, verbose = 0))
	if(Pend < 0)
		Pend = 0
	endif
	Pend = dim0 - Pend - 1
	Sort coordinateX, indices, coordinateX, coordinateY
	Pstart = ceil(FindLevelWrapper(coordinateX, xmin, verbose = 0))
	if(Pstart < 0)
		Pstart = 0
	endif

	// get Y coordinates
	dim1 = Pend - Pstart + 1
	Duplicate/FREE/R=[Pstart, Pend] coordinateX, coordinateX1
	Duplicate/FREE/R=[Pstart, Pend] coordinateY, coordinateY1
	Duplicate/FREE/R=[Pstart, Pend] indices,     indices1
	if(verbose)
		print "between", xmin, "and", xmax, ":", indices1
	endif
	Sort/R coordinateY1, indices1, coordinateX1, coordinateY1
	Qend = ceil(FindLevelWrapper(coordinateY1, ymax, verbose = 0))
	if(Qend < 0)
		Qend = 0
	endif
	Qend = dim1 - Qend - 1
	Sort coordinateY1, indices1, coordinateX1, coordinateY1
	Qstart = ceil(FindLevelWrapper(coordinateY1, ymin, verbose = 0))
	if(Qstart < 0)
		Qstart = 0
	endif

	Duplicate/FREE/R=[Qstart, Qend] indices1, indices2
	if(verbose)
		print "between", ymin, "and", ymax, ":", indices2
	endif

	return indices2
End

Function/WAVE CoordinateFinderXYrange(coordinates, xmin, xmax, ymin, ymax, [verbose])
	WAVE coordinates
	Variable xmin, xmax, ymin, ymax, verbose

	verbose = ParamIsDefault(verbose) ? 0 : !!verbose

	Duplicate/FREE/R=[][0] coordinates, coordinateX
	Duplicate/FREE/R=[][1] coordinates, coordinateY

	Extract/INDX/FREE coordinateX, indicesX, coordinateX > xmin && coordinateX < xmax
	Extract/INDX/FREE coordinateY, indicesY, coordinateY > ymin && coordinateY < ymax

	Make/FREE/N=0 indicesXY
	Concatenate {indicesX, indicesY}, indicesXY

	FindDuplicates/DN=indices indicesXY

	if(verbose)
		print indices
	endif
	return indices
End

Function CoordinateFinderXYZ(coordinates, xVal, yVal, zVal, [verbose, accuracy])
	WAVE coordinates
	Variable xVal, yVal, zVal, verbose
	Variable accuracy

	verbose = ParamIsDefault(verbose) ? 0 : !!verbose
	accuracy = ParamIsDefault(accuracy) ? 0.5 : abs(accuracy)

	Duplicate/FREE/R=[][0] coordinates, coordinateX
	Duplicate/FREE/R=[][1] coordinates, coordinateY
	Duplicate/FREE/R=[][2] coordinates, coordinateZ

	coordinateX = round(coordinateX[p] / accuracy) * accuracy
	coordinateY = round(coordinateY[p] / accuracy) * accuracy
	coordinateZ = round(coordinateZ[p] / accuracy) * accuracy
	xVal = round(xVal / accuracy) * accuracy
	yVal = round(yVal / accuracy) * accuracy
	zVal = round(zVal / accuracy) * accuracy

	Extract/INDX/FREE coordinateX, indicesX, (coordinateX[p] == xVal)
	Extract/INDX/FREE coordinateY, indicesY, (coordinateY[p] == yVal)
	Extract/INDX/FREE coordinateZ, indicesZ, (coordinateZ[p] == zVal)

	if(!DimSize(indicesX, 0) || !DimSize(indicesY, 0) || !DimSize(indicesZ, 0))
		return NaN
	endif

	Make/FREE/N=0 indicesXYZ
	Concatenate {indicesX, indicesY, indicesZ}, indicesXYZ

	Sort indicesXYZ, indicesXYZ
	Redimension/N=(numpnts(indicesXYZ))/E=1 indicesXYZ

	Extract/FREE indicesXYZ, indices, (p > 1 && (indicesXYZ[p] == indicesXYZ[p - 1]) && (indicesXYZ[p] == indicesXYZ[p - 2]))
	if(!DimSize(indices, 0))
		return NaN
	endif

	if(verbose)
		print "CoordinateFinderXYZ: found the following indices in the input wave:"
		print indices
	endif
	return indices[0]
End
