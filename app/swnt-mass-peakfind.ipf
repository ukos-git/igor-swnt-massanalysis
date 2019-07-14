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
		Redimension/N=(abs(ende - start) + 1) source_extracted

		WAVE guess = PeakFind(source_extracted, wvXdata = wl_extracted, maxPeaks = 1, smoothingFactor = 3) // align smoothingFactor to your needs
		WAVE/WAVE coef = BuildCoefWv(source_extracted, peaks = guess)
		WAVE/WAVE peakParam = fitGauss(source_extracted, wvXdata = wl_extracted, wvCoef = coef, cleanup = 1)
		if(!WaveExists(peakParam))
			printf "SMAsinglePeakAction: error fitting %d.\r", i
			continue
		endif
		if(DimSize(peakParam, 0) != 1)
			Abort "Code Inconsitency: More than one peak found."
		endif
		WAVE result = peakParamToResult(peakParam)

		WAVE peakfit = CreateFitCurve(peakParam, startX, endX, 1024)
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

	WAVE nospikes = removeSpikes(wv)
	 //WAVE nobackground = RemoveBackground(nospikes)

	if(ParamIsDefault(wvXdata))
		WAVE guess = PeakFind(nospikes, maxPeaks = maxPeaks, minPeakPercent = minPeakPercent, smoothingFactor = smoothingFactor, verbose = verbose)
	else
		WAVE guess = PeakFind(nospikes, wvXdata = wvXdata, maxPeaks = maxPeaks, minPeakPercent = minPeakPercent, smoothingFactor = smoothingFactor, verbose = verbose)
	endif
	DFREF dfr = SMApeakfitDF()
	WAVE/WAVE coef = BuildCoefWv(nospikes, peaks = guess, dfr = dfr, verbose = verbose)
	if(ParamIsDefault(wvXdata))
		WAVE/WAVE/Z peakParam = fitGauss(nospikes, wvCoef = coef, verbose = verbose)
	else
		WAVE/WAVE/Z peakParam = fitGauss(nospikes, wvXdata = wvXdata, wvCoef = coef, verbose = verbose)
	endif

	if(verbose > 2)
		print "==COEF WAVE=="
		numResults = DimSize(coef, 0)
		for(i = 0; i < numResults; i += 1)
			WAVE output = coef[i]
			print output
		endfor
	endif
	KillWaveOfWaves(coef)

	if(createWaves)
		Duplicate/O nospikes root:nospikes
		Duplicate/O wv root:original
		//Duplicate/O nobackground root:nobackground
		Duplicate/O nospikes root:nospikes
		WAVE peakfit = CreateFitCurve(peakParam, DimOffset(input, 0), DimOffset(input, 0) + DimSize(input, 0) * DimDelta(input, 0), 1024)
		Duplicate/O peakfit root:peakfit
		WAVE peakfit = CreateFitCurve(peakParam, DimOffset(input, 0), DimOffset(input, 0) + DimSize(input, 0) * DimDelta(input, 0), DimSize(input, 0))
		Duplicate/O peakfit root:residuum/WAVE=res
		res = nospikes - peakfit
	endif

	if(!WaveExists(peakParam))
		print "SMApeakFind Error: no peakParam"
		return $""
	endif
	return peakParamToResult(peakParam)
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
	WAVE/Z area = root:peakArea
	if(!WaveExists(area) || DimSize(area, 0) != dim0)
		Make/O/N=(dim0) root:peakArea/WAVE=area = NaN
	endif

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	if(DimSize(stats.wavPLEM, 1) > 1)
		return SMApeakAnalysisMap()
	endif

	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))

		// do peakfind on ranged wave
		WAVE PLEMrange = PLEMd2NanotubeRangePLEM(stats)
		WAVE corrected = removeSpikes(PLEMrange)
		WAVE/WAVE peakfind = SMApeakFind(corrected, maxPeaks = 3, verbose = 0)
		if(!WaveExists(peakfind))
			continue // fall back to SMAquickAnalysis()
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
			area[i] = peakfind[j][%area]
		endfor
	endfor
End

Function SMApeakAnalysisMap()
	variable i, j, numPeaks, numAccuracy
	Variable fit_start, fit_end, numPoints
	Struct PLEMd2stats stats

	Variable numDelta = 100 / 2 // this is the fitting range around the initial guess

	Variable V_fitOptions = 4 // used to suppress CurveFit dialog
	Variable V_FitQuitReason  // stores the CurveFit Quit Reason
	Variable V_FitError   // Curve Fit error
	
	Variable dim0 = PLEMd2getMapsAvailable()

	WAVE wavelength = SMAcopyWavelengthToRoot()
	WAVE excitation = SMAcopyExcitationToRoot()
	
	SMAquickAnalysis()

	Make/O/N=(dim0) root:peakHeight/WAVE=peakHeight
	Make/O/N=(dim0) root:peakEmission/WAVE=peakEmission
	Make/O/N=(dim0) root:peakExcitation/WAVE=peakExcitation
	
	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		WAVE corrected = RemoveSpikes(stats.wavPLEM)

		// fit Excitation
		// find p,q
		FindValue/T=2/V=(peakEmission[i] - numDelta) wavelength
		if(V_Value == -1)
			fit_start = 0
		else
			fit_start = V_Value
		endif
		FindValue/T=2/V=(peakEmission[i] + numDelta) wavelength
		if(V_Value == -1)
			fit_end = DimSize(corrected, 0) - 1
		else
			fit_end = V_Value
		endif
		numAccuracy = 0
		do
			numAccuracy += 1
			FindValue/T=(numAccuracy)/V=(peakExcitation[i]) excitation
		while(V_Value == -1)

		numPoints = abs(fit_end - fit_start) + 1
		Make/N=(numPoints)/FREE fitEmission = corrected[fit_start + p][V_Value]
		Make/N=(numPoints)/FREE fitEmissionX = wavelength[fit_start + p]

		WAVE/WAVE peakfind = SMApeakFind(fitEmission, wvXdata = fitEmissionX, maxPeaks = 3, verbose = 1)
		if(!WaveExists(peakfind))
			continue
		endif
		numPeaks = DimSize(peakfind, 0)
		for(j = 0; j < numPeaks; j += 1)
			if(peakfind[j][%height] < peakHeight[i])
				continue
			endif
			if((peakfind[j][%fwhm] < 5) || (peakfind[j][%fwhm] > 50))
				continue
			endif
			peakHeight[i] = peakfind[j][%height]
			peakEmission[i] = peakfind[j][%location]
		endfor
		WaveClear peakfind

		// fit Emission
		// find p,q
		FindValue/T=2/V=(peakExcitation[i] - numDelta) excitation
		if(V_Value == -1)
			fit_start = 0
		else
			fit_start = V_Value
		endif
		FindValue/T=2/V=(peakExcitation[i] + numDelta) excitation
		if(V_Value == -1)
			fit_end = DimSize(corrected, 1) - 1
		else
			fit_end = V_Value
		endif
		numAccuracy = 0
		do
			numAccuracy += 1
			FindValue/T=(numAccuracy)/V=(peakEmission[i]) wavelength
		while(V_Value == -1)

		numPoints = abs(fit_end - fit_start) + 1
		Make/N=(numPoints)/FREE fitExcitation = corrected[V_Value][fit_start + p]
		Make/N=(numPoints)/FREE fitExcitationX = excitation[fit_start + p]

		WAVE/WAVE peakfind = SMApeakFind(fitExcitation, wvXdata = fitExcitationX, maxPeaks = 3, verbose = 0)
		if(!WaveExists(peakfind))
			continue
		endif
		numPeaks = DimSize(peakfind, 0)
		for(j = 0; j < numPeaks; j += 1)
			if(peakfind[j][%height] < peakHeight[i])
				continue
			endif
			if((peakfind[j][%fwhm] < 5) || (peakfind[j][%fwhm] > 50))
				continue
			endif
			peakHeight[i] = peakfind[j][%height]
			peakExcitation[i] = peakfind[j][%location]
		endfor
		WaveClear peakfind
	endfor

	// create simple sum
	WAVE source = SMAgetSourceWave()
	MatrixOp/O root:mapsSum/WAVE=dest = sumCols(source)^t
	SMARedimensionToMap(dest)

	// display
	DoWindow/F SMAmapsSum
	if(!V_flag)
		Execute "SMAmapsSum()"
	endif
	DoWindow/F SMApeakMaximum
	if(!V_flag)
		Execute "SMApeakMaximum()"
	endif
End

Function SMAquickAnalysis()
	variable i, dim0
	Struct PLEMd2stats stats
	
	dim0 = Plemd2getMapsAvailable()
	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	Make/O/N=(dim0) root:peakHeight/WAVE=int = NaN
	if(DimSize(stats.wavPLEM, 1) > 1)
		Make/O/N=(dim0) root:peakEmission/WAVE=emi = NaN
		Make/O/N=(dim0) root:peakExcitation/WAVE=exc = NaN
	else
		Make/O/N=(dim0) root:peakLocation/WAVE=loc = NaN
	endif
	
	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))

		WAVE PLEMrange = PLEMd2NanotubeRangePLEM(stats)
		WAVE corrected = removeSpikes(PLEMrange)
		WaveStats/M=1/Q/P corrected // explicitly get min/max in points

		int[i] = V_max
		if(DimSize(stats.wavPLEM, 1) > 1)
			emi[i] = stats.wavWavelength[ScaleToIndex(stats.wavPLEM, IndexToScale(corrected, V_maxRowLoc, 0), 0)]
			exc[i] = stats.wavExcitation[ScaleToIndex(stats.wavPLEM, IndexToScale(corrected, V_maxColLoc, 1), 1)]
		else
			loc[i] = stats.wavWavelength[ScaleToIndex(stats.wavPLEM, IndexToScale(corrected, V_maxRowLoc, 0), 0)]
		endif
	endfor
End

// extract best Spectrum from exactscan to get only one spectrum per nanotube
Function SMApeakAnalysisExactscan()
	variable i, numItems

	WAVE index = SMApeakAnalysisGetBestIndex()
	numItems = DimSize(index, 0)

	WAVE loc = root:peakLocation
	WAVE int = root:peakHeight
	WAVE fwhm = root:peakFWHM
	WAVE area = root:peakArea

	Make/O/N=(numItems) root:peakLocationExact = numType(index[p]) == 0 ? loc[index[p]] : NaN
	Make/O/N=(numItems) root:peakHeightExact = numType(index[p]) == 0 ? int[index[p]] : NaN
	Make/O/N=(numItems) root:peakFWHMExact = numType(index[p]) == 0 ? fwhm[index[p]] : NaN
	Make/O/N=(numItems) root:peakAreaExact = numType(index[p]) == 0 ? area[index[p]] : NaN

	DoWindow/F SMAexactscanImage
	if(!V_flag)
		Plemd2getCoordinates()
		SetDataFolder root:
		SmaloadBasePath()
		LoadWave/H/O/P=SMAbasePath ":collection:suspended:methods:exactscan:template:trenches.ibw"
		LoadWave/H/O/P=SMAbasePath ":collection:suspended:methods:exactscan:template:borders.ibw"
		Execute "SMAexactscanImage()"
		Execute "saveWindow(\"SMAexactscanImage\", saveJSON = 0, saveImages = 1, saveSVG = 0)"
	endif
End

// @brief find best spectrum from exactscan
//
// fixed to 11 scans around central position
// does not respect 2 different peak locations in one exactscan (too close nanotubes or bundles)
Function/WAVE SMApeakAnalysisGetBestIndex()
	variable i, dim0, range, numPLEM, numIndex
	variable rangeStart, rangeEnd
	Struct PLEMd2stats stats
	
	dim0 = Plemd2getMapsAvailable()
	range = 11

	WAVE/Z int = root:peakHeight
	if(!WaveExists(int))
		SMApeakAnalysis()
		WAVE int = root:peakHeight
	endif
	numIndex = round(dim0 / range)
	Make/O/N=(numIndex) root:peakIndex/WAVE=index = NaN
	for(i = 0; i < numIndex; i += 1)
		rangeStart = i * range
		rangeEnd = rangeStart + range - 1
		Duplicate/FREE/R=[rangeStart, rangeEnd] int int_range
		SetScale/P x, 0, 1, int_range
		WAVE/WAVE/Z peakParam = SMApeakFind(int_range, maxPeaks = 1)
		numPLEM = NaN
		if(WaveExists(peakParam))
			numPLEM = peakParam[0][%location]
		endif
		if(numType(numPLEM) != 0) // fall back to maximum intensity spectrum
			Wavestats/Q/M=1/P int_range
			numPLEM = V_maxLoc
		endif
		numPLEM += rangeStart
		numPLEM = max(min(round(numPLEM), rangeEnd), rangeStart)
		index[i] = numPLEM
	endfor

	return index
End
