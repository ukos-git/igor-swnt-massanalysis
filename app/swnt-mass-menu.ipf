#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Menu "CameraImage"
	// CTRL+0 is the keyboard shortcut
	"AddCoordinates/1", /Q, AddCoordinatesFromGraph()
	"Set WaveScale zero", /Q, SetScaleToCursor()
	"Process Coordinates", /Q, SMAprocessCoordinates()
	"PeakFind for coordinates", /Q, GetCoordinates()
End

Menu "GraphMarquee"
	"Erase Points", SMA_EraseMarqueeArea()
End
