#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function/WAVE SMAgetSourceWave([overwrite])
	Variable overwrite

	Variable i, dim1, dim2, numMarkers
	STRUCT PLEMd2Stats stats

	Variable dim0 = PLEMd2getMapsAvailable()
	String name = "source"
	DFREF dfr = root:

	overwrite = ParamIsDefault(overwrite) ? 1 : !!overwrite

	WAVE/Z wv = dfr:$name
	if(WaveExists(wv) && !overwrite)
		if(DimSize(wv, 0) == dim0)
			return wv
		endif
	endif

	PLEMd2statsLoad(stats, PLEMd2strPLEM(1))
	dim1 = DimSize(stats.wavPLEM, 0)
	dim2 = DimSize(stats.wavPLEM, 1)
	dim2 = dim2 == 0 ? 1 : dim2
	Make/O/N=(dim0, dim1 * dim2) dfr:$name/WAVE=wv
	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		WAVE nospikes = Utilities#removeSpikes(stats.wavPLEM)
		wv[i][0, DimSize(nospikes, 0) * DimSize(nospikes, 1) - 1] = nospikes[mod(q, dim1)][floor(q / dim1)]
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

Function SMAcovariance()
	STRUCT PLEMd2Stats stats
	PLEMd2statsLoad(stats, PLEMd2strPLEM(1))

	if(DimSize(stats.wavPLEM, 1) > 1)
		SMAcovarianceMaps()
		return 0
	endif

	WAVE source = SMAgetSourceWave(overwrite = 1)
	ImageFilter NanZapMedian source

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

	WAVE source = SMAgetSourceWave(overwrite = 1)
	ImageFilter NanZapMedian source

	// skip intermediate sym, asym due to space limitations

	MatrixOP/O root:covariance_sym_diag/WAVE=symdiag = getDiag(syncCorrelation(source), 0)
	MatrixOP/O root:covariance_asym_diag/WAVE=asymdiag = getDiag(asyncCorrelation(source), 0)

	// sym and asym have a non-monotonic wave scale
	Redimension/N=(DimSize(stats.wavPLEM, 0), DimSize(stats.wavPLEM, 1)) symdiag, asymdiag
	SetScale/P x, DimOffset(stats.wavPLEM, 0), DimDelta(stats.wavPLEM, 0), symdiag, asymdiag
	SetScale/P y, DimOffset(stats.wavPLEM, 1), DimDelta(stats.wavPLEM, 1), symdiag, asymdiag
	
	DoWindow SMAcovarianceImage
	if(V_flag == 0)
		Display/N=SMAcovarianceImage
		AppendImage/W=SMAcovarianceImage symdiag
		ModifyImage covariance_sym_diag ctab= {*,*,Terrain256,0}
	endif
End

// copy the wavelength from PLEM
// this should be a PLEMd2 function
Function/WAVE SMAcopyWavelengthToRoot()
	variable numPoints
	STRUCT PLEMd2Stats stats

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	Duplicate/O stats.wavWavelength root:wavelength/WAVE=wavelength

	// @todo: delete wavelengthImage here as it adds wrong assumtion. Instead use SetScale where 2D Waves need to be plotted.
	Duplicate/O stats.wavWavelength root:wavelengthImage/WAVE=wavelength_graph
	numPoints = DimSize(wavelength, 0)
	Redimension/N=(numPoints + 1) wavelength_graph
	wavelength_graph[numPoints] = wavelength_graph[numPoints - 1] + 1
	
	return wavelength
End
