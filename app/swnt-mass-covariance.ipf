#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function SMAcovariance()
	variable i, numXvalues

	NVAR numSpec = root:PLEMd2:gnumMapsAvailable
	STRUCT PLEMd2Stats stats

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))
	numXvalues = DimSize(stats.wavPLEM, 0)
	MAKE/O/N=(numSpec, numXvalues) root:source/WAVE=source
	MAKE/O/N=(numXvalues) root:sum1/WAVE=sum1
	MAKE/O/N=(numXvalues) root:sum2/WAVE=sum2

	for(i = numSpec - 1; i > -1; i -= 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		WAVE peaks = SMApeakFind(stats.wavPLEM, createwaves = 1)
		WAVE original = root:original
		WAVE nospikes = root:nospikes
		//WAVE nobackground = root:nobackground
		WAVE peakfit = root:peakfit
		WAVE residuum = root:residuum

		source[i][] = nospikes[q]
		sum1[] += nospikes[p]
		sum2[] += nospikes[p]^2
	endfor

	sum1 /= (numSpec - i)
	sum2 = sqrt(sum2)

	MatrixOP/O root:covariance_sym/WAVE=sym = syncCorrelation(source)
	MatrixOP/O root:covariance_asym/WAVE=asym = asyncCorrelation(source)

	MatrixOP/O root:covariance_sym_diag = getDiag(sym, 0)
	MatrixOP/O root:covariance_asym_diag = getDiag(asym, 0)
End
