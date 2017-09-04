#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

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
