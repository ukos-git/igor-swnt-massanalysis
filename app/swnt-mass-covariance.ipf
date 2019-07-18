#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

static constant samplingAccuracy = 5e-2 // in nanometer

// Append the given spectra to a 2-dimensional wave.
//
// WARNING: Will alter the original data! (spikes, resample, interpolate)
//          Automatically resamples data only if it was not equally acquired
//          using different detectors, gratings, or excitation steps
//
// @param overwrite  if set to 1: recreate the wave if it already exists
// @param range      specify the spectra ids with a numeric, uint wave
// @param destName   Name of destination WAVE in root: data folder
// @param downsample set to force to a specific wavelength spacing
// @param graph      display a graph showing the source wave
Function/WAVE SMAgetSourceWave([overwrite, range, destName, downsample, graph])
	Variable overwrite
	WAVE/U/I range
	String destName
	Variable downsample, graph

	Variable i, j, dim0, dim1, dim2, numMarkers, scale, index, accuracy, err
	STRUCT PLEMd2Stats stats

	DFREF dfr = root:

	overwrite = ParamIsDefault(overwrite) ? 1 : !!overwrite
	graph = ParamIsDefault(graph) ? 1 : !!graph
	if(ParamIsDefault(range))
		Make/FREE/U/I/N=(PLEMd2getMapsAvailable()) range = p
	endif
	dim0 = DimSize(range, 0)
	if(ParamIsDefault(destName))
		destName = "source"
	endif
	WAVE/Z wv = dfr:$destName
	if(WaveExists(wv) && !overwrite)
		if(DimSize(wv, 0) == dim0)
			return wv
		endif
	endif

	if(dim0 > (2^32))
		Abort "SMAgetSourceWave: Too many spectra."
	endif

	STRUCT SMAsampling s
	SMAgetResamplingInformation(range, s, range = 1, verbose = 0)

	if(!ParamIsDefault(downsample))
		s.xDelta = max(s.xDelta, downsample)
		s.yDelta = max(s.yDelta, downsample)
	endif
	s.yDelta = numtype(s.yDelta) != 0 ? abs(s.yMax - s.yMin) : s.yDelta // undefined @c numExcitationStep in spectra

	dim1 = round(abs(s.xMax - s.xMin) / s.xDelta)
	dim2 = max(1, round(abs(s.yMax - s.yMin) / s.yDelta))
	if(dim0 * dim1 * dim2 > (2^32))
		if(dim0 * dim2 > (2^32))
			Abort "SMAgetSourceWave: Can not handle this many points."
		endif
		do // downsample x (x is always smaller than y due to setup constraints)
			s.xDelta *= 2
			dim1 = round(abs(s.xMax - s.xMin) / s.xDelta)
			if(s.xDelta > s.yDelta) // downsample y
				s.yDelta *= 2
				dim2 = max(1, round(abs(s.yMax - s.yMin) / s.yDelta))
			endif
		while(dim0 * dim1 * dim2 < (2^32))
	endif
	s.xSize = numtype(dim1) == 0 ? dim1 : 0
	s.ySize = numtype(dim2) == 0 ? dim2 : 0

	Make/FREE/N=(dim0, s.xSize * s.ySize) wv
	if(dim2 == 1)
		SetScale/I y, s.xMin, s.xMax, wv
	endif
	SMAsetSampling(wv, s)

	Make/FREE/N=(s.xSize, s.ySize) target
	Make/FREE/N=(s.xSize) targetX
	SetScale/I x, s.xMin, s.xMax, target, targetX
	SetScale/I y, s.yMin, s.yMax, target

	// fill source wave
	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(range[i]))
		WAVE PLEM = stats.wavPLEM

		// resample along excitation Δλ > 1, size < 48
		if(DimSize(PLEM, 1) > 2)
			accuracy = min(samplingAccuracy, stats.numEmissionStep / s.yDelta)
			try
				RatioFromNumber/MERR=(accuracy) stats.numEmissionStep / s.yDelta; AbortOnRTE
				Resample/DIM=1/UP=(V_numerator)/DOWN=(V_denominator)/N=3 PLEM; AbortOnRTE
			catch
				err = GetRTError(1)
				printf "SMAgetSourceWave: Failed to Resample %s from %d to %d/%d Error: %s\r", stats.strPLEM, DimSize(PLEM, 1), V_numerator, V_denominator, GetRTErrMessage()
			endtry
		endif

		// interpolate along emission Δλ < 1, size > 768
		//
		// first (and last) spectrum is garbage in PLE acquisition.
		// Fixed with https://github.com/ukos-git/labview-plem/commit/87b38e6f03b345e5c9823fa79b9dc358dbe251be
		target = median(PLEM) // we should have enough noise to fill missing values with median.
		for(j = 1; j < max(1, DimSize(PLEM, 1) - 1); j += 1)
			Duplicate/FREE/R=[][j] PLEM dummy
			Redimension/N=(-1, 0) dummy
			// T=1: linear interpolation
			// T=3: smoothing spline interpolation
			try
				Interpolate2/T=1/I=3/Y=targetX stats.wavWavelength, dummy; AbortOnRTE
			catch
				err = GetRTError(1)
				printf "SMAgetSourceWave: Error in interpolate2 for %d in %s\r", j, stats.strPLEM
				targetX = NaN
			endtry
			scale = IndexToScale(PLEM, j, 1)
			index = min(dim2 - 1, max(0, ScaleToIndex(target, scale, 1)))
			target[][index] = targetX[p]
		endfor
		WAVE PLEM = removeSpikes(target)

		// resample not necessary due to the previous interpolation but more failsafe
		accuracy = min(samplingAccuracy, DimSize(targetX, 0) / s.xSize)
		RatioFromNumber/MERR=(accuracy) DimSize(targetX, 0) / s.xSize
		Resample/DIM=0/UP=(V_numerator)/DOWN=(V_denominator)/N=3 PLEM

		Multithread wv[i][] = PLEM[mod(q, dim1)][floor(q / dim1)]
	endfor
	Duplicate/O wv dfr:$destName/WAVE=wv

	if(!graph)
		return wv
	endif

	DoWindow SMAsourceGraph
	if(V_flag == 0)
		SMAcopyWavelengthToRoot()
		Display/N=SMAsourceGraph
		AppendImage wv
		ModifyImage ''#0  ctab= {*,*,YellowHot256,1}
	endif

	return wv
End

Function SMARedimensionToMap(wv)
	WAVE wv

	Variable dim0, dim1v1, dim1v2, dim1

	STRUCT PLEMd2Stats stats
	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	dim0 = DimSize(stats.wavPLEM, 0)
	dim1 = round(DimSize(wv, 0) / dim0)
	Redimension/E=1/N=(dim0, dim1) wv

	SetScale/P x, DimOffset(stats.wavPLEM, 0), DimDelta(stats.wavPLEM, 0), wv
	SetScale/P y, DimOffset(stats.wavPLEM, 1), DimDelta(stats.wavPLEM, 1), wv
End

// @brief Covariance for indices with different detectors
//
// @param indices Wave holding the ids of PLEM spectra
Function SMAgetCovarianceForDifferentSetups(indices)
	WAVE/U/I indices

	Variable i, numMaps
	STRUCT PLEMd2Stats stats

	WAVE allDetectors = PLEMd2getDetectors()

	numMaps = DimSize(indices, 0)
	if(numMaps == 0)
		return 1
	endif
	Make/U/B/N=(numMaps)/FREE detectors = allDetectors[indices[p]]

	Extract/FREE indices, indicesSilicon, (detectors[p] == PLEMd2detectorNewton)
	WAVE autocorrelation = SMAcovariance(range = indicesSilicon, graph = 0)
	Duplicate/O autocorrelation root:covariance_si_diag
	WAVE/Z covariance = root:covariance_sym
	if(WaveExists(covariance))
		Duplicate/O covariance root:covariance_si
	endif

	Extract/FREE indices, indicesInGaAs, (detectors[p] == PLEMd2detectorIdus)
	WAVE autocorrelation = SMAcovariance(range = indicesInGaAs, graph = 0)
	Duplicate/O autocorrelation root:covariance_ingaas_diag
	WAVE/Z covariance = root:covariance_sym
	if(WaveExists(covariance))
		Duplicate/O covariance root:covariance_ingaas
	endif

	KillWaves/Z covariance, autocorrelation
	return 0
End

/// @brief calculate symmetric correlation spectra
///
/// NOTE: acts on downsampled data of 25nm spacing
///
/// @param normalized  divide all spectra by its maximum
/// @param range       specify the spectra ids with a numeric, uint wave
/// @returns a wave reference to the symmetric autocorrelation
Function/WAVE SMAcovariance([normalized, range, graph])
	Variable normalized, graph
	WAVE/U/I range

	Variable replacement
	STRUCT SMAsampling s

	if(ParamIsDefault(normalized))
		normalized = 1
	endif
	if(ParamIsDefault(graph))
		graph = 1
	endif

	NVAR/Z downsample = root:downsample
	if(ParamIsDefault(range))
		if(NVAR_EXISTS(downsample))
			WAVE source = SMAgetSourceWave(overwrite = 1, graph = 0, downsample = downsample)
		else
			WAVE source = SMAgetSourceWave(overwrite = 1, graph = 0)
		endif
	else
		if(NVAR_EXISTS(downsample))
			WAVE source = SMAgetSourceWave(overwrite = 1, range = range, graph = 0, downsample = downsample)
		else
			WAVE source = SMAgetSourceWave(overwrite = 1, range = range, graph = 0)
		endif
	endif

	if(numpnts(source) == 0)
		Duplicate/O source root:covariance_sym_diag/WAVE=symdiag
		return symdiag
	endif

	// there should be a decent amount of equal noise to remove NaNs
	StatsQuantiles/Q source
	replacement = V_Q25
	MatrixOP/O source = ReplaceNaNs(source, replacement)

	// normalize
	if(normalized)
		MatrixoP/O source = normalizeRows(source)
	endif

	SMAgetSampling(source, s)
	if(s.ySize > 1)
		return SMAcovarianceMaps(source)
	endif

	MatrixOP/O root:covariance_sym/WAVE=sym = syncCorrelation(source)
	MatrixOP/O root:covariance_sym_diag/WAVE=symdiag = getDiag(sym, 0)

	SMAcopyWavelengthToRoot()

	SetScale/P x, s.xMin, s.xDelta, sym, symdiag
	SetScale/P y, s.xMin, s.xDelta, sym

	if(graph)
		return symdiag
	endif

	DoWindow SMAcovarianceGraphDiagonal
	if(V_flag == 0)
		Display/N=SMAcovarianceGraphDiagonal symdiag/TN=diag_syncCorrelation
	endif

	DoWindow SMAcovarianceGraph
	if(V_flag == 0)
		Display/N=SMAcovarianceGraph
		AppendImage/W=SMAcovarianceGraph sym
	endif

	return symdiag
End

// @brief get the autocorrelation of a 2d maps wave
//
// @param source give source wave
// @return the symmetric autocorrelation
Function/WAVE SMAcovarianceMaps(source)
	WAVE source

	STRUCT SMAsampling s
	SMAgetSampling(source, s)

	if(DimSize(source, 0) > 1)
		//MatrixOP/O root:covariance_sym_diag/WAVE=symdiag = getDiag(syncCorrelation(source), 0)
		MatrixOP/O root:covariance_sym_diag/WAVE=symdiag = varCols(source)^t
	else
		Duplicate/O source root:covariance_sym_diag/WAVE=symdiag
	endif
	Redimension/N=(s.xSize, s.ySize)/E=1 symdiag
	SetScale/I x, s.xMin, s.xMax, symdiag
	SetScale/I y, s.yMin, s.yMax, symdiag

	DoWindow SMAcovarianceImage
	if(V_flag == 0)
		Display/N=SMAcovarianceImage
		AppendImage/W=SMAcovarianceImage symdiag
		ModifyImage covariance_sym_diag ctab= {*,*,Terrain256,0}
	endif

	return symdiag
End

// @brief structure with info for building source waves
//
// @see SMAgetResamplingInformation SMAgetSourceWave
static Structure SMAsampling
	Variable xMin, xDelta, xMax, xSize
	Variable yMin, yDelta, yMax, ySize
EndStructure

// @brief save the sampling information in the given wave.
//
// requires the JSON_XOP: http://docs.byte-physics.de/json-xop/
//
// @see SMAgetSamplin SMAsampling SMAcovarianceMaps SMAgetSourceWave
static Function SMAsetSampling(wv, s)
	WAVE wv
	STRUCT SMAsampling &s

	Variable jsonID
	String wavenote = Note(wv)

	if(strlen(wavenote) == 0)
		jsonID = JSON_New()
	else
		jsonID = JSON_Parse(wavenote, ignoreErr = 1)
	endif

	JSON_AddTreeObject(jsonID, "/scaling/x")
	JSON_SetVariable(jsonID,   "/scaling/x/min",   s.xMin)
	JSON_SetVariable(jsonID,   "/scaling/x/delta", s.xDelta)
	JSON_SetVariable(jsonID,   "/scaling/x/max",   s.xMax)
	JSON_SetVariable(jsonID,   "/scaling/x/size",  s.xSize)
	JSON_AddTreeObject(jsonID, "/scaling/y")
	JSON_SetVariable(jsonID,   "/scaling/y/min",   s.yMin)
	JSON_SetVariable(jsonID,   "/scaling/y/delta", s.yDelta)
	JSON_SetVariable(jsonID,   "/scaling/y/max",   s.yMax)
	JSON_SetVariable(jsonID,   "/scaling/y/size",  s.ySize)
	Note/K wv, JSON_Dump(jsonID)
	JSON_Release(jsonID)
End

// @brief get the sampling information back from the given wave.
//
// requires the JSON_XOP: http://docs.byte-physics.de/json-xop/
//
// @see SMAsetSampling SMAsampling SMAcovarianceMaps SMAgetSourceWave
static Function SMAgetSampling(wv, s)
	WAVE wv
	STRUCT SMAsampling &s

	Variable jsonID = JSON_Parse(Note(wv))
	s.xMin   = JSON_GetVariable(jsonID, "/scaling/x/min")
	s.xDelta = JSON_GetVariable(jsonID, "/scaling/x/delta")
	s.xMax   = JSON_GetVariable(jsonID, "/scaling/x/max")
	s.xSize  = JSON_GetVariable(jsonID, "/scaling/x/size")
	s.yMin   = JSON_GetVariable(jsonID, "/scaling/y/min")
	s.yDelta = JSON_GetVariable(jsonID, "/scaling/y/delta")
	s.yMax   = JSON_GetVariable(jsonID, "/scaling/y/max")
	s.ySize  = JSON_GetVariable(jsonID, "/scaling/y/size")
	JSON_Release(jsonID)
End

// @brief analyze a range of maps to get resampling information
//
// NOTE: for equally scaled wave sets taken with equal (detector, grating)
//       combination this function should yield the original wave scaling.
//       @todo: add unit test
//
// For covariance calculation and any averaging on maps or spectra taken with
// different detectors or gratings, the maps have to get aligned to get
// overlapping pixels. Note that this procedure assumes equally spaced input
// waves and is not accurate when acting i.e. on unequally spaced waves like
// the wavelength waves from the grating waves that are of quadratic or higher
// order distored along the wavelength scale.
//
// Assumes positive delta values
//
// @param[in]  indices  unsigned integer wave containing the ids of spectra
//                      to analyze
// @param[out] s        @see SMAsampling structure holding all acquired information
// @param[in]  range    respect fixed setup specific range (grating + detectors)
//                      @see PLEMd2NanotubeRangePLEM
// @param[in]  verbose  set output verbosity, default 1 (verbose)
Function SMAgetResamplingInformation(indices, s, [range, verbose])
	WAVE/U/I indices
	STRUCT SMAsampling &s
	Variable range, verbose

	Variable i, numMaps, dim0, newSamplingRate
	STRUCT PLEMd2Stats stats

	range = ParamIsDefault(range) ? 0 : !!range
	verbose = ParamIsDefault(verbose) ? 1 : !!verbose

	numMaps = DimSize(indices, 0)
	Make/D/N=(numMaps)/FREE xCRC, yCRC
	Make/N=(numMaps)/FREE excMin, excDelta, excMax, emiMin, emiDelta, emiMax
	for(i = 0; i < numMaps; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(indices[i]))

		// spectral emission intensity is called emi(ssion)
		emiMin[i] = stats.wavWavelength[0]
		emiMax[i] = stats.wavWavelength[DimSize(stats.wavWavelength, 0) - 1]
		emiDelta[i] = stats.numWLdelta // inaccurate (<0.5nm)
		if(range)
			emiMin[i] = max(emiMin[i], stats.numDetector == PLEMd2detectorNewton ? 820 : 950)
			emiMax[i] = min(emiMax[i], stats.numDetector == PLEMd2detectorNewton ? 1040 : 1250)
		endif
		xCRC[i] = StringCRC(0, num2str(stats.numGrating))
		xCRC[i] = StringCRC(xCRC[i], num2str(stats.numDetector))
		xCRC[i] = StringCRC(xCRC[i], num2str(stats.numWLcenter))

		// emission from light source is called exc(itation)
		excMin[i] = stats.numEmissionStart
		excMax[i] = stats.numEmissionEnd
		excDelta[i] = stats.numEmissionStep
		if(range)
			excMin[i] = max(excMin[i], 540)
			excMax[i] = min(excMax[i], 750)
		endif
		yCRC[i] = StringCRC(0, num2str(stats.numEmissionStep))
		yCRC[i] = StringCRC(yCRC[i], num2str(stats.numEmissionStart))
	endfor

	s.xMin    = WaveMin(emiMin)
	s.xMax    = WaveMax(emiMax)
	s.xDelta  = median(emiDelta)

	s.yMin    = WaveMin(excMin)
	s.yMax    = WaveMax(excMax)
	s.yDelta  = median(excDelta)

	if(numMaps < 2)
		return 0
	endif

	// output status information about experiment
	if(verbose)
		FindDuplicates/FREE/RN=grating xCRC
		dim0 = DimSize(grating, 0)
		if(dim0 > 1)
			printf "SMAgetResamplingInformation: %d different grating/detector setups\r", dim0
			for(i = 0; i < dim0; i += 1)
				Extract/FREE indices, sameXrange, xCRC[p] == grating[i]
				printf "%02d: %d maps\r", i, DimSize(sameXrange, 0)
			endfor
		endif
		FindDuplicates/FREE/RN=excitation yCRC
		dim0 = DimSize(excitation, 0)
		if(dim0 > 1)
			printf "SMAgetResamplingInformation: %d different excitation setups\r", dim0
			for(i = 0; i < dim0; i += 1)
				Extract/FREE excMin, sameYrange, yCRC[p] == excitation[i]
				printf "%02d: %d maps\r", i, DimSize(sameYrange, 0)
			endfor
		endif
	endif

	// find best sampling rate for different delta y
	//
	// do not do such things for xDelta as we can accept the error there but
	// not in y where spacing is allowed up to 50nm.
	excDelta[] = round(excDelta[p] / samplingAccuracy)
	s.yDelta  = median(excDelta)
	FindDuplicates/FREE/TOL=0/RN=excDeltaUnique excDelta
	dim0 = DimSize(excDeltaUnique, 0)
	for(i = 0; i < dim0; i += 1)
		newSamplingRate = excDeltaUnique[i]
		if(mod(newSamplingRate, s.yDelta) != 0)
			s.yDelta = gcd(s.yDelta, newSamplingRate )
		endif
	endfor
	FindDuplicates/FREE/TOL=0/RN=excOffsetUnique excMin
	dim0 = DimSize(excOffsetUnique, 0)
	for(i = 1; i < dim0; i += 1)
		newSamplingRate = abs(excOffsetUnique[i] - excOffsetUnique[i - 1])
		if(mod(newSamplingRate, s.yDelta) != 0)
			s.yDelta = gcd(s.yDelta, newSamplingRate )
		endif
	endfor
	s.yDelta *= samplingAccuracy
End

// copy the wavelength from PLEM
// this should be a PLEMd2 function
//
// @param numPLEM [optional] specify the id of the spectrum where wavelength comes from.
Function/WAVE SMAcopyWavelengthToRoot([numPLEM])
	variable numPLEM

	variable numPoints
	STRUCT PLEMd2Stats stats

	numPLEM = ParamIsDefault(numPLEM) ? 0 : numPLEM

	PLEMd2statsLoad(stats, PLEMd2strPLEM(numPLEM))

	Duplicate/O stats.wavWavelength root:wavelength/WAVE=wavelength

	// @todo: delete wavelengthImage here as it adds wrong assumtion. Instead use SetScale where 2D Waves need to be plotted.
	Duplicate/O stats.wavWavelength root:wavelengthImage/WAVE=wavelength_graph
	numPoints = DimSize(wavelength, 0)
	Redimension/N=(numPoints + 1) wavelength_graph
	wavelength_graph[numPoints] = wavelength_graph[numPoints - 1] + 1

	return wavelength
End

// copy the excitation wavelength from PLEM
// this should be a PLEMd2 function
//
// @param numPLEM [optional] specify the id of the spectrum where wavelength comes from.
Function/WAVE SMAcopyExcitationToRoot([numPLEM])
	variable numPLEM

	variable numPoints
	STRUCT PLEMd2Stats stats

	numPLEM = ParamIsDefault(numPLEM) ? 0 : numPLEM

	PLEMd2statsLoad(stats, PLEMd2strPLEM(numPLEM))
	if(DimSize(stats.wavPLEM, 1) < 2)
		Abort "Not a PLE map"
	endif

	Duplicate/O stats.wavWavelength root:excitation/WAVE=excitation

	// @todo: delete wavelengthImage here as it adds wrong assumtion. Instead use SetScale where 2D Waves need to be plotted.
	Duplicate/O stats.wavExcitation root:excitationImage/WAVE=excitation_image
	numPoints = DimSize(excitation, 0)
	Redimension/N=(numPoints + 1) excitation_image
	excitation_image[numPoints] = excitation_image[numPoints - 1] + 1

	return excitation
End
