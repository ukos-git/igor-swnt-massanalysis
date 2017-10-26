#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// require igor-common-utilities
// https://github.com/ukos-git/igor-common-utilities
#include "utilities-peakfind"
#include "utilities-peakfit"

Function SMAsinglePeakAction(startX, endX)
	Variable startX, endX
	
	smareset()

	WAVE source = SMAgetSourceWave(overwrite = 1)

	STRUCT PLEMd2Stats stats
	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	Duplicate/O stats.wavWavelength root:wavelength/WAVE=wl

	findvalue/V=(startX)/T=1 wl
	variable start = V_Value
	findvalue/V=(endX)/T=1 wl
	variable ende = V_value

	// sync correlation
	Duplicate/O/R=[0,*][start, ende] source root:source_extracted/wave=source2
	matrixop/O root:timecorrelation_extracted = getdiag(synccorrelation(source2^t), 0)

	// lor fit
	variable dim0 = DimSize(source, 0)
	variable i
	variable height, position, fwhm
	Duplicate/O source root:source_fit/WAVE=myfitwave
	myfitwave = NaN
	Make/FREE/N=4 coefWave
	Make/O/N=(dim0) root:source_maxHeight/WAVE=wvHeight
	Make/O/N=(dim0) root:source_maxPosition/WAVE=wvPosition
	Make/O/N=(dim0) root:source_maxFWHM/WAVE=wvFwhm
	for(i = 0; i < dim0; i += 1)
		CurveFit/Q lor, kwCWave=coefWave source[i][start, ende] /X=wl[start, ende] /D=myfitwave[i][start, ende]
		wvHeight[i]   = coefWave[0] + coefWave[1] / coefWave[3]
		wvPosition[i] = coefWave[2]
		wvFwhm[i]     = 2 * sqrt(2 / ((1 / coefWave[3]) - (coefWave[0] / coefWave[1])) - coefWave[3])
	endfor
	dowindow/F $stats.strPLEM
	if(!V_flag)
		Display/N=$stats.strPLEM wvHeight as stats.strPLEM
	endif
end

Function SMApeakFindMass(verbose)
	variable verbose
	variable i

	STRUCT SMAinfo info
	SMAstructureLoad(info)
	STRUCT SMAprefs prefs
	SMAloadPackagePrefs(prefs)

	if(info.numSpectra != DimSize(info.wavSpectra, 0))
		print "SMApeakFindMass: error in SMAinfo structure"
		return 0
	endif

	info.numSpectra = DimSize(info.wavSpectra, 0)
	SMAstructureSave(info)
	Redimension/N=(info.numSpectra) info.wavPeakFind
	for(i = 0; i < info.numSpectra; i += 1)
		info.wavPeakFind[i] = SMApeakFind(info.wavSpectra[i], verbose = verbose)
	endfor
End

Function/WAVE SMApeakFind(input, [info, verbose, createWaves, maxPeaks, minPeakPercent, smoothingFactor])
	WAVE input
	STRUCT SMAinfo &info
	variable verbose, createWaves, maxPeaks, minPeakPercent, smoothingFactor

	variable numResults, i

	STRUCT SMAinfo info_copy
	if(ParamIsDefault(info))
		SMAstructureLoad(info_copy)
	else
		info_copy = info
	endif
	if(ParamIsDefault(verbose))
		verbose = 0
	endif
	if(ParamIsDefault(createWaves))
		createWaves = 0
	endif
	if(ParamIsDefault(maxPeaks))
		maxPeaks = 2
	endif
	if(ParamIsDefault(minPeakPercent))
		minPeakPercent = 0.9
	endif
	if(ParamIsDefault(smoothingFactor))
		smoothingFactor = 1
	endif
	
	Duplicate/FREE input, wv

	if(verbose)
		printf "SMApeakFind(%s, verbose=%d)\r", GetWavesDatafolder(input, 2), verbose
	endif

	WAVE nospikes = Utilities#removeSpikes(wv)
	 //WAVE nobackground = Utilities#RemoveBackground(nospikes)

	WAVE guess = Utilities#PeakFind(nospikes, maxPeaks = maxPeaks, minPeakPercent = minPeakPercent, smoothingFactor = smoothingFactor, verbose = verbose)
	WAVE/WAVE coef = Utilities#BuildCoefWv(nospikes, peaks = guess, dfr = info_copy.dfrPeakFit, verbose = verbose)
	WAVE/WAVE peakParam = Utilities#fitGauss(nospikes, wvCoef = coef, verbose = verbose)
	
	if(verbose > 2)
		print "==COEF WAVE=="
		numResults = DimSize(coef, 0)
		for(i = 0; i < numResults; i += 1)
			WAVE output = coef[i]
			print output
		endfor
	endif

	if(verbose > 3)
		Duplicate/O nospikes root:nospikes
		WAVE nopeaks = Utilities#RemovePeaks(nospikes, verbose = 0)
		Duplicate/O nopeaks root:nopeaks
		WAVE smoothed = Utilities#SmoothBackground(nopeaks)
		Duplicate/O smoothed root:smoothed
		createWaves = 1
	endif

	if(createWaves)
		Duplicate/O wv root:original
		//Duplicate/O nobackground root:nobackground
		Duplicate/O nospikes root:nospikes
		WAVE peakfit = Utilities#CreateFitCurve(peakParam, DimOffset(input, 0), DimOffset(input, 0) + DimSize(input, 0) * DimDelta(input, 0), 1024)
		Duplicate/O peakfit root:peakfit
		WAVE peakfit = Utilities#CreateFitCurve(peakParam, DimOffset(input, 0), DimOffset(input, 0) + DimSize(input, 0) * DimDelta(input, 0), DimSize(input, 0))
		Duplicate/O peakfit root:residuum/WAVE=res
		res = nospikes - peakfit
	endif

	Utilities#KillWaveOfWaves(coef)
	
	numResults = 0
	if(WaveExists(peakParam))
		numResults = DimSize(peakParam, 0)
	endif

	Make/FREE/N=(numResults, 6) result
	SetDimLabel 1, 0, position, result
	SetDimLabel 1, 1, intensity, result
	SetDimLabel 1, 2, fwhm, result
	SetDimLabel 1, 3, position_err, result
	SetDimLabel 1, 4, intensity_err, result
	SetDimLabel 1, 5, fwhm_err, result
	for(i = 0; i < numResults; i += 1)
		wave peak = peakParam[i]
		result[i][%position] = peak[0][0]
		result[i][%position_err] = peak[0][1]
		result[i][%intensity] = peak[1][0]
		result[i][%intensity_err] = peak[1][1]
		result[i][%fwhm] = peak[3][0]
		result[i][%fwhm_err] = peak[3][1]
	endfor

	return result
End

Function SMApeakAnalysis()
	variable i, j, numPeaks, offset

	STRUCT SMAinfo info
	SMAstructureLoad(info)

	for(i = 0; i < info.numSpectra; i += 1)
		WAVE/WAVE peakfind = info.wavPeakFind[i]
		if(!WaveExists(peakfind))
			continue
		endif
		numPeaks += DimSize(peakfind, 0)
	endfor

	Make/O/N=(numPeaks) root:peakfind_wl/WAVE=wl
	Make/O/N=(numPeaks) root:peakfind_int/WAVE=int
	Make/O/N=(numPeaks) root:peakfind_fwhm/WAVE=fwhm

	for(i = 7; i < info.numSpectra; i += 1)
		WAVE/WAVE peakfind = info.wavPeakFind[i]
		if(!WaveExists(peakfind))
			continue
		endif
		numPeaks = DimSize(peakfind, 0)
		for(j = 0; j < numPeaks; j += 1)
			wl[offset + j]  = peakfind[j][%position]
			int[offset + j] = peakfind[j][%intensity]
			fwhm[offset + j] = peakfind[j][%fwhm]
		endfor
		offset += numPeaks
	endfor

End
