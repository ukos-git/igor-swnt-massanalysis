#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Menu "CameraImage"
	// CTRL+1 is the keyboard shortcut
	"AddCoordinates/1", /Q, AddCoordinatesFromGraph()
	"Set WaveScale zero", /Q, SetScaleToCursor()
	"Process xyz coordinates", SMAtasksProcessCoordinates()
	"PeakFind for coordinates", /Q, GetCoordinates()
	"Correct Image overlap", /Q, SMAtestSizeAdjustment()
End

Menu "GraphMarquee"
	"Erase Points", SMA_EraseMarqueeArea()
	"Extract z-dimension", SMA_ExtractSumMarqueeArea()
End

Menu "MassAnalysis"
	"Calculate camerascan from TiltPlane", /Q, SMAtasksGetTiltPlane()
	"Load CameraScan", /Q, SMAmergeImages(0)
	"Load multiple CameraScans", SMAprocessImageStack()
	"Merge TimeSeries", SMAmergeTimeSeries()
	"Search focus (pointzero)", SMAtasksPointZero()
	"Select Spectra Panel", SMAopenPanelSelectWaves()
	"Histogram", SMAtasksHistogram()
End

Function SMAtasksHistogram()
	Make/O histResult = 0, fit_histResult = 0
	
	SVAR/Z diffwave = root:diffwave
	if(!SVAR_EXISTS(diffwave))
		String/G root:diffwave
		SVAR/Z diffwave = root:diffwave
	endif
	NVAR/Z checkbox_fit = root:checkbox_fit
	if(!NVAR_EXISTS(checkbox_fit))
		Variable/G root:checkbox_fit = 1
	endif	
	
	WAVE wv = SMA_PromptTrace()
	diffwave = GetWavesDataFolder(wv, 2)

	DoWindow/F SMAHistogram
	if(!V_flag)
		Execute "SMAHistogram()"
	endif
End

Function SMAtasksPointZero()
	SMAgetFocuspoints(graph = 1)
	Duplicate/O/R=[][2] root:SMAcameraIntensityCoordinates root:SMAcameraIntensityCoordinateZ/wave=coordinateZ
	Redimension/N=(-1, 0) coordinateZ
	Display/K=0 root:SMAcameraIntensitySmth vs coordinateZ
	WaveStats/Q root:SMAcameraIntensitySmth
	print "maximum", coordinateZ[V_maxloc], "um"
End

Function SMAtasksProcessCoordinates()
	RoundCoordinates(accuracy = 4)
	print "rounded coordinates"
	SortCoordinates()
	print "sorted coordinates"
	DeleteCoordinates(-5, 305)
	print "deleted range from -5um to 305um"
	SMAcalcZcoordinateFromTiltPlane()
	print "SMAcalcZcoordinateFromTiltPlane(zOffset = ", SMAcameraGetTiltPlane(0,0), ")"
End

Function SMAtasksGetTiltPlane()
	Variable numMaps = PLEMd2getMapsAvailable()

	// Tilt Plane Parameters could have been loaded from ibw files.
	WAVE/Z normal = root:SMAcameraPlaneNormal
	WAVE/Z distance = root:SMAcameraPlaneDistance
	if(!WaveExists(normal) || !WaveExists(distance))
		if(numMaps == 0)
			Execute "SMAread()"
			Execute "SMAreset()"
		endif
	endif
	Execute "SMAcameraCoordinates()"
End

Function SMAopenPanelSelectWaves()

	// create waves
	SMAgetWaveMapsAvailable()
	PLEMd2getWaveMapsSelected()
	PLEMd2getWaveMapsSelection()

	DoWindow SMAselectWaves
	if(!V_flag)
		Execute/Q "SMAselectWaves"
	endif
	DoWindow/F SMAselectWaves
End