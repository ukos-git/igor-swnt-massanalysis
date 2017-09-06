Window SMAintensityAnalysis() : Graph
	PauseUpdate; Silent 1 // building window...
	Display /W=(240,50,784.5,445.25) as "intensity_analysis"
	AppendImage nanotubes_transposed
	ModifyImage nanotubes_transposed ctab= {0,315,Red,1}
	ModifyGraph margin(right)=141,width={Aspect,1}
	ModifyGraph grid=1
	ModifyGraph mirror=0
	SetAxis left -5,105
	SetAxis bottom -5,105
	ColorScale/C/N=text0/F=0/A=MC/X=67.56/Y=3.78 image=nanotubes_transposed
	SetDrawLayer UserFront
EndMacro

Window SMAcameraFocusPointsGraph() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(825.75,299.75,1220.25,508.25) SMAcameraIntensity[160,*] as "zAxisIntensityv2"
	AppendToGraph/T SMAcameraIntensity
	AppendToGraph SMAcameraIntensity[0,79],SMAcameraIntensity[80,159]
	ModifyGraph userticks(bottom)={SMAcameraPlanePeakMaximum,SMAcameraPlanePeakMaximumT}
	ModifyGraph userticks(top)={SMAcameraPlanePeakMaximumZ,SMAcameraPlanePeakMaximumZT}
	ModifyGraph mode(SMAcameraIntensity#1)=3
	ModifyGraph marker(SMAcameraIntensity#1)=8
	ModifyGraph lSize(SMAcameraIntensity)=2,lSize(SMAcameraIntensity#2)=2,lSize(SMAcameraIntensity#3)=2
	ModifyGraph rgb(SMAcameraIntensity#2)=(0,0,0),rgb(SMAcameraIntensity#3)=(1,16019,65535)
	ModifyGraph msize(SMAcameraIntensity#1)=2,msize(SMAcameraIntensity#2)=2,msize(SMAcameraIntensity#3)=2
	Label left "laser spot intensity"
	Label bottom "(x,y) position"
	Label top "z position"
EndMacro
