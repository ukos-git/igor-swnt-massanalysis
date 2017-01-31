Window SMAintensityAnalysis() : Graph
	PauseUpdate; Silent 1		// building window...
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
