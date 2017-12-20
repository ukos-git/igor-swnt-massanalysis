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
StrConstant cstrSMAroot = "root:Packages:SMA:"

// call SMAread() directly.
Function SMAload()
	FILO#load(fileType = ".ibw", packageID = 1)
	if(!PLEMd2getMapsAvailable())
		SMAread()
	endif
End

Function SMAread()
	String file
	Variable numFiles, i
	STRUCT FILO#experiment filos

	FILO#structureLoad(filos)

	numFiles = ItemsInList(filos.strFileList)
	if(numFiles == 0)
		SMAload()
		return 0
	endif
	for(i = 0; i < numFiles; i += 1)
		file = StringFromList(i, filos.strFileList)
		PLEMd2Open(strFile = filos.strFolder + file, display = 0)
	endfor
	// hotfix for file load
	file = StringFromList(0, filos.strFileList)
	PLEMd2Open(strFile = filos.strFolder + file, display = 0)
End

Function SMAmapInfo()
	String strPLEM
	Variable i

	variable numSpectra = PLEMd2getMapsAvailable()
	STRUCT PLEMd2Stats stats
	STRUCT SMAinfo info

	SMAstructureLoad(info)
	info.numSpectra = numSpectra
	Redimension/N=(info.numSpectra) info.wavSpectra

	for(i = 0; i < numSpectra; i += 1)
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

	variable numSpec = PLEMd2getMapsAvailable()
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

Function SMAgetMaximum(bestEnergy)
	variable bestEnergy

	variable i, j, numPeaks
	variable peakEnergy, peakIntensity
	variable bestIntensity
	string secondBestPLEM, currentPLEM
	string bestPLEM = ""

	variable numSpec = PLEMd2getMapsAvailable()
	STRUCT PLEMd2Stats stats

	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	for(i = 0; i < numSpec; i += 1)
		currentPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, currentPLEM)
		WAVE nospikes = Utilities#removeSpikes(stats.wavPLEM)
		WAVE guess = Utilities#PeakFind(nospikes, maxPeaks = 10, minPeakPercent = 0.2, smoothingFactor = 1, verbose = 0)
		//WAVE peaks = SMApeakFind(stats.wavPLEM, createwaves = 0)
		numPeaks = DimSize(guess, 0)
		for(j = 0; j < numPeaks; j += 1)
			//peakEnergy = peaks[j][%position]
			//peakIntensity = peaks[j][%intensity]
			peakEnergy = guess[j][%wavelength]
			peakIntensity = guess[j][%height]
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

Function SMAreset([power])
	variable power

	String strPLEM
	Variable i

	variable numSpectra = PLEMd2getMapsAvailable()
	Struct PLEMd2Stats stats

	power = ParamIsDefault(power) ? 1 : !!power

	for(i = 0; i < numSpectra; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		stats.booBackground = 1
		stats.booPhoton = 0
		stats.booPower = power
		stats.booGrating = 0
		PLEMd2statsSave(stats)
		PLEMd2BuildMaps(strPLEM)
	endfor
End

Function SMAbackgroundMedian()
	String strPLEM
	Variable i

	variable numSpectra = PLEMd2getMapsAvailable()
	Struct PLEMd2Stats stats

	SMAreset(power = 1)
	WAVE globalMedian = SMAgetMedian(overwrite = 1)

	for(i = 0; i < numSpectra; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		stats.wavPLEM -= globalMedian
	endfor
End

Function SMABackgroundAncestor()
	String strPLEM, strPLEM2
	Variable i, previousmax

	Variable numSpectra = PLEMd2getMapsAvailable()
	Struct PLEMd2Stats stats
	Struct PLEMd2Stats stats2

	for(i = 0; i < numSpectra; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		stats.wavPLEM = stats.wavmeasure - stats.wavbackground
	endfor

	for(i = 2; i < numSpectra; i += 1)
		strPLEM = PLEMd2strPLEM(i-1)
		PLEMd2statsLoad(stats, strPLEM)
		previousmax = WaveMax(stats.wavPLEM)

		strPLEM2= PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats2, strPLEM2)

		stats.wavPLEM = stats.wavPLEM - stats2.wavPLEM/WaveMax(stats.wavPLEM) * previousmax
	endfor
End

Function SMAanalyse(min, max)
	Variable min, max

	Struct PLEMd2Stats stats
	String strPLEM, caption
	Variable i
	Variable numSpectra = PLEMd2getMapsAvailable()

	for(i = 1; i < numSpectra; i += 1)
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

Function/DF SMAgetPackageRoot()
	variable i, startFolder, numFolders
	string currentFolder = ""
	
	if(!DataFolderExists(cstrSMAroot))
		if(!cmpstr(cstrSMAroot[0,4], "root:"))
			startFolder = 1
			currentFolder = "root"
		endif
		numFolders = ItemsInList(cstrSMAroot, ":")
		for(i = startFolder; i < numFolders; i += 1)
			currentFolder += ":" + StringFromList(i, cstrSMAroot, ":")
			NewDataFolder/O $currentFolder
		endfor
	endif
	
	DFREF dfr = $cstrSMAroot

	return dfr
End

Function/WAVE SMAgetWaveMapsAvailable()
	variable numSpectra = PLEMd2getMapsAvailable()
	string strMaps = PLEMd2getStrMapsAvailable()
	
	DFREF dfr = SMAgetPackageRoot()

	if(numSpectra == 0)
		return $""
	endif

	WAVE/T/Z wv = dfr:mapsavailable
	if(WaveExists(wv))
		if(DimSize(wv, 0) == numSpectra)
			return wv
		endif
	endif
	
	Make/O/T/N=(numSpectra) dfr:mapsavailable/WAVE=wv = StringFromList(p, strMaps)

	return wv
End

Function/WAVE PLEMd2getWaveMapsSelected()
	variable numSpectra = PLEMd2getMapsAvailable()
	string strMaps = PLEMd2getStrMapsAvailable()

	DFREF dfr = SMAgetPackageRoot()

	if(numSpectra == 0)
		return $""
	endif

	WAVE/T/Z wv = dfr:mapsselected
	if(WaveExists(wv))
		if(DimSize(wv, 0) != numSpectra)
			Redimension/N=(numSpectra) dfr:mapsselected
		endif
		return wv
	endif

	Make/O/T/N=(numSpectra) dfr:mapsselection/WAVE=wv = StringFromList(p, strMaps)

	return wv
End

Function/WAVE PLEMd2getWaveMapsSelection()
	variable numSpectra = PLEMd2getMapsAvailable()
	string strMaps = PLEMd2getStrMapsAvailable()

	DFREF dfr = SMAgetPackageRoot()

	if(numSpectra == 0)
		return $""
	endif

	WAVE/Z wv = dfr:mapsselection
	if(WaveExists(wv))
		if(DimSize(wv, 0) != numSpectra)
			Redimension/N=(numSpectra) dfr:mapsselection 
		endif
		return wv
	endif

	Make/O/N=(numSpectra) dfr:mapsselection/WAVE=wv = 1

	return wv
End