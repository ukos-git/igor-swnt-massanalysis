#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include "utilities-time"

Function/WAVE SMAmergeImages(quick, [createNew, indices])
	Variable createNew, quick
	WAVE indices

	Variable pixelX, pixelY, resolution, imageborders
	Variable numMaps
	Variable i, j, k, dim0, dim1
	variable imagearea = 311
	STRUCT PLEMd2Stats stats

	Variable numMapsAvailable = PLEMd2getMapsAvailable()
	if(numMapsAvailable == 0)
		SMAread()
		numMapsAvailable = PLEMd2getMapsAvailable()
	endif

	if(ParamIsDefault(indices))
		Make/FREE/N=(numMapsAvailable) indices = p
	endif

	quick = !!quick

	createNew = ParamIsDefault(createNew) ? 1 : !!createNew

	if(!createNew)
		WAVE/Z fullimage = root:fullimage
		if(WaveExists(fullimage))
			return fullimage
		endif
		WaveClear fullimage
	endif

	Variable timerRefNum = StartMSTimer

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	dim0 = DimSize(stats.wavPLEM, 0)
	dim1 = DimSize(stats.wavPLEM, 1)

	// append all Images to one big Image (fullimage)
	WAVE medianImage = SMAgetMedian(overwrite = 1)
	wave background = SMAestimateBackground(medianImage)
	ImageFilter/O /N=101/P=1 avg background
	Duplicate/O background root:backround
	resolution = (abs(DimDelta(stats.wavPLEM, 0)) + abs(DimDelta(stats.wavPLEM, 1))) / 2
	resolution = ceil(imagearea / resolution)

	Make/O/N=(resolution, resolution) root:fullimage/WAVE=fullimage = 0
	Make/FREE/B/U/N=(resolution, resolution) fullimagenorm = 0
	Make/FREE/N=(dim0, dim1) currentImage

	imageborders = abs(imagearea - 300 - 1) / 2
	SetScale/I x, 0 - imageborders , 300 + imageborders, fullimage
	SetScale/I y, 0 - imageborders , 300 + imageborders, fullimage

	numMaps = DimSize(indices, 0)
	for(i = 0; i < numMaps; i += 1)
		if(numtype(indices[i]) != 0)
			continue
		endif
		PLEMd2statsLoad(stats, PLEMd2strPLEM(indices[i]))
		MultiThread currentImage[][] = stats.wavPLEM[p][q] - background[p][q]
		if(!quick)
			ImageFilter/O /N=5 median currentImage // remove spikes
		endif
		for(j = 0; j < dim0; j += 1)
			pixelX = ScaleToIndex(fullimage, IndexToScale(stats.wavPLEM, j, 0), 0)
			if((pixelX < 0) || (pixelX >= resolution))
				continue
			endif
			for(k = 0; k < dim1; k += 1)
				if(numtype(currentImage[j][k]) != 0)
					continue
				endif
				pixelY = ScaleToIndex(fullimage, IndexToScale(stats.wavPLEM, k, 1), 1)
				if((pixelY < 0) || (pixelY >= resolution))
					continue
				endif

				fullimage[pixelX][pixelY] += currentImage[j][k]
				fullimagenorm[pixelX][pixelY] += 1
			endfor
		endfor
	endfor

	MultiThread fullimage[][] = fullimagenorm[p][q] == 0 ? NaN : fullimage[p][q] / fullimagenorm[p][q]

	// interpolate values, that were not found directly
	if(!quick)
		MultiThread fullimagenorm[][] = numtype(fullimage[p][q]) == 2
		if(sum(fullimagenorm) / (dim0 * dim1) < 0.01)
			ImageFilter/O NanZapMedian fullimage
		endif
	endif

	SMAbuildGraphFullImage()

	Utilities#lap(timerRefNum, "SMAmergeImages")

	return fullimage
End

// input a wave stackCoordinates and search for the coordinates included in it.
// the wave stackCoordinates is split to coordinate lists that have the size stackSize.
// the function can be called multiple times with varying stackNumber to merge differnt
// parts of the coordinate list.
Function/WAVE SMAmergeStack(stackCoordinates, stackNumber, stackSize, [createNew])
	WAVE stackCoordinates
	Variable stackNumber, stackSize
	Variable createNew

	Variable rangeStart, rangeEnd
	
	createNew = ParamIsDefault(createNew) ? 1 : !!createNew

	rangeStart = stackNumber * stackSize
	rangeEnd   = (stackNumber + 1) * stackSize - 1
	Duplicate/FREE/R=[rangeStart, rangeEnd][] stackCoordinates scan
	WAVE found = SMAfindCoordinatesInPLEM(scan)
	make/free/n=(stackSize) normalnumber = numType(found[p]) == 0
	if(sum(normalnumber) < stackSize / 4)
		return $""
	endif
	Duplicate/O found 	root:found/WAVE=found
	WAVE fullimage = SMAmergeImages(1, indices = found, createNew = createNew)

	SMAconvertWaveToUint(fullimage, bit = 8)

	return fullimage
End

Function/WAVE SMAprocessImageStack([coordinates, createNew])
	WAVE coordinates
	Variable createNew

	Variable i, numFullImages, numImages

	createNew = ParamIsDefault(createNew) ? 1 : !!createNew
	if(ParamIsDefault(coordinates))
		//WAVE coordinates = SMAcameraCoordinates(export = 0)
		WAVE coordinates = PLEMd2getCoordinates()
	endif

	numImages = PLEMd2getMapsAvailable()
	if(numImages == 0)
		SMAload()
		numImages = PLEMd2getMapsAvailable()
		WAVE coordinates = PLEMd2getCoordinates(forceRenew = 1)
	endif

	if(!WaveExists(coordinates))
		Abort
	endif

	numFullImages = floor(numImages / 24)
	Wave fullimage = SMAmergeStack(coordinates, 0, 24)
	Duplicate/O fullimage root:SMAimagestack/WAVE=imagestack
	Redimension/N=(-1, -1, numFullImages) imagestack

	for(i = 1; i < numFullImages; i += 1)
		Wave fullimage = SMAmergeStack(coordinates, i, 24, createNew = createNew)
		if(WaveExists(fullimage))
			MultiThread imagestack[][][i] = fullimage[p][q]
		endif
	endfor

	SMAimageStackopenWindow()
	
	return imagestack
End

// only valid for images
Function SMAmergeTimeSeries()
	Variable i
	Variable numImages = PLEMd2getMapsAvailable()

	STRUCT PLEMd2Stats stats

	if(numImages == 0)
		SMAload()
	endif

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	Duplicate/O stats.wavPLEM root:SMAimagestack/WAVE=imagestack
	Redimension/N=(-1, -1, numImages) imagestack

	for(i = 1; i < numImages; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		MultiThread imagestack[][][i] = stats.wavPLEM[p][q]
	endfor

	SMAimageStackopenWindow()
End

// see ACW_EraseMarqueeArea.
Function SMA_ExtractSumMarqueeArea()
	variable pStart, pEnd, qStart, qEnd
	variable i, dim2, cursorExists
	string sourcewin, destwin
	variable normalization = 0
	string outputName = "timetrace"
	
	sourcewin = WinName(0, 1)
	destwin = outputName

	GetMarquee left, bottom //V_bottom, V_top, V_left and V_right
	if (V_flag == 0)
		return 0
	endif
	
	WAVE/Z image = getTopWindowImage()
	pStart = ScaleToIndex(image, V_left, 0)
	pEnd = ScaleToIndex(image, V_right, 0)
	qStart = ScaleToIndex(image, V_bottom, 1)
	qEnd = ScaleToIndex(image, V_top, 1)

	SMAorderAsc(pStart, pEnd)
	SMAorderAsc(qStart, qEnd)

	DoWindow $destwin
	if(!V_Flag)
		Display/N=$destwin
	endif

	outputName = UniqueName(outputName, 1, 0)
	dim2 = DimSize(image, 2)
	Make/N=(dim2) $outputName/WAVE=wv

	cursorExists = strlen(CsrInfo(A)) > 0 && strlen(CsrInfo(B)) > 0
	if(cursorExists)
		print "substracting area between cursors as background for marquee area"
	endif

	for(i = 0; i < dim2; i += 1)
		Duplicate/FREE/R=[pStart, pEnd][qStart, qEnd][i] image, marqueearea
		if(cursorExists)
			Duplicate/FREE/R=[pcsr(a, sourcewin), pcsr(b, sourcewin)][qcsr(a, sourcewin), qcsr(b, sourcewin)][i] image, reference
			// background for marquearea
			normalization = sum(reference) / (DimSize(reference, 0) * DimSize(reference, 1)) * (DimSize(marqueearea, 0) * DimSize(marqueearea, 1))
		endif
		wv[i] = sum(marqueearea) - normalization
	endfor

	AppendToGraph/W=$destwin wv
	print outputname
End

// save storage by converting image to full uint
Function SMAconvertWaveToUint(wv, [bit])
	WAVE wv
	Variable bit

	Variable wMin, wMax
	Variable numSpace

	bit = ParamIsDefault(bit) ? 32 : bit
	numSpace = 2^bit - 1

	wMin = WaveMin(wv)
	wv -= wMin

	wMax = WaveMax(wv)
	wv[][] = round(wv[p][q] / wMax * numSpace)

	switch(bit)
		case 16:
			Redimension/W/U wv // 16bit
			break
		case 8:
			Redimension/B/U wv // 8bit
			break
		case 32:
		default:
			Redimension/I/U wv // 32bit
	endswitch
End

Function/S SMAbuildGraphPLEM()
	Variable i, range_min, range_max
	String ImageNames
	STRUCT PLEMd2Stats stats

	String graphName = "SMAgetCoordinatesGraph"
	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")

	DoWindow $graphName
	if(V_flag != 0)
		return graphName
	endif

	Display/W=(400,40,1200,650)/N=$graphName
	graphName = S_name

	WAVE wavCoordinates = root:coordinates
	if(WaveExists(wavCoordinates))
		AppendToGraph/W=$graphName wavCoordinates[][0]/TN=coordinates vs wavCoordinates[][1]
		ModifyGraph/W=$graphName mode(coordinates)=3,marker(coordinates)=1,msize(coordinates)=2
	endif

	for(i = 0; i < gnumMapsAvailable; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))

		range_min = WaveMin(stats.wavPLEM)
		range_max = WaveMax(stats.wavPLEM)
		AppendImage/W=$graphName stats.wavPLEM
	endfor

	ImageNames = ImageNameList("", ";")
	for(i = 0; i < gnumMapsAvailable; i += 1)
		ModifyImage/W=$graphName $StringFromList(i, ImageNames) ctab= {range_min,range_max,Terrain,0}
	endfor

	return graphName
End

Function/S SMAbuildGraphFullImage()
	String graphName = "SMAgetCoordinatesfullImage"

	DoWindow $graphName
	if(V_flag == 0)
		Display/W=(400,40,1200,650)/N=$graphName
		graphName = S_name
		wave image = root:fullimage
		if(!WaveExists(image))
			Make/N=(2,2) root:fullimage/WAVE=image
		endif
		AppendImage/W=$graphName root:fullimage
		ModifyImage/W=$graphName fullimage ctab= {*,*,Blue,1}
		ModifyGraph/W=$graphName mirror=0
	endif

	return graphName
End

Function SMAtestSizeAdjustment()
	Variable i
	variable dim4size = 20
	Variable dim4offset = 0.9700
	Variable dim4delta  = 0.0010

	NVAR/Z numSizeAdjustment = root:numSizeAdjustment
	if(!NVAR_EXISTS(numSizeAdjustment))
		Variable/G root:numSizeAdjustment = 1
		NVAR/Z numSizeAdjustment = root:numSizeAdjustment
	endif

	// load for magnification
	STRUCT PLEMd2Stats stats
	PLEMd2statsLoad(stats, PLEMd2strPLEM(1))

	WAVE imagestack = SMAprocessImageStack(createNew = 0)

	Duplicate/O imagestack root:SMAsizeAdjustment/WAVE=wv
	Redimension/N=(-1, -1, -1, dim4size) wv
	SetScale/P t, dim4offset, dim4delta, wv

	Make/O/N=(dim4size) root:SMAnumSizeAdjustment/WAVE=dim4 = dim4offset + p * dim4delta

	for(i = 0; i < dim4size; i += 1)
		numSizeAdjustment = (dim4offset + i * dim4delta)
		dim4[i] = stats.numMagnification / numSizeAdjustment
		//SMAread()
		SMAreset()
		WAVE imagestack = SMAprocessImageStack(createNew = 1)
		Multithread wv[][][][i] = imagestack[p][q][r]
		SavePICT/WIN=win_SMAimageStack/O/P=home/E=-5/B=72 as "sizeAdjustment_" + num2str(numSizeAdjustment * 1e4) + ".png"
	endfor

	DoWindow/F win_SMAimageStack
End

Function/WAVE SMAestimateBackground(input)
	WAVE input

	Variable pVal, qVal
	Variable i

	Variable V_fitOptions=4 // used to suppress CurveFit dialog
	Variable V_FitQuitReason // stores the CurveFit Quit Reason
	Variable V_FitError // Curve Fit error

	Duplicate/FREE input background

	// ImageFilter/O NaNZapMedian background
	ImageFilter/O /N=5 median background // remove spikes
	Smooth 5, background
	ImageFilter/O /N=101/P=1 avg background

	// remove gaussian background from illumination if possible
	Make/O/T/N=3 T_Constraints = {"K1 > 0","K3 > 0","K5 > 0"}
	V_FitError = 0
	CurveFit/Q Gauss2D background /C=T_Constraints
	if(V_FitError == 0)
		Wave W_coef, W_sigma
		W_coef[] = abs(W_sigma[p] / W_coef[p]) > 0.3 ? NaN : W_coef[p]
		if(numType(sum(W_coef) == 0))
			background -= Gauss2D(W_coef, x, y)
		endif
		WaveClear W_coef, W_sigma
	endif
	KillWaves/Z T_Constraints

	return background
End

Function/WAVE SMAgetMedian([overwrite])
	Variable overwrite

	Variable i, dim0, dim1
	Variable pVal, qVal
	Struct PLEMd2Stats stats
	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")

	overwrite = ParamIsDefault(overwrite) ? 0 : !!overwrite

	WAVE/Z myMedian = root:SMAmedian
	if(WaveExists(myMedian) && !overwrite)
		return myMedian
	endif
	WaveClear myMedian

	PLEMd2statsLoad(stats, PLEMd2strPLEM(1))

	dim0 = DimSize(stats.wavPLEM, 0)
	dim1 = DimSize(stats.wavPLEM, 1)
	dim1 = dim1 != 0 ? dim1 : 1 // dim1 = 0 and dim1 = 1 is the same
	Make/O/N=(dim0, dim1) root:SMAmedianBackground/WAVE=myMedian
	SetScale/P x, 0, 1, myMedian
	SetScale/P y, 0, 1, myMedian

	// calculate median of all images
	//Make/O/N=(dim0, dim1, gnumMapsAvailable) root:SMAmedianMatrix/WAVE=bgMatrix
	Make/FREE/N=(dim0, dim1, gnumMapsAvailable) bgMatrix
	for(i = 0; i < gnumMapsAvailable; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		if(dim1 != DimSize(stats.wavPLEM, 1))
			continue
		endif
		if(dim1 == 1)
			bgMatrix[][0][i] = stats.wavPLEM[p]
		else
			bgMatrix[][][i] = stats.wavPLEM[p][q]
		endif
	endfor
	for(i = 0; i < dim0 * dim1; i += 1)
		pVal = mod(i, dim0)
		qVal = floor(i / dim0)
		Duplicate/FREE/R=[pVal][qVal][0,*] bgMatrix, currentPixel
		myMedian[pVal][qVal] = median(currentPixel)
		WaveClear currentPixel
	endfor
	duplicate/o bgmatrix root:temp
	WaveClear bgMatrix

	if(dim1 == 1)
		Redimension/N=(dim0) myMedian
	endif

	return myMedian
End
