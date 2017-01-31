// Version 0: rough analysis tool

#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma IndependentModule=SMA

#include "ILAv2main"

Function load()
	ILAv2#Load()
End

Function read()
	STRUCT ILAv2#ILAv2experiment ila
	String file
	Variable numFiles, i
	ILAv2#StructureLoad(ila)

	numFiles = ItemsInList(ila.strFileList)
	for(i = 0; i < numFiles; i+=1)
		file = StringFromList(i, ila.strFileList)
		PLEMd2Open(strFile = ila.strFolder + file, display = 0)
	endfor
End

Function myCorrection()
	String strPLEM
	Variable i

	NVAR gnumMapsAvailable	 = $(cstrPLEMd2root + ":gnumMapsAvailable")
	Struct PLEMd2Stats stats

	print gnumMapsAvailable
	for(i = 0; i < gnumMapsAvailable; i += 1)
		strPLEM = PLEMd2strPLEM(i)
		PLEMd2statsLoad(stats, strPLEM)
		stats.booBackground = 0
		stats.booPhoton = 0
		stats.booGrating = 0
		PLEMd2statsSave(stats)
		PLEMd2BuildMaps(strPLEM)
	endfor
End
Function reset()
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


Function myBackground()
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

Function analyse(min, max)
	Variable min, max

	Struct PLEMd2Stats stats
	String strPLEM, caption
	Variable i
	NVAR gnumMapsAvailable	 = $(cstrPLEMd2root + ":gnumMapsAvailable")

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

Function killAllWindows()
	String myWindow
	Variable i

	for(i=0; i<400; i += 1)
		myWindow = "Graph" + num2str(i)
		myWindow = "win_spectra50_00_" + num2str(i)
		KillWindow/Z $myWindow
	endfor
End
