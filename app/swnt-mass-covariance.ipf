#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function/WAVE SMAgetSourceWave([overwrite])
	Variable overwrite

	Variable i, dim1
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
	Make/O/N=(dim0, dim1) dfr:$name/WAVE=wv
	for(i = 0; i < dim0; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		WAVE nospikes = Utilities#removeSpikes(stats.wavPLEM)
		wv[i][] = nospikes[q]
	endfor

	return wv
End

Function SMAcovariance()
	variable i, numXvalues
	variable numPoints

	Variable numSpec = PLEMd2getMapsAvailable()
	STRUCT PLEMd2Stats stats

	WAVE source = SMAgetSourceWave(overwrite = 1)

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	numXvalues = DimSize(stats.wavPLEM, 0)
	MAKE/O/N=(numXvalues) root:sum1/WAVE=sum1
	MAKE/O/N=(numXvalues) root:sum2/WAVE=sum2
	Duplicate/O stats.wavWavelength root:wavelength/WAVE=wavelength
	Duplicate/O stats.wavWavelength root:wavelengthImage/WAVE=wavelength_graph
	numPoints = DimSize(wavelength, 0)
	Redimension/N=(numPoints + 1) wavelength_graph
	wavelength_graph[numPoints] = wavelength_graph[numPoints - 1] + 1

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
		AppendImage sym vs {wavelength_graph, wavelength_graph}
	endif
	DoWindow SMAcovarianceGraphDiagonal
	if(V_flag == 0)
		Display/N=SMAcovarianceGraphDiagonal symdiag vs wavelength
	endif
End
