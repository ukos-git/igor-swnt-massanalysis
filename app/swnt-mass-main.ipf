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
	string secondBestPLEM, currentPLEM
	string bestPLEM = ""

	NVAR numSpec = root:PLEMd2:gnumMapsAvailable
	STRUCT PLEMd2Stats stats

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	for(i = 0; i < numSpec; i += 1)
		currentPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, currentPLEM)
		WAVE peaks = SMApeakFind(stats.wavPLEM, createwaves = 0)
		numPeaks = DimSize(peaks, 0)
		for(j = 0; j < numPeaks; j += 1)
			peakEnergy = peaks[j][%position]
			peakIntensity = peaks[j][%intensity]
			if(abs(peakEnergy - bestEnergy) < 5)
				print currentPLEM
				if(peakIntensity > bestIntensity)
					bestIntensity = peakIntensity
					secondBestPLEM = bestPLEM
					bestPLEM = currentPLEM
				endif
			endif
		endfor
	endfor
	PLEMd2Display(bestPLEM)
	PLEMd2Display(secondBestPLEM)
End

Function SMAgetCoordinates()
	String strPLEM
	Variable i, j, k, startX, numPeaks, numCoords

	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")
	STRUCT PLEMd2Stats stats
	STRUCT SMAinfo info

	SMAstructureLoad(info)
	info.numSpectra = gnumMapsAvailable * 40
	Redimension/N=(info.numSpectra) info.wavSpectra
	Make/N=(10240, 4) root:coordinates/Wave=wavCoordinates
	for(i = 0; i < gnumMapsAvailable; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		startX = round(stats.numPositionX) - 40
		startX -= mod(startX, 2)
		for(j = startX; j < startX + 80; j += 2)
			Duplicate/FREE/R=[][ScaleToIndex(stats.wavPLEM, j, 1)] stats.wavPLEM, currentLine
			Redimension/N=(DimSize(stats.wavPLEM, 0)) currentLine
			//SetScale/P x, DimOffset(stats.wavPLEM, 1), DimDelta(stats.wavPLEM, 1), currentLine
			wave peakResult = SMApeakFind(currentLine, verbose = 0)
			numPeaks = DimSize(peakResult, 0)
			if(DimSize(wavCoordinates, 0) < numCoords + numPeaks)
				Redimension/N=(numcoords) wavCoordinates
			endif
			for(k = 0; k < numPeaks; k += 1)
				wavCoordinates[(numCoords + k)][0] = peakResult[k][%position]
				wavCoordinates[(numCoords + k)][1] = j
				wavCoordinates[(numCoords + k)][2] = stats.numPositionZ
				wavCoordinates[(numCoords + k)][3] = peakResult[k][%intensity]
			endfor
			numCoords += numPeaks
		endfor
	endfor

	SMAstructureSave(info)
End

Function SMAreset()
	String strPLEM
	Variable i

	NVAR gnumMapsAvailable = $(cstrPLEMd2root + ":gnumMapsAvailable")
	Struct PLEMd2Stats stats

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

Function SMAmedianBackground()
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

Function SMAancestorBackground()
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
