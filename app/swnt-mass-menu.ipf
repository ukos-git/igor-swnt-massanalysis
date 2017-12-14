#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Menu "CameraImage"
	// CTRL+0 is the keyboard shortcut
	"AddCoordinates/1", /Q, AddCoordinatesFromGraph()
	"Set WaveScale zero", /Q, SetScaleToCursor()
	"Process xyz coordinates", /Q, SMAtasksProcessCoordinates()
	"PeakFind for coordinates", /Q, GetCoordinates()
	"Correct Image overlap", /Q, SMAtestSizeAdjustment()
End

Menu "GraphMarquee"
	"Erase Points", SMA_EraseMarqueeArea()
End

Menu "MassAnalysis"
	"Calculate camerascan from TiltPlane", /Q, SMAtasksGetTiltPlane()
	"Load single CameraScan", /Q, SMAmergeImages(0)
	"Process Image Stack", SMAprocessImageStack()
	"Search focus", SMAtasksPointZero()
End

Function SMAtasksPointZero()
	SMAgetFocuspoints()
	Duplicate/O/R=[][2] root:SMAcameraIntensityCoordinates root:SMAcameraIntensityCoordinateZ/wave=coordinateZ
	Redimension/N=(-1, 0) coordinateZ
	Display/K=0 root:SMAcameraIntensitySmth vs coordinateZ
	WaveStats/Q root:SMAcameraIntensitySmth
	print "maximum", coordinateZ[V_maxloc], "um"
End

Function SMAtasksProcessCoordinates()
	RoundCoordinates(accuracy = 4)
	SortCoordinates()
	DeleteCoordinates(-5, 305)
	print "zero at ", SMAcameraGetTiltPlane(0,0)
	SMAcalcZcoordinateFromTiltPlane()
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
