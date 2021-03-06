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
		WAVE/Z indices = CoordinateFinderXYZ(coordinates, centerX, centerY, centerZ, accuracy = accuracy, verbose = 0)
		if(!WaveExists(indices))
			continue
		endif
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

Function SMADuplicateRangeFromCoordinates(coordinates)
	WAVE coordinates

	String name, win, strPath
	Variable i
	Variable numCoordinates = DimSize(coordinates, 0)
	String coordinatesName = NameOfWave(coordinates)
	String experimentName = IgorInfo(1)

	if(DimSize(coordinates, 1) < 3)
		Abort "Need at least 2 coordinates"
	endif

	PathInfo home
	strPath = S_Path + experimentName
	NewPath/C/O/Z images, strPath

	for(i = 0; i < numCoordinates; i += 1)
		sprintf name, "%s_image%03d", coordinatesName, i
		SMADisplayCoordinates(coordinates[i][0], coordinates[i][1], range = 3) // set axis for SMAduplicateRange
		DoUpdate/W=win_SMAimageStack
		WAVE wv = SMAduplicateRange(SMAgetFirstImage(coordinates[i][0], coordinates[i][1], coordinates[i][2]), outputName = name)
		Save/C/O/P=images wv

		// create image for standard range
		Redimension/U/I wv
		Display/N=temp
		win = S_name
		AppendImage/W=$win wv
		ModifyImage/W=$win $"#0" ctab= {0,*,YellowHot,0}
		ModifyGraph/W=$win nticks=0, axthick=0, margin=1, width={Plan,1,bottom,left}
		SetDrawLayer/W=$win UserFront
		SetDrawEnv/W=$win linethick= 5,linefgc= (56797,56797,56797)
		DrawLine/W=$win 0.822437513922712,0.1,0.944949852649121,0.1
		SetDrawEnv/W=$win fsize= 24,fstyle= 1,textrgb= (65535,65535,65535)
		DrawText/W=$win 0.82122905027933,0.25,"1µm"
		DoUpdate/W=$win
		saveWindow(win, customName = name, path = "images", saveJSON = 1, saveTiff = 1, saveImages = 0)

		// cleanup
		KillWindow/Z $win
		KillWaves/Z wv
	endfor
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

Function SMADisplayCoordinates(xCoordinate, yCoordinate, [range])
	Variable xCoordinate, yCoordinate
	Variable range

	String win = "win_SMAimageStack" // use this image
	if(ParamIsDefault(range))
		range = 2 // extract 2µm in x- and 2*2µm in y-direction
	endif

	DoWindow/F $win
	if(!V_flag)
		Abort "Create SMAimageStack first"
	endif

	SetAxis/W=$win left, xCoordinate - range, xCoordinate + range
	SetAxis/W=$win bottom, yCoordinate - 2 * range, yCoordinate + 2 * range
	DoUpdate/W=$win
End

Function/WAVE SMAduplicateRange(FirstImage, [outputName])
	String outputName
	Variable FirstImage

	Variable i, numPLEM
	Variable offsetX, offsetY

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
	Duplicate/O/R=(yStart + offsetY, yEnd + offsetY)(xStart + offsetX, xEnd + offsetX) stats.wavPLEM $outputName/WAVE=wv
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
	SMASetCoordinates(wv, (yEnd + yStart) / 2, (xEnd + xStart) / 2 )

	return wv
End

Function SMASetCoordinates(wv, yCoordinate, xCoordinate)
	WAVE wv
	Variable yCoordinate, xCoordinate

	Variable start, ende
	String wavenote = note(wv)

	start = strsearch(wavenote, "x-position", start)
	ende  = strsearch(wavenote, "\r", start)
	wavenote = wavenote[0, start - 1] + "x-position: " + num2str(xCoordinate) + wavenote[ende, inf]
	start = strsearch(wavenote, "y-position", start)
	ende  = strsearch(wavenote, "\r", start)
	wavenote = wavenote[0, start - 1] + "y-position: " + num2str(yCoordinate) + wavenote[ende, inf]
End
