#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Menu "CameraImage"
	// CTRL+1 is the keyboard shortcut
	"AddCoordinates/1", /Q, AddCoordinatesFromGraph()
	"Set WaveScale zero", /Q, SetScaleToCursor()
	"Process xyz coordinates", SMAtasksProcessCoordinates()
	"Merge Coordinates", SMAtasksMergeCoordinates()
	"PeakFind for coordinates", /Q, GetCoordinates()
	"Correct Image overlap", /Q, SMAtestSizeAdjustment()
	"GetHeight/2", SMAtasksPrintZposition()
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
	"generate exactscan", SMAtasksGenerateExactscan()
	"load exactscan", SMAtasksLoadExactscan()
	"convert excactscan to exactcoordinates", SMAtasksGenerateCoordinates()
	"Histogram", SMAtasksHistogram()
	"Maps: Quick Analysis", SMAquickAnalyseMap()
End

Function SMAquickAnalyseMap()
	variable i, numMaps
	
	Struct PLEMd2stats stats
	
	numMaps = Plemd2getMapsAvailable()
	smareset(power=1)

	make/O/N=(numMaps) root:intensity/WAVE=intensity
	make/O/N=(numMaps) root:emission/WAVE=emi
	make/O/N=(numMaps) root:excitation/WAVE=exc
	for(i=0; i < numMaps; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		
		duplicate/FREE/R=[][6,*]stats.wavPLEM, corrected
		smooth 255, corrected

		WaveStats/Q corrected
		print V_maxRowLoc, V_maxColLoc
		intensity[i] = V_max
		emi[i] = V_maxRowLoc
		exc[i] = V_maxColLoc
		
		print i, PLEMd2strPLEM(i), V_max, V_maxRowLoc, V_maxColLoc
	endfor
	
	DoWindow/F SMAmapAnalysis
	if(!V_flag)
		Display/N=SMAmapAnalysis
		AppendToGraph exc vs emi
		ModifyGraph mode=3,marker=19,zColor(excitation)={intensity,*,*,YellowHot,0}
		SetAxis bottom 800,1100
		SetAxis left 500,750
	endif
end

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
	SMAbackgroundMedian()
	SMAgetSourceWave(overwrite = 1)
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
	
	dim0 = DimSize(wv, 0)
	dim1 = DimSize(wv, 1)
	
	Make/O/N=(dim0 * resolution, dim1) root:exactscan/WAVE=exactscan
	exactscan[][] = wv[floor(p / resolution)][q]
	exactscan[][1] = wv[floor(p / resolution)][1] - (resolution - 1) / 2 * stepsize + mod(p, 11) * stepsize
	
	print "SMAcalcZcoordinateFromTiltPlane(wv = ", NameOfWave(exactscan), ", zOffset = ", SMAcameraGetTiltPlane(0,0), ")"
	SMAcalcZcoordinateFromTiltPlane(wv = exactscan)

	Save/J/O/DLIM=","/P=home exactscan as "exactscan.csv"
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
			Execute "SMAreset(power=0)"
		endif
	endif
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
	
	print GetWavesDataFolder(wv, 2)
	Save/J/O/DLIM=","/P=home wv as "exactcoordinates.csv"
End
