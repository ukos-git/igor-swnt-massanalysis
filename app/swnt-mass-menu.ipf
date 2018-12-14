#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Menu "CameraImage"
	// CTRL+1 is the keyboard shortcut
	"AddCoordinates/1", /Q, AddCoordinatesFromGraph()
	"Zero To Cursor", Utilities#SetScaleToCursor()
	"Process xyz coordinates", SMAtasksProcessCoordinates()
	"Merge Coordinates", SMAtasksMergeCoordinates()
	"PeakFind for coordinates", /Q, GetCoordinates()
	"Correct Image overlap", /Q, SMAtestSizeAdjustment()
	"GetHeight/2", SMAtasksPrintZposition()
End

Menu "GraphMarquee"
	"Erase Points", SMA_EraseMarqueeArea()
	"Extract z-dimension", SMA_ExtractSumMarqueeArea()
	"Display Original", SMAdisplayOriginal()
	"Duplicate", SMADuplicateRangeFromMarquee()
	"Wigner", SMAtasksCreateWigner()
End

Menu "MassAnalysis"
	"Load Spectra", SMAtasksLoadExactscan()
	"Load CameraScan", SMAprocessImageStack()

	"Load Tiltscan", /Q, SMAtasksGetTiltPlane()
	"Recalc TiltPlane", SMAcameraGetTiltPlaneParameters(createNew = 1)

	"Load PointZero", SMAtasksPointZero()
	"Load CameraScan (timeSeries to z)", SMAmergeTimeSeries()

	"Background: Median", SMABackgroundMedian(power = 0)

	"generate exactscan", SMAtasksGenerateExactscan()
	"convert excactscan to exactcoordinates", SMAtasksGenerateCoordinates()

	"Histogram", SMAtasksHistogram()

	"Simple Analysis", SMAquickAnalysis()
	"Best Peak Analysis", SMApeakAnalysis()
	"Single Peak Analysis", SMAsinglePeakAction(hcsr(A), hcsr(B))
	"Analyse Exactscan", SMApeakAnalysisExactscan()

	"Select Spectra Panel", SMAopenPanelSelectWaves()
End

Function SMAtasksCreateWigner()
	WAVE wv = SMAduplicateRange(SMAgetOriginalFromMarquee())
	if(!WaveExists(wv))
		Abort "Could not Duplicate Image"
	endif
	DelayUpdate
	Duplicate/O wv root:WignerSource
	KillWaves/Z wv
	SMAWigner(0, forceReNew = 1)
	DoWindow WignerGizmo
	if(!V_flag)
		Execute "	WignerGizmo()"
	endif
	DoWindow/F SMAwignerHor
	if(!V_flag)
		Execute "	SMAwignerHor()"
	endif
End

Function SMAtasksPrintZposition()
	print "(x,y)=", hcsr(a), ",", vcsr(a)
	print "z =", SMAcameraGetTiltPlane(hcsr(a), vcsr(a))
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

Function SMAtasksLoadExactscan()
	variable numMaps = PLEMd2getMapsAvailable()
	if(!numMaps)
		SMAread()
	endif
	SMAgetSourceWave(overwrite = 1)
	SMApeakAnalysisExactscan()
End

Function SMAtasksGenerateExactscan([wv])
	WAVE wv
	
	variable dim0, dim1
	variable resolution = 11
	variable stepsize = 0.5

	if(ParamIsDefault(wv))
		WAVE wv = root:coordinates
		print "SMAtasksGenerateExactscan(wv = root:coordinates)"
	endif
	if(!WaveExists(wv))
		print "SMAtasksGenerateExactscan: Can not find coordinates"
		return 1
	endif
	
	dim0 = DimSize(wv, 0)
	dim1 = DimSize(wv, 1)
	
	Make/O/N=(dim0 * resolution, dim1) root:exactscan/WAVE=exactscan
	exactscan[][] = wv[floor(p / resolution)][q]
	exactscan[][1] = wv[floor(p / resolution)][1] - (resolution - 1) / 2 * stepsize + mod(p, 11) * stepsize
	
	print "SMAcalcZcoordinateFromTiltPlane(wv = ", NameOfWave(exactscan), ", zOffset = ", SMAcameraGetTiltPlane(0,0), ")"
	SMAcalcZcoordinateFromTiltPlane(wv = exactscan)

	Save/J/O/DLIM=","/P=home exactscan as "exactscan.csv"

	return 0
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
		endif
	endif
	Execute "SMAreset(power=0, background=0)"
	Execute "	SMAcameraGetTiltPlaneParameters(createNew = 1)"
	Execute "SMAcameraCoordinates()"
End

// panel for handling different wave-sets in one igor experiment
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

// for coordinates from two camerascans.
Function SMAtasksMergeCoordinates()
	WAVE coordinates0, coordinates1, coordinates
	SMAMergeCoordinates(coordinates0, coordinates1)
End

// for coordinates from two camerascans.
// do not input root:coordinates!
Function/WAVE SMAMergeCoordinates(coordinates0, coordinates1)
	WAVE coordinates0, coordinates1
	
	WAVE/Z coordinates = root:coordinates
	if(WAVEExists(coordinates))
		duplicate/o coordinates root:coordinates_backup
	endif

	Variable dim00, dim01
	dim00 = DimSize(coordinates0, 0)
	dim01 = DimSize(coordinates1, 0)
	make/O/N=(dim00 + dim01, 3) root:coordinates/WAVE=coordinates

	coordinates[0, dim00 - 1] = coordinates0[p][q]
	coordinates[dim00,*] = coordinates1[p - dim00][q]
End

// exactscan --> exactcoordinates
Function SMAtasksGenerateCoordinates()
	WAVE exactscan = root:coordinates
	
	Duplicate/O exactscan root:exactcoordinates/WAVE=wv

	WAVE coordinates = PLEMd2getCoordinates()
	wv[][] = coordinates[exactscan[p][1]][q]

	print "SMAcalcZcoordinateFromTiltPlane(wv = ", GetWavesDataFolder(wv, 2), ", zOffset = ", SMAcameraGetTiltPlane(0,0), ")"

	print "Save/J/O/DLIM=\",\"/P=home ", GetWavesDataFolder(wv, 2), " as \"exactcoordinates.csv\""
	Save/J/O/DLIM=","/P=home wv as "exactcoordinates.csv"
End
