#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// Append the given spectra to a 2-dimensional wave.
//
// @param overwrite if set to 1: recreate the wave if it already exists
// @param range     specify the spectra ids with a numeric, uint wave
// @param fitable   1,0 set to create a source wave with improper spectral edges removed. This will alter the data.
Function/WAVE SMAgetSourceWave([overwrite, range, fitable])
	Variable overwrite
	WAVE/U/I range
	Variable fitable

	Variable i, dim1, dim2, numMarkers
	STRUCT PLEMd2Stats stats

	Variable dim0
	String name = "source"
	DFREF dfr = root:

	overwrite = ParamIsDefault(overwrite) ? 1 : !!overwrite
	fitable = ParamIsDefault(fitable) ? 0 : !!fitable
	if(ParamIsDefault(range))
		Make/FREE/U/I/N=(PLEMd2getMapsAvailable()) range = p
	endif
	dim0 = DimSize(range, 0)

	WAVE/Z wv = dfr:$name
	if(WaveExists(wv) && !overwrite)
		if(DimSize(wv, 0) == dim0)
			return wv
		endif
	endif

	PLEMd2statsLoad(stats, PLEMd2strPLEM(range[1]))
	if(fitable)
		WAVE PLEM = PLEMd2NanotubeRangePLEM(stats)
	else
		WAVE PLEM = stats.wavPLEM
	endif
	dim1 = DimSize(PLEM, 0)
	dim2 = DimSize(PLEM, 1)
	dim2 = dim2 == 0 ? 1 : dim2
	Make/O/N=(dim0, dim1 * dim2) dfr:$name/WAVE=wv
	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(range[i]))
		if(fitable)
			WAVE PLEM = removeSpikes(PLEMd2NanotubeRangePLEM(stats))
		else
			WAVE PLEM = stats.wavPLEM
		endif
		wv[i][0, DimSize(PLEM, 0) * DimSize(PLEM, 1) - 1] = PLEM[mod(q, dim1)][floor(q / dim1)]
	endfor

	DoWindow SMAsourceGraph
	if(V_flag == 0)
		SMAcopyWavelengthToRoot()
		Display/N=SMAsourceGraph
		if(dim2 == 1)
			AppendImage root:source vs {*, root:wavelengthImage}
		else
			AppendImage root:source vs {*, *}
		endif
		ModifyImage ''#0  ctab= {*,*,YellowHot256,1}
		numMarkers = round(DimSize(wv, 0) / 4)
		Make/O/N=(numMarkers) root:markers_source/WAVE=markers = p * 	11 + 6
		Make/O/N=(numMarkers)/T root:markers_sourceT/WAVE=markersT = num2str(p)
		ModifyGraph userticks(bottom)={markers,markersT}
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

Function SMAcovariance([normalized])
	Variable normalized

	if(ParamIsDefault(normalized))
		normalized=0
	endif

	STRUCT PLEMd2Stats stats
	PLEMd2statsLoad(stats, PLEMd2strPLEM(1))

	if(DimSize(stats.wavPLEM, 1) > 1)
		SMAcovarianceMaps()
		return 0
	endif

	WAVE source = SMAgetSourceWave(overwrite = 0)
	ImageFilter NanZapMedian source
	if(normalized)
		MatrixoP/O source = normalizeRows(source)
	endif

	MatrixOP/O root:covariance_sym/WAVE=sym = syncCorrelation(source)
	MatrixOP/O root:covariance_asym/WAVE=asym = asyncCorrelation(source)

	MatrixOP/O root:covariance_sym_diag/WAVE=symdiag = getDiag(sym, 0)
	MatrixOP/O root:covariance_asym_diag/WAVE=asymdiag = getDiag(asym, 0)

	SMAcopyWavelengthToRoot()

	SetScale/P x, DimOffset(stats.wavPLEM, 0), DimDelta(stats.wavPLEM, 0), sym, asym, symdiag, asymdiag
	SetScale/P y, DimOffset(stats.wavPLEM, 0), DimDelta(stats.wavPLEM, 0), sym, asym

	DoWindow SMAcovarianceGraphDiagonal
	if(V_flag == 0)
		Display/N=SMAcovarianceGraphDiagonal symdiag/TN=diag_syncCorrelation vs root:wavelength
	endif

	DoWindow SMAcovarianceGraph
	if(V_flag == 0)
		Display/N=SMAcovarianceGraph
		AppendImage/W=SMAcovarianceGraph sym
	endif
End

Function SMAcovarianceMaps()
	STRUCT PLEMd2Stats stats
	PLEMd2statsLoad(stats, PLEMd2strPLEM(1))
	WAVE PLEM = PLEMd2NanotubeRangePLEM(stats)

	WAVE source = SMAgetSourceWave(overwrite = 1, fitable = 1)
	ImageFilter NanZapMedian source

	// skip intermediate sym, asym due to space limitations

	MatrixOP/O root:covariance_sym_diag/WAVE=symdiag = getDiag(syncCorrelation(source), 0)
	MatrixOP/O root:covariance_asym_diag/WAVE=asymdiag = getDiag(asyncCorrelation(source), 0)

	// sym and asym have a non-monotonic wave scale
	Redimension/N=(DimSize(PLEM, 0), DimSize(PLEM, 1)) symdiag, asymdiag
	SetScale/P x, DimOffset(PLEM, 0), DimDelta(PLEM, 0), symdiag, asymdiag
	SetScale/P y, DimOffset(PLEM, 1), DimDelta(PLEM, 1), symdiag, asymdiag
	
	DoWindow SMAcovarianceImage
	if(V_flag == 0)
		Display/N=SMAcovarianceImage
		AppendImage/W=SMAcovarianceImage symdiag
		ModifyImage covariance_sym_diag ctab= {*,*,Terrain256,0}
	endif
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
