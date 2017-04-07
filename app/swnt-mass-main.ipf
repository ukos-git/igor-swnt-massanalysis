#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// requires IM FILO (igor-file-loader)
// https://github.com/ukos-git/igor-file-loader
#include "FILOmain"
#include "FILOprefs"
#include "FILOstructure"
#include "FILOtools"
// requires PLEM (igor-swnt-plem)
// https://github.com/ukos-git/igor-swnt-plem

strConstant cSMApackage = "swnt-mass-analysis"

Function SMAload()
	FILO#load(fileType = ".ibw", packageID = 1)
End

Function SMAread()
	String file
	Variable numFiles, i
	STRUCT FILO#experiment filos

	FILO#structureLoad(filos)

	numFiles = ItemsInList(filos.strFileList)
	for(i = 0; i < numFiles; i += 1)
		file = StringFromList(i, filos.strFileList)
		PLEMd2Open(strFile = filos.strFolder + file, display = 0)
	endfor
End

Function SMAmapInfo()
	String strPLEM
	Variable i

	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")
	STRUCT PLEMd2Stats stats
	STRUCT SMAinfo info

	SMAstructureLoad(info)
	info.numSpectra = gnumMapsAvailable
	Redimension/N=(info.numSpectra) info.wavSpectra

	for(i = 0; i < gnumMapsAvailable; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		info.wavSpectra[i] = stats.wavPLEM
	endfor

	SMAstructureSave(info)
End

Function SMAgetBestSpectra(bestEnergy)
	variable bestEnergy

	variable i, j, numPeaks
	variable peakEnergy, peakIntensity
	variable bestIntensity
	string bestPLEM, currentPLEM

	NVAR numSpec = root:PLEMd2:gnumMapsAvailable
	STRUCT PLEMd2Stats stats

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	for(i = 0; i < numSpec; i += 1)
		currentPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, currentPLEM)
		WAVE peaks = SMApeakFind(stats.wavPLEM, createwaves = 0)
		numPeaks = DimSize(peaks, 0)
		for(j = 0; j < numPeaks; j += 1)
			peakEnergy = peaks[i][%position]
			peakIntensity = peaks[i][%intensity]
			if(abs(peakEnergy - bestEnergy) < 2)
				if(peakIntensity > bestIntensity)
					bestIntensity = peakIntensity
					bestPLEM = currentPLEM
					print currentPLEM
				endif
			endif
		endfor
	endfor
	PLEMd2Display(bestPLEM)
End

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

Function SMAcorrection()
	String strPLEM
	Variable i

	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")
	Struct PLEMd2Stats stats

	print gnumMapsAvailable
	for(i = 0; i < gnumMapsAvailable; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		stats.booBackground = 1
		stats.booPhoton = 0
		stats.booPower = 1
		stats.booGrating = 0
		PLEMd2statsSave(stats)
		PLEMd2BuildMaps(strPLEM)
	endfor
End

Function SMAreset()
	String strPLEM
	Variable i

	NVAR gnumMapsAvailable	 = $(cstrPLEMd2root + ":gnumMapsAvailable")
	Struct PLEMd2Stats stats

	for(i = 0; i < gnumMapsAvailable; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		stats.wavPLEM = stats.wavmeasure - stats.wavbackground
	endfor
End

Function SMAbackground()
	String strPLEM, strPLEM2
	Variable i, previousmax

	NVAR gnumMapsAvailable	 = $(cstrPLEMd2root + ":gnumMapsAvailable")
	Struct PLEMd2Stats stats
	Struct PLEMd2Stats stats2

	for(i = 0; i < gnumMapsAvailable; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		stats.wavPLEM = stats.wavmeasure - stats.wavbackground
	endfor

	for(i = 2; i < gnumMapsAvailable; i += 1)
		strPLEM = PLEMd2strPLEM(i-1)
		PLEMd2statsLoad(stats, strPLEM)
		Wavestats/Q stats.wavPLEM
		previousmax = V_max

		strPLEM2= PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats2, strPLEM2)
		Wavestats/Q stats2.wavPLEM

		stats.wavPLEM = stats.wavPLEM - stats2.wavPLEM/V_max * previousmax
	endfor
End

Function SMAanalyse(min, max)
	Variable min, max

	Struct PLEMd2Stats stats
	String strPLEM, caption
	Variable i
	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")

	for(i = 1; i < gnumMapsAvailable; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		Wavestats/Q stats.wavPLEM
		if((V_max > min) && (V_max < max))
			PLEMd2DisplayByNum(i)
			caption = stats.strPLEM +" at\r(x,y) = " + num2str(stats.numPositionX) + ", " + num2str(stats.numPositionY) + ""
			TextBox/C/N=text0/F=0/B=1/A=RT/X=0.00/Y=0.00 caption
		endif
	endfor
End

Function SMAkillAllWindows()
	String myWindow
	Variable i

	for(i=0; i<400; i += 1)
		myWindow = "Graph" + num2str(i)
		myWindow = "win_spectra50_00_" + num2str(i)
		KillWindow/Z $myWindow
	endfor
End
