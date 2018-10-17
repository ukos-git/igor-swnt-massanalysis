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
	SetAxis left 0,*
	Label left "laser spot intensity"
	Label bottom "(x,y) position"
	Label top "z position"
EndMacro

Function SMAimageStackopenWindow()
	NVAR/Z numSizeAdjustment = root:numSizeAdjustment
	if(!NVAR_EXISTS(numSizeAdjustment))
		Variable/G root:numSizeAdjustment = 1
	endif
	NVAR/Z numSizeAdjustmentSingleStack = root:numSizeAdjustmentSingleStack
	if(!NVAR_EXISTS(numSizeAdjustmentSingleStack))
		Variable/G root:numSizeAdjustmentSingleStack = 0
	endif

	DoWindow win_SMAimageStack
	if(!V_flag)
		Execute "win_SMAimageStack()"
		ControlBar 0

		WMAppendAxisSlider()
		ModifyControl WMAxSlSl proc=SliderProcSMAimageStackX

		WAVE/Z imagestack = root:SMAimagestack
		if(WaveExists(imagestack) && (DimSize(imagestack, 2) > 1))
			WMAppend3DImageSlider()
		endif

		WMColorTableControlPanel#createColorTableControlPanel()
	endif
	DoWindow/F win_SMAimageStack
End

Window win_SMAimageStack() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(261.6,180.8,816.6,619.4)
	AppendImage SMAimagestack
	ModifyImage SMAimagestack ctab= {0,196.418918918919,RedWhiteBlue256,0}
	ModifyImage SMAimagestack plane= 1
	ModifyGraph margin(right)=170,width={Aspect,1}
	ModifyGraph grid(left)=1
	ModifyGraph mirror(left)=2,mirror(bottom)=0
	ModifyGraph nticks=10
	ModifyGraph minor=1
	ModifyGraph fSize=8
	ModifyGraph standoff=0
	ModifyGraph axOffset(left)=0.428571
	ModifyGraph gridRGB(left)=(26205,52428,1)
	ModifyGraph tkLblRot(left)=90
	ModifyGraph btLen=3
	ModifyGraph tlOffset=-2
	ModifyGraph manTick(left)={0,20,0,0},manMinor(left)={4,5}
	ModifyGraph manTick(bottom)={0,20,0,0},manMinor(bottom)={4,0}
	SetAxis bottom -25.0880129730861,285.262665759946
	Cursor/P/I A SMAimagestack 187,193
	ColorScale/C/N=text0/F=0/A=MC/X=67.37/Y=-25.31 image=SMAimagestack, heightPct=50
	ColorScale/C/N=text0 axisRange={NaN,255,0}
	TextBox/C/N=zAxis/F=0/A=LT/X=103.13/Y=0.77 "\\JL\\Z24z=147µm"
	ControlBar 45
	GroupBox CBSeparator0,pos={0.00,0.00},size={600.00,2.40}
	GroupBox CBSeparator1,pos={0.00,0.00},size={597.00,2.40}
	Slider WMAxSlSl,pos={49.80,9.00},size={526.80,6.00},proc=SliderProcSMAimageStackX
	Slider WMAxSlSl,limits={0,1,0},value= 0.435838150289017,side= 0,vert= 0,ticks= 0
	PopupMenu WMAxSlPop,pos={9.60,4.80},size={15.60,15.60},proc=WMAxSlPopProc
	PopupMenu WMAxSlPop,mode=0,value= #"\"Instructions...;Set Axis...;Zoom Factor...;Resync position;Resize;Remove\""
	SetDrawLayer UserFront
	SetDrawEnv linethick= 5
	DrawLine 1.25144203951618,0.35850622406639,1.10248370618284,0.35850622406639
	DrawLine 148,0.1,150,0.1
	SetDrawEnv fsize= 24
	DrawText 1.11534780391897,0.338713821409761,"0µm"
	NewPanel/HOST=#/EXT=0/W=(0,0,216,438.6)  as "sizeAdjustment"
	ModifyPanel cbRGB=(65534,65534,65534), fixedSize=0
	SetDrawLayer UserBack
	DrawLine 15,99,124.2,99
	Button sizeAdjustment,pos={24.00,75.00},size={99.00,18.00},proc=ButtonProcSizeAdjustment,title="sizeAdjustment"
	SetVariable cnumSizeAdjustment,pos={6.00,12.00},size={186.60,13.80}
	SetVariable cnumSizeAdjustment,limits={0.9,1.1,0.001},value= numSizeAdjustment
	CheckBox checkSizeAdjustment,pos={33.00,51.00},size={80.40,12.00},title="only current stack"
	CheckBox checkSizeAdjustment,variable= numSizeAdjustmentSingleStack
	Button save,pos={456.00,54.00},size={75.00,24.00},proc=ButtonProcSMAImageStackSave,title="simple save"
	Button save,labelBack=(65535,65535,65535)
	Button save1,pos={18.00,117.00},size={75.00,24.00},proc=ButtonProcSMAImageStackSave,title="simple save"
	Button save1,labelBack=(65535,65535,65535)
	SetVariable cnumRotationAdjustment,pos={6.00,27.00},size={184.20,13.80}
	SetVariable cnumRotationAdjustment,limits={-5,5,0.1},value= numRotationAdjustment
	CheckBox SMAimagestack_check_fullcalc,pos={36.60,169.80},size={42.00,12.00},title="full calc"
	CheckBox SMAimagestack_check_fullcalc,variable= numFullCalcultions
	RenameWindow #,P0
	SetActiveSubwindow ##
	NewPanel/HOST=#/EXT=1/W=(18.6,0,0,438.6)  as "controls"
	ModifyPanel cbRGB=(65534,65534,65534), fixedSize=0
	Slider WMAxSlY,pos={6.00,6.00},size={6.00,408.00},proc=SliderProcSMAimageStackY
	Slider WMAxSlY,limits={0,1,0},value= 0.644677661169415,side= 0,ticks= 0
	RenameWindow #,P1
	SetActiveSubwindow ##
EndMacro

Function SliderProcSMAimageStackY(sa) : SliderControl
	STRUCT WMSliderAction &sa

	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			if( sa.eventCode & 1 ) // value set
				String grfName= WinName(0, 1)
				SVAR axisName = root:Packages:WMAxisSlider:$(grfName):gAxisName
				axisName = "left"
				WMAxisSliderProc(sa.ctrlName, sa.curval, sa.eventCode)
			endif
			break
	endswitch

	return 0
End

Function SliderProcSMAimageStackX(sa) : SliderControl
	STRUCT WMSliderAction &sa

	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			if( sa.eventCode & 1 ) // value set
				String grfName= WinName(0, 1)
				SVAR axisName = root:Packages:WMAxisSlider:$(grfName):gAxisName
				axisName = "bottom"
				WMAxisSliderProc(sa.ctrlName, sa.curval, sa.eventCode)
			endif
			break
	endswitch

	return 0
End

Function ButtonProcSMAImageStackSave(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR cnumLayer = root:Packages:WM3DImageSlider:win_SMAimageStack:gLayer
	
	variable i
	variable numLayers = 8 // hard coded
	variable zaxis

	switch( ba.eventCode )
		case 2: // mouse up

		for(i = 0; i < numLayers; i += 1)
			cnumLayer=i
			WM3DImageSliderProc("",0,0)
			zaxis = 150 - i * 0.5 // hard coded
			TextBox/C/N=zAxis "\\JL\\Z24z=" + num2str(round(zaxis * 10)/10) + "µm"
			SavePICT/O/P=home/E=-5/B=288 as "mkl12_focusscan_" + num2str(round(zaxis * 10)) + ".png"
		endfor
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ButtonProcSizeAdjustment(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	variable numLayer = 0
	NVAR singleStack = root:numSizeAdjustmentSingleStack
	NVAR/Z cnumLayer = root:Packages:WM3DImageSlider:win_SMAimageStack:gLayer
	if(NVAR_EXISTS(cnumLayer))
		numLayer = cnumLayer
	endif

	switch( ba.eventCode )
		case 2: // mouse up

			smareset()
			WAVE coordinates = PLEMd2getCoordinates(forceRenew = 0)

			if(singleStack)
				Wave fullimage = SMAmergeStack(coordinates, 2, 24)
				WAVE imagestack = root:SMAimagestack
				MultiThread imagestack[][][numLayer] = fullimage[p][q]
			else
				SMAprocessImageStack(coordinates = coordinates, createNew = 1)
				//SMAtestsizeAdjustment()
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

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
	
	variable resolution = 2.5
	variable width = 100
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