#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function/WAVE SMAmergeImages([createNew, indices])
	Variable createNew
	WAVE indices

	Variable pixelX, pixelY, resolution
	Variable numMaps
	Variable i, j, k, dim0, dim1
	STRUCT PLEMd2Stats stats

	if(ParamIsDefault(indices))
		Make/FREE/N=(PLEMd2getMapsAvailable()) indices = p
	endif

	createNew = ParamIsDefault(createNew) ? 1 : !!createNew

	if(!createNew)
		WAVE/Z fullimage = root:fullimage
		if(WaveExists(fullimage))
			return fullimage
		endif
		WaveClear fullimage
	endif

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	dim0 = DimSize(stats.wavPLEM, 0)
	dim1 = DimSize(stats.wavPLEM, 1)

	// append all Images to one big Image (fullimage)
	wave background = SMAestimateBackground()
	resolution = (abs(DimDelta(stats.wavPLEM, 0)) + abs(DimDelta(stats.wavPLEM, 1))) / 2
	resolution = ceil(331 / resolution)

	Make/O/N=(resolution, resolution) root:fullimage/WAVE=fullimage = 0
	Make/FREE/U/N=(resolution, resolution) fullimagenorm = 0

	SetScale/I x, -5, 325, fullimage
	SetScale/I y, -5, 325, fullimage

	numMaps = DimSize(indices, 0)
	for(i = 0; i < numMaps; i += 1)
		if(numtype(indices[i]) != 0)
			continue
		endif
		PLEMd2statsLoad(stats, PLEMd2strPLEM(indices[i]))
		Duplicate/FREE stats.wavPLEM, currentImage
		ImageFilter/O /N=5 median currentImage // remove spikes
		currentImage -= background
		for(j = 0; j < dim0; j += 1)
			for(k = 0; k < dim1; k += 1)
				if(numtype(currentImage[j][k]) != 0)
					continue
				endif
				pixelX = IndexToScale(currentImage, j, 0)
				pixelX = ScaleToIndex(fullimage, pixelX, 0)
				pixelY = IndexToScale(currentImage, k, 1)
				pixelY = ScaleToIndex(fullimage, pixelY, 1)
				if((pixelX < 0) || (pixelY < 0))
					continue
				endif
				if((pixelX >= resolution) || (pixelY >= resolution))
					continue
				endif

				fullimage[pixelX][pixelY] += currentImage[j][k]
				fullimagenorm[pixelX][pixelY] += 1
			endfor
		endfor
		WaveClear currentImage
	endfor
	fullimage[][] = fullimagenorm[p][q] == 0 ? NaN : fullimage[p][q] / fullimagenorm[p][q]
	ImageFilter/O NanZapMedian fullimage
	SMAbuildGraphFullImage()

	return fullimage
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
	AppendToGraph/W=$graphName wavCoordinates[][0]/TN=coordinates vs wavCoordinates[][1]
	ModifyGraph/W=$graphName mode(coordinates)=3,marker(coordinates)=1,msize(coordinates)=2

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
	String graphName1, graphName2

	NVAR/Z numSizeAdjustment = root:numSizeAdjustment
	if(!NVAR_EXISTS(numSizeAdjustment))
		Variable/G root:numSizeAdjustment = 1
		NVAR/Z numSizeAdjustment = root:numSizeAdjustment
	endif

	WAVE fullimage = SMAmergeImages(createNew = 0)
	graphName1 = SMAbuildGraphPLEM()
	graphName2 = SMAbuildGraphFullImage()

	for(i = 0; i < 10; i += 1)
		numSizeAdjustment = (0.940 + i * 0.005)
		SMAread()
		WAVE fullimage = SMAmergeImages(createNew = 1)
		Duplicate/O fullimage $("root:fullImage_" + num2str(numSizeAdjustment * 1e3))

		SavePICT/WIN=$graphName1/O/P=home/E=-5/B=72 as "fullImage_" + num2str(numSizeAdjustment * 1e3) + ".png"
		SavePICT/WIN=$graphName2/O/P=home/E=-5/B=72 as "sizeAdjustment_" + num2str(numSizeAdjustment * 1e3) + ".png"
	endfor
End

Function/WAVE SMAestimateBackground()
	Variable pVal, qVal, dim0, dim1
	Variable i
	STRUCT PLEMd2Stats stats

	Variable V_fitOptions=4 // used to suppress CurveFit dialog
	Variable V_FitQuitReason // stores the CurveFit Quit Reason
	Variable V_FitError // Curve Fit error

	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")

	WAVE/Z background = root:background
	if(WaveExists(background))
		return background
	endif
	WaveClear background
	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	dim0 = DimSize(stats.wavPLEM, 0)
	dim1 = DimSize(stats.wavPLEM, 1)
	Make/N=(dim0, dim1) root:background/WAVE=background

	WAVE median = SMAmedian()
	background = median

	// remove gaussian background from illumination
	ImageFilter/O /N=5 median background // remove spikes
	Smooth 5, background
	ImageFilter/O /N=101/P=1 avg background
	Make/O/T/N=3 T_Constraints = {"K1 > 0","K3 > 0","K5 > 0"}
	V_FitError = 0
	CurveFit/Q Gauss2D background /C=T_Constraints
	if(V_FitError == 0)
		Wave W_coef, W_sigma
		W_coef[] = abs(W_sigma[p] / W_coef[p]) > 0.3 ? NaN : W_coef[p]
		if(numType(sum(W_coef) == 0))
			background = Gauss2D(W_coef, x, y)
		endif
		WaveClear W_coef, W_sigma
	endif
	KillWaves/Z T_Constraints

	return background
End

Function/WAVE SMAmedian([overwrite])
	Variable overwrite

	Variable i, dim0, dim1
	Variable pVal, qVal
	Struct PLEMd2Stats stats
	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")

	overwrite = ParamIsDefault(overwrite) ? 0 : !!overwrite

	WAVE/Z source = root:source
	if(!WaveExists(source) || overwrite)
		SMAcovariance()
		WAVE source = root:source
	endif

	WAVE/Z myMedian = root:SMAmedian
	if(WaveExists(myMedian) && !overwrite)
		return myMedian
	endif
	WaveClear myMedian

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	dim0 = DimSize(stats.wavPLEM, 0)
	dim1 = DimSize(stats.wavPLEM, 1)
	if(dim1 == 0)
		dim1 = 1
	endif
	Make/O/N=(dim0, dim1) root:backgroundMedian/WAVE=myMedian

	// calculate median of all images
	Make/FREE/N=(dim0, dim1, gnumMapsAvailable) bgMatrix
	for(i = 0; i < gnumMapsAvailable; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
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
	WaveClear bgMatrix

	if(dim1 == 1)
		Redimension/N=(dim0) myMedian
		SetScale/P x, DimOffset(stats.wavPLEM, 0), DimDelta(stats.wavPLEM, 0), myMedian
	endif

	return myMedian
End
