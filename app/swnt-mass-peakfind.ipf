#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// require igor-common-utilities
// https://github.com/ukos-git/igor-common-utilities
#include "utilities-peakfind"
#include "utilities-peakfit"

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

Function/WAVE SMApeakFind(input, [info, verbose, createWaves])
	WAVE input
	STRUCT SMAinfo &info
	variable verbose, createWaves

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

	Duplicate/FREE input, wv

	if(verbose)
		printf "SMApeakFind(%s, verbose=%d)\r", GetWavesDatafolder(input, 2), verbose
	endif

	WAVE nospikes = Utilities#removeSpikes(wv)
	//WAVE nobackground = Utilities#RemoveBackground(nospikes)

	WAVE guess = Utilities#PeakFind(nospikes, maxPeaks = 2, minPeakPercent = 0.9, smoothingFactor = 1, verbose = verbose)
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
