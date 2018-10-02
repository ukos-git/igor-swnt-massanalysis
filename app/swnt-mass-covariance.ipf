#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function/WAVE SMAgetSourceWave([overwrite])
	Variable overwrite

	Variable i, dim1, dim2, numMarkers
	STRUCT PLEMd2Stats stats

	Variable dim0 = PLEMd2getMapsAvailable()
	String name = "source"
	DFREF dfr = root:

	overwrite = ParamIsDefault(overwrite) ? 0 : !!overwrite

	WAVE/Z wv = dfr:$name
	if(WaveExists(wv) && !overwrite)
		if(DimSize(wv, 0) == dim0)
			return wv
		endif
	endif

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	dim1 = DimSize(stats.wavPLEM, 0)
	dim2 = DimSize(stats.wavPLEM, 1)
	dim2 = dim2 == 0 ? 1 : dim2
	Make/O/N=(dim0, dim1 * dim2) dfr:$name/WAVE=wv
	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		WAVE nospikes = Utilities#removeSpikes(stats.wavPLEM)
		wv[i][] = nospikes[mod(q, dim1)][floor(q / dim1)]
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
	variable i, numXvalues

	Variable numSpec = PLEMd2getMapsAvailable()
	STRUCT PLEMd2Stats stats

	WAVE source = SMAgetSourceWave(overwrite = 1)

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	numXvalues = DimSize(stats.wavPLEM, 0)
	MAKE/O/N=(numXvalues) root:sum1/WAVE=sum1
	MAKE/O/N=(numXvalues) root:sum2/WAVE=sum2

	SMAcopyWavelengthToRoot()

	for(i = 0; i < numSpec; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		WAVE nospikes = Utilities#removeSpikes(stats.wavPLEM)

		sum1[] += nospikes[p]
		sum2[] += nospikes[p]^2
	endfor

	sum1 = sum1 / numSpec
	sum2 = sqrt(sum2 / numSpec)

	ImageFilter NanZapMedian source

	MatrixOP/O root:covariance_sym/WAVE=sym = syncCorrelation(source)
	MatrixOP/O root:covariance_asym/WAVE=asym = asyncCorrelation(source)

	MatrixOP/O root:covariance_sym_diag/WAVE=symdiag = getDiag(sym, 0)
	MatrixOP/O root:covariance_asym_diag = getDiag(asym, 0)

	DoWindow SMAcovarianceGraph
	if(V_flag == 0)
		Display/N=SMAcovarianceGraph
		AppendImage sym vs {root:wavelengthImage, root:wavelengthImage}
	endif
	DoWindow SMAcovarianceGraphDiagonal
	if(V_flag == 0)
		Display/N=SMAcovarianceGraphDiagonal symdiag vs root:wavelength
	endif
End

// copy the wavelength from PLEM
// this should be a PLEMd2 function
Function/WAVE SMAcopyWavelengthToRoot()
	variable numPoints
	STRUCT PLEMd2Stats stats

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	Duplicate/O stats.wavWavelength root:wavelength/WAVE=wavelength
	Duplicate/O stats.wavWavelength root:wavelengthImage/WAVE=wavelength_graph
	numPoints = DimSize(wavelength, 0)
	Redimension/N=(numPoints + 1) wavelength_graph
	wavelength_graph[numPoints] = wavelength_graph[numPoints - 1] + 1
	
	return wavelength
End
