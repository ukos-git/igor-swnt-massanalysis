#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function SMAcovariance()
	variable i, numXvalues
	variable numPoints

	Variable numSpec = PLEMd2getMapsAvailable()
	STRUCT PLEMd2Stats stats

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	numXvalues = DimSize(stats.wavPLEM, 0)
	MAKE/O/N=(numSpec, numXvalues) root:source/WAVE=source
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

		source[i][] = nospikes[q]
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
