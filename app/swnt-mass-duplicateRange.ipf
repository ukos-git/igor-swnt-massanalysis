#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function SMAdisplayOriginal([numPLEM])
	Variable numPLEM

	Variable xStart, xEnd, yStart, yEnd
	
	if(ParamIsDefault(numPLEM))
		numPLEM = SMAgetOriginalFromMarquee()
	endif

	// save graph axis settings
	GetAxis/Q bottom
	if(!!V_flag)
		print "SMAdisplayOriginal: Error getting bottom axis in top Graph"
		return -1
	endif
	yStart = V_min
	yEnd = V_max
	GetAxis/Q left
	if(!!V_flag)
		print "SMAdisplayOriginal: Error getting left axis in top Graph"
		return -1
	endif
	xStart = V_min
	xEnd = V_max

	Variable offsetX, offsetY
	SMAgetOffset(offsetX, offsetY)

	Plemd2displaybynum(numPLEM)

	// copy graph axis settings
	GetAxis/Q bottom
	if(!!V_flag)
		print "SMAdisplayOriginal: Error getting bottom axis in top Graph"
		return -1
	endif
	SetAxis bottom, yStart + offsetY, yEnd + offsetY
	GetAxis/Q left
	if(!!V_flag)
		print "SMAdisplayOriginal: Error getting left axis in top Graph"
		return -1
	endif
	SetAxis left, xStart + offsetX, xEnd + offsetX
End

// get center coordinate from marquee and display search the image that matches those coordinates closest
Function SMAgetOriginalFromMarquee()
	Variable centerX, centerY

	GetMarquee left, bottom //V_bottom, V_top, V_left and V_right
	if (V_flag == 0)
		return -1
	endif
	centerY = V_left + (V_left - V_right) / 2
	centerX = V_bottom + (V_bottom - V_top) / 2

	return SMAgetFirstImage(centerX, centerY, 150)
End

// returns the index of the image where the specified coordinates are located
Function SMAgetFirstImage(centerX, centerY, centerZ)
	Variable centerX, centerY, centerZ
	Variable accuracy = 0

	Variable index

	WAVE coordinates = PLEMd2getcoordinates(forceRenew=1)
	do
		accuracy += 10
		WAVE indices = CoordinateFinderXYZ(coordinates, centerX, centerY, centerZ, accuracy = accuracy, verbose = 0)
		index = indices[0]
	while(!!numtype(index) && accuracy < 1e4)

	if(index > PLEMd2getmapsavailable())
		print "SMAgetFirstImage: Index out of range"
		return -1
	endif

	if(!!numtype(index))
		return -1
	endif

	return index
End

Function SMADuplicateRangeFromMarquee()
	String win

	WAVE wv = SMAduplicateRange(SMAgetOriginalFromMarquee())
	if(!WaveExists(wv))
		return 1
	endif

	win = "win_" + NameOfWave(wv)
	Display/N=$win as win
	AppendImage wv
	ModifyGraph width={Plan,1,bottom,left}
	ModifyImage ''#0 ctab= {*,*,RedWhiteBlue256,0}
End

// read globally set offset variables and give instructions on how to update them.
// set the input variables to their global values.
Function SMAgetOffset(offsetX, offsetY)
	Variable &offsetX, &offsetY

	// manually set using: SMAtasksZeroToCursor()

	NVAR/Z gOffsetX = root:offsetX
	if(NVAR_Exists(gOffsetX))
		offsetX = gOffsetX
	endif

	NVAR/Z gOffsetY = root:offsetY
	if(NVAR_Exists(gOffsetY))
		offsetY = gOffsetY
	endif
End

Function SMAsetOffset(offsetX, offsetY)
	Variable offsetX, offsetY

	NVAR/Z gOffsetX = root:offsetX
	if(!NVAR_Exists(gOffsetX))
		Variable/G root:offsetX
		NVAR gOffsetX = root:offsetX
	endif

	NVAR/Z gOffsetY = root:offsetY
	if(!NVAR_Exists(gOffsetY))
		Variable/G root:offsetY
		NVAR gOffsetY = root:offsetY
	endif

	gOffsetX = offsetX
	gOffsetY = offsetY
End

Function SMAaddOffset(addX, addY)
	Variable addX, addY

	Variable offsetX, offsetY
	SMAgetOffset(offsetX, offsetY)

	SMAsetOffset(offsetX + addX, offsetY + addY)
End

Function/WAVE SMAduplicateRange(FirstImage, [outputName])
	Variable FirstImage

	Variable i, numPLEM
	Variable offsetX, offsetY

	String outputName
	Variable dim2 = 1
	Variable StackSize = 24
	Variable zStep = 1

	if(ParamIsDefault(outputName))
		outputName = "imageRange"
		outputName = UniqueName(outputName, 1, 0)
	endif

	// get range from axis settings (not intuitive for marquee!)
	GetAxis/Q left
	if(!!V_flag)
		return $""
	endif
	Variable xstart = V_min
	Variable xend = V_max
	GetAxis/Q bottom
	if(!!V_flag)
		return $""
	endif
	Variable ystart = V_min
	Variable yend = V_max

	SMAorderAsc(xStart, xEnd)
	SMAorderAsc(yStart, yEnd)

	SMAgetOffset(offsetX, offsetY)

	Struct PLEMd2stats stats
	PLEMd2statsLoad(stats, PLEMd2strPLEM(FirstImage))

	WAVE imagestack = getTopWindowImage()
	if(WaveExists(imagestack))
		dim2 = DimSize(imagestack, 2)
	endif

	// prepare output wave container
	Duplicate/R=(yStart + offsetY, yEnd + offsetY)(xStart + offsetX, xEnd + offsetX) stats.wavPLEM $outputName/WAVE=wv
	Redimension/N=(-1, -1, dim2) wv
	// set z Axis
	WAVE zAxis = PLEMd2getCoordinates()
	if(FirstImage + StackSize < PLEMd2getMapsAvailable())
		zStep = zAxis[FirstImage][2] - zAxis[FirstImage + StackSize][2]
	endif
	SetScale/P z, zAxis[FirstImage][2], zStep, wv
	// set x,y Axis offset
	AddWaveScaleOffset(wv, offsetY, offsetX)

	// write output wave
	for(i = 0; i < dim2; i += 1)
		numPLEM = FirstImage + i * StackSize
		PLEMd2statsLoad(stats, PLEMd2strPLEM(numPLEM))
		Duplicate/FREE/R=(yStart + offsetY, yEnd + offsetY)(xStart + offsetX, xEnd + offsetX) stats.wavPLEM image
		wv[][][i] = image[p][q]
	endfor

	return wv
End
