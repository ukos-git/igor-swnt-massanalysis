#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Menu "CameraImage"
	// CTRL+0 is the keyboard shortcut
	"AddCoordinates/1", /Q, AddCoordinatesFromGraph()
	"Set WaveScale zero", /Q, SetScaleToCursor()
	"Process xyz coordinates", /Q, SMAprocessCoordinates()
	"PeakFind for coordinates", /Q, GetCoordinates()
	"Correct Image overlap", /Q, SMAtestSizeAdjustment()
End

Menu "GraphMarquee"
	"Erase Points", SMA_EraseMarqueeArea()
End

Menu "MassAnalysis"
	"Calculate camerascan from TiltPlane", /Q, SMAtasksGetTiltPlane()
	"Process Image Stack", SMAprocessImageStack()
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
