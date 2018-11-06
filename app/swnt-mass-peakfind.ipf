#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// use root:source and root:wavelength wave to search for peaks
Function SMAsinglePeakAction(startX, endX, [source])
	Variable startX, endX
	WAVE source

	variable i, dim0

	// input waves
	if(paramIsDefault(source))
		WAVE source = SMAgetSourceWave(overwrite = 0)
	endif
	WAVE wl = root:wavelength
	if(!WaveExists(wl))
		WAVE wl = SMAcopyWavelengthToRoot()
	endif

	// search x coordinate in wavelength wave
	FindValue/V=(startX)/T=1 wl
	variable start = V_Value
	FindValue/V=(endX)/T=1 wl
	variable ende = V_value
	if(start == -1 || ende == -1)
		Abort "start or end not found in wavelength wave"
	endif

	// sync correlation for specified range
	Duplicate/O/R=[0,*][start, ende] source root:source_extracted/wave=source2
	MatrixOP/O root:source_extracted_timecorrelation/WAVE=extracted = getdiag(synccorrelation(source2^t), 0)
	DoWindow source_extracted_timecorrelation_graph
	if(!V_flag)
		Display/N=source_extracted_timecorrelation_graph extracted
	endif

	dim0 = DimSize(source, 0)

	// create output waves
	Make/O/N=(DimSize(source, 0), 1024) root:source_extracted_fit/WAVE=myfitwave = NaN
	SetScale/I y, startX, EndX, myfitwave
	Make/O/N=(dim0) root:peakHeight/WAVE=wvHeight = NaN
	Make/O/N=(dim0) root:peakHeightErr/WAVE=wvHeightErr = NaN
	Make/O/N=(dim0) root:peakLocation/WAVE=wvPos = NaN
	Make/O/N=(dim0) root:peakLocationErr/WAVE=wvPosnErr = NaN
	Make/O/N=(dim0) root:peakFWHM/WAVE=wvFwhm = NaN
	Make/O/N=(dim0) root:peakFWHMErr/WAVE=wvFwhmErr = NaN

	// do fit in specified range
	Duplicate/FREE/R=[start, ende] wl wl_extracted
	for(i = 0; i < dim0; i += 1)
		Duplicate/FREE/R=[i][start, ende] source source_extracted
		Redimension/N=(ende - start + 1) source_extracted

		WAVE guess = Utilities#PeakFind(source_extracted, wvXdata = wl_extracted, maxPeaks = 1, smoothingFactor = 3) // align smoothingFactor to your needs
		WAVE/WAVE coef = Utilities#BuildCoefWv(source_extracted, peaks = guess)
		WAVE/WAVE peakParam = Utilities#fitGauss(source_extracted, wvXdata = wl_extracted, wvCoef = coef, cleanup = 1)
		if(!WaveExists(peakParam))
			printf "SMAsinglePeakAction: error fitting %d.\r", i
			continue
		endif
		if(DimSize(peakParam, 0) != 1)
			Abort "Code Inconsitency: More than one peak found."
		endif
		WAVE result = Utilities#peakParamToResult(peakParam)

		WAVE peakfit = Utilities#CreateFitCurve(peakParam, startX, endX, 1024)
		myfitwave[i][] = peakfit[q]

		wvHeight[i]    = result[0][%height]
		wvHeightErr[i] = result[0][%height_err]
		wvPos[i]       = result[0][%location]
		wvPosnErr[i]   = result[0][%location_err]
		wvFwhm[i]      = result[0][%fwhm]
		wvFwhmErr[i]   = result[0][%fwhm_err]
	endfor

	DoWindow source_extracted_peak_height
	if(!V_flag)
		Display/N=source_extracted_peak_height wvHeight as "PLEM peak action"
	endif
end

Function/WAVE SMApeakFind(input, [wvXdata, verbose, createWaves, maxPeaks, minPeakPercent, smoothingFactor])
	WAVE input, wvXdata
	variable verbose, createWaves, maxPeaks, minPeakPercent, smoothingFactor

	variable numResults, i

	if(ParamIsDefault(verbose))
		verbose = 0
	endif
	if(ParamIsDefault(createWaves))
		createWaves = 1
	endif
	if(ParamIsDefault(maxPeaks))
		maxPeaks = 1
	endif
	if(ParamIsDefault(minPeakPercent))
		minPeakPercent = 5
	endif
	if(ParamIsDefault(smoothingFactor))
		smoothingFactor = 1
	endif
	
	Duplicate/FREE input, wv
	if(DimSize(wv, 1) == 1)
		Redimension/N=(-1,0) wv
	endif

	if(verbose)
		printf "SMApeakFind(%s, verbose=%d)\r", GetWavesDatafolder(input, 2), verbose
	endif

	WAVE nospikes = Utilities#removeSpikes(wv)
	 //WAVE nobackground = Utilities#RemoveBackground(nospikes)

	if(ParamIsDefault(wvXdata))
		WAVE guess = Utilities#PeakFind(nospikes, maxPeaks = maxPeaks, minPeakPercent = minPeakPercent, smoothingFactor = smoothingFactor, verbose = verbose)
	else
		WAVE guess = Utilities#PeakFind(nospikes, wvXdata = wvXdata, maxPeaks = maxPeaks, minPeakPercent = minPeakPercent, smoothingFactor = smoothingFactor, verbose = verbose)
	endif
	DFREF dfr = SMApeakfitDF()
	WAVE/WAVE coef = Utilities#BuildCoefWv(nospikes, peaks = guess, dfr = dfr, verbose = verbose)
	WAVE/WAVE peakParam = Utilities#fitGauss(nospikes, wvCoef = coef, verbose = verbose)
	
	if(verbose > 2)
		print "==COEF WAVE=="
		numResults = DimSize(coef, 0)
		for(i = 0; i < numResults; i += 1)
			WAVE output = coef[i]
			print output
		endfor
	endif
	Utilities#KillWaveOfWaves(coef)

	if(createWaves)
		Duplicate/O nospikes root:nospikes
		Duplicate/O wv root:original
		//Duplicate/O nobackground root:nobackground
		Duplicate/O nospikes root:nospikes
		WAVE peakfit = Utilities#CreateFitCurve(peakParam, DimOffset(input, 0), DimOffset(input, 0) + DimSize(input, 0) * DimDelta(input, 0), 1024)
		Duplicate/O peakfit root:peakfit
		WAVE peakfit = Utilities#CreateFitCurve(peakParam, DimOffset(input, 0), DimOffset(input, 0) + DimSize(input, 0) * DimDelta(input, 0), DimSize(input, 0))
		Duplicate/O peakfit root:residuum/WAVE=res
		res = nospikes - peakfit
	endif

	WAVE result = Utilities#peakParamToResult(peakParam)
	return result
End

Function SMApeakAnalysis()
	variable i, j, numPeaks, offset

	STRUCT PLEMd2Stats stats
	Variable dim0 = PLEMd2getMapsAvailable()

	SMAquickAnalysis()

	WAVE/Z loc = root:peakLocation
	if(!WaveExists(loc) || DimSize(loc, 0) != dim0)
		Make/O/N=(dim0) root:peakLocation/WAVE=loc = NaN
	endif
	WAVE/Z int = root:peakHeight
	if(!WaveExists(int) || DimSize(int, 0) != dim0)
		Make/O/N=(dim0) root:peakHeight/WAVE=int = NaN
	endif
	WAVE/Z fwhm = root:peakFWHM
	if(!WaveExists(fwhm) || DimSize(fwhm, 0) != dim0)
		Make/O/N=(dim0) root:peakFWHM/WAVE=fwhm = NaN
	endif

	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		WAVE/WAVE peakfind = SMApeakFind(stats.wavPLEM, wvXdata = stats.wavWavelength, maxPeaks = 3, verbose = 1)
		if(!WaveExists(peakfind))
			continue
		endif
		numPeaks = DimSize(peakfind, 0)
		for(j = 0; j < numPeaks; j += 1)
			if(peakfind[j][%height] < int[i])
				continue
			endif
			if((peakfind[j][%fwhm] < 5) || (peakfind[j][%fwhm] > 30))
				continue
			endif
			int[i] = peakfind[j][%height]
			loc[i]  = peakfind[j][%location]
			fwhm[i] = peakfind[j][%fwhm]
		endfor
	endfor
End

Function SMAquickAnalysis()
	variable i, dim0
	Struct PLEMd2stats stats
	
	dim0 = Plemd2getMapsAvailable()

	Make/O/N=(dim0) root:peakHeight/WAVE=int
	if(DimSize(stats.wavPLEM, 1) > 1)
		Make/O/N=(dim0) root:peakEmission/WAVE=emi
		Make/O/N=(dim0) root:peakExcitation/WAVE=exc
	else
		Make/O/N=(dim0) root:peakLocation/WAVE=loc
	endif
	
	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		
		if(DimSize(stats.wavPLEM, 1) > 1)
			Duplicate/FREE/R=[][3,*] stats.wavPLEM, corrected
		else
			Duplicate/FREE stats.wavPLEM corrected
			Redimension/N=(-1,0) corrected
		endif
		Smooth 255, corrected

		WaveStats/M=1/Q corrected
		int[i] = V_max
		if(DimSize(stats.wavPLEM, 1) > 1)
			emi[i] = stats.wavWavelength[V_maxRowLoc]
			exc[i] = stats.wavExcitation[V_maxColLoc]
		else
			loc[i] = stats.wavWavelength[V_maxRowLoc]
		endif
	endfor
End
