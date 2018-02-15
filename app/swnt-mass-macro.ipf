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

Function ListBoxProc_SMAselect(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			WAVE selectedMaps = PLEMd2getWaveMapsSelection()
			Extract listWave, selectedMaps, selWave[p] == 1
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function ButtonProc_SMAselectPower(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Window SMAselectWaves() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /W=(306,137,806,237) as "select waves"
	ListBox mapsAvailable,pos={0.00,0.00},size={200.00,100.00},proc=ListBoxProc_SMAselect
	ListBox mapsAvailable,userdata(ResizeControlsInfo)= A"!!*'\"z!!#AW!!#@,z!!#](Aon\"Qzzzzzzzzzzzzzz!!#`-A7TLfzz"
	ListBox mapsAvailable,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	ListBox mapsAvailable,userdata(ResizeControlsInfo) += A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	ListBox mapsAvailable,listWave=root:Packages:SMA:mapsavailable
	ListBox mapsAvailable,selWave=root:Packages:SMA:mapsselected,mode= 4
	ListBox mapsSelected,pos={206.00,0.00},size={200.00,100.00}
	ListBox mapsSelected,userdata(ResizeControlsInfo)= A"!!,G^z!!#AW!!#@,z!!#`-A7TLfzzzzzzzzzzzzzz!!#o2B4uAezz"
	ListBox mapsSelected,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	ListBox mapsSelected,userdata(ResizeControlsInfo) += A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	ListBox mapsSelected,listWave=root:Packages:SMA:mapsselection
	Button extractpower,pos={414.00,2.00},size={81.00,25.00},proc=ButtonProc_SMAselectPower,title="extract power"
	Button extractpower,userdata(ResizeControlsInfo)= A"!!,I5!!#7a!!#?[!!#=+z!!#o2B4uAezzzzzzzzzzzzzz!!#o2B4uAezz"
	Button extractpower,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#u:Du]k<zzzzzzzzzzz"
	Button extractpower,userdata(ResizeControlsInfo) += A"zzz!!#u:Du]k<zzzzzzzzzzzzzz!!!"
	SetWindow kwTopWin,hook(ResizeControls)=ResizeControls#ResizeControlsHook
	SetWindow kwTopWin,userdata(ResizeControlsInfo)= A"!!*'\"z!!#C_!!#@,zzzzzzzzzzzzzzzzzzzzz"
	SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzzzzzzzz"
	SetWindow kwTopWin,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzzzzzzzzz!!!"
	Execute/Q/Z "SetWindow kwTopWin sizeLimit={375,75,inf,inf}" // sizeLimit requires Igor 7 or later
EndMacro

Window SMAHistogram() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(256.5,314.75,653.25,522.5) fit_histResult,histResult,histResult as "SMAHistogram"
	ModifyGraph mode(histResult#1)=5
	ModifyGraph lSize(fit_histResult)=2,lSize(histResult)=2
	ModifyGraph rgb(fit_histResult)=(65535,0,0,32768),rgb(histResult)=(0,0,0)
	NewPanel/HOST=#/EXT=0/W=(0,0,78,278) 
	Slider slider0,pos={16.00,30.00},size={54.00,244.00},proc=SMAHistogramSliderProc
	Slider slider0,limits={0,25,1},value= 1
	CheckBox check_fit,pos={20.00,11.00},size={26.00,15.00},title="fit"
	CheckBox check_fit,variable= checkbox_fit
	RenameWindow #,P0
	SetActiveSubwindow ##
EndMacro

Function SMAHistogramSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa
	
	variable resolution = 0.05
	variable width = 11
	SVAR/Z diffwave = root:diffwave
	if(!SVAR_EXists(diffwave))
		return 0
	endif
	NVAR checkbox_fit = root:checkbox_fit

	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			if( sa.eventCode & 1 ) // value set
				Variable curval = sa.curval
				wave wv = $diffwave
				Duplicate/O wv diff
				wave histResult
				
				diff = p < curval ? 0 : wv[p] - wv[p - curval]
				Histogram/B={-(width - 1)/2,resolution,abs((width - 1)/resolution)} diff, histResult
				if(checkbox_fit)
					CurveFit/M=2/W=0 lor, histResult/D
				endif
			endif
			break
	endswitch

	return 0
End