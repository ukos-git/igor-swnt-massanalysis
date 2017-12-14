#include <ImageSlider>
#include <AxisSlider>
#include <Color Table Control Panel>

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
	AppendToGraph SMAcameraIntensitySmth
	ModifyGraph userticks(bottom)={SMAcameraPlanePeakMaximum,SMAcameraPlanePeakMaximumT}
	ModifyGraph userticks(top)={SMAcameraPlanePeakMaximumZ,SMAcameraPlanePeakMaximumZT}
	ModifyGraph mode(SMAcameraIntensity#1)=3
	ModifyGraph marker(SMAcameraIntensity#1)=8
	ModifyGraph lSize(SMAcameraIntensity)=2,lSize(SMAcameraIntensity#2)=2,lSize(SMAcameraIntensity#3)=2
	ModifyGraph rgb(SMAcameraIntensity#2)=(0,0,0),rgb(SMAcameraIntensity#3)=(1,16019,65535)
	ModifyGraph msize(SMAcameraIntensity#1)=2,msize(SMAcameraIntensity#2)=2,msize(SMAcameraIntensity#3)=2
	ModifyGraph grid(bottom)=1
	Label left "laser spot intensity"
	Label bottom "(x,y) position"
	Label top "z position"
EndMacro

Function SMAimageStackopenWindow()
	DoWindow win_SMAimageStack
	if(!V_flag)
		WMColorTableControlPanel#createColorTableControlPanel()
		Execute "win_SMAimageStack()"
		WMAppend3DImageSlider()
		WMAppendAxisSlider()
	endif
	DoWindow/F win_SMAimageStack
End

Window win_SMAimageStack() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(526.5,42.5,1184.25,643.25)
	AppendImage root:SMAimagestack
	ModifyImage SMAimagestack ctab= {0,254.9998,RedWhiteBlue256,0}
	ModifyImage SMAimagestack plane= 6
	ModifyGraph margin(right)=170
	ModifyGraph grid(left)=1
	ModifyGraph mirror(left)=2,mirror(bottom)=0
	ModifyGraph nticks=10
	ModifyGraph minor=1
	ModifyGraph fSize=8
	ModifyGraph standoff=0
	ModifyGraph gridRGB(left)=(26205,52428,1)
	ModifyGraph tkLblRot(left)=90
	ModifyGraph btLen=3
	ModifyGraph tlOffset=-2
	ModifyGraph manTick(left)={0,20,0,0},manMinor(left)={4,5}
	ColorScale/C/N=text0/F=0/A=MC/X=67.37/Y=-25.31 image=SMAimagestack, heightPct=50
	ColorScale/C/N=text0 axisRange={NaN,255,0}
	ControlBar 30
	PopupMenu selectColorTablePU,pos={681.00,69.00},size={200.00,19.00},proc=WMColorTableControlPanel#SelectColorTableProc
	PopupMenu selectColorTablePU,fSize=12
	PopupMenu selectColorTablePU,mode=14,value= #"\"*COLORTABLEPOPNONAMES*\""
	Slider lowSliderSC,pos={673.00,117.00},size={79.00,220.00},proc=SMAfullstackSliderProc
	Slider lowSliderSC,fSize=10,limits={0,255,0.579545},value= 77.65903
	Slider lowSliderSC,userTicks={:Packages:ColorTableControlPanel:WMSliderTicks,:Packages:ColorTableControlPanel:WMSliderTickLabels}
	Slider highSliderSC,pos={770.00,117.00},size={79.00,220.00},proc=SMAfullstackSliderProc
	Slider highSliderSC,fSize=10,limits={0,255,0.579545},value= 254.9998
	Slider highSliderSC,userTicks={:Packages:ColorTableControlPanel:WMSliderTicks,:Packages:ColorTableControlPanel:WMSliderTickLabels}
EndMacro

// derives from WMColorTableControlPanel#SliderProc
Function SMAfullstackSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa

	string target
	string colorPanel = "ColorTableControlPanel"
	string SMAfullimageGraph = "win_SMAimageStack"

	switch( sa.eventCode )
		case -1: // control being killed
			break
		case 9:  // mouse moved && mouse down
			DoWindow $colorPanel
			if(!V_flag)
				WMColorTableControlPanel#createColorTableControlPanel()
			endif
			Slider highSliderSC, win=$colorPanel, limits={0,255,1}
			Slider lowSliderSC, win=$colorPanel, limits={0,255,1}
			target = StringFromList(0, ImageNameList(SMAfullimageGraph, ";")) + "*"
			PopupMenu selectTracePU, win=$colorPanel, popmatch=target

			WMColorTableControlPanel#SliderProc(sa)

			break
	endswitch

	return 0
End
