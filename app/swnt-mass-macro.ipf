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

		WMAppendAxisSlider()

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
	Display /W=(451.8,164.6,925.2,642.2)
	AppendImage SMAimagestack
	ModifyImage SMAimagestack ctab= {0,255,RedWhiteBlue256,0}
	ModifyGraph width={Plan,1,bottom,left},height=396.85
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
	ControlBar 45
	GroupBox CBSeparator0,pos={0.00,0.00},size={472.80,2.40}
	Slider WMAxSlSl,pos={49.80,9.00},size={402.60,6.00},proc=WMAxisSliderProc
	Slider WMAxSlSl,limits={0,1,0},value= 0.5,side= 0,vert= 0,ticks= 0
	PopupMenu WMAxSlPop,pos={9.60,4.80},size={15.60,15.60},proc=WMAxSlPopProc
	PopupMenu WMAxSlPop,mode=0,value= #"\"Instructions...;Set Axis...;Zoom Factor...;Resync position;Resize;Remove\""
	NewPanel/HOST=#/EXT=0/W=(0,0,216,438.6)  as "sizeAdjustment"
	ModifyPanel cbRGB=(65534,65534,65534), fixedSize=0
	SetDrawLayer UserBack
	SetDrawEnv dash= 6,fillfgc= (61166,61166,61166)
	DrawRect 15,87,186,145.8
	DrawText 37.2,109.8,"scaling"
	Button mergeImageStack,pos={54.00,297.00},size={99.00,18.00},proc=ButtonProcMergeImages,title="mergeImageStack"
	SetVariable cnumSizeAdjustment,pos={6.00,12.00},size={186.00,13.80}
	SetVariable cnumSizeAdjustment,limits={0.9,1.1,0.001},value= numSizeAdjustment
	CheckBox checkSizeAdjustment,pos={33.00,51.00},size={80.40,12.00},title="only current stack"
	CheckBox checkSizeAdjustment,variable= numSizeAdjustmentSingleStack
	Button save,pos={456.00,54.00},size={75.00,24.00},proc=ButtonProcSMAImageStackSave,title="simple save"
	Button save,labelBack=(65535,65535,65535)
	Button save1,pos={54.00,343.80},size={99.00,18.00},proc=ButtonProcSMAImageStackSave,title="simple save"
	Button save1,labelBack=(65535,65535,65535)
	SetVariable cnumRotationAdjustment,pos={6.00,27.00},size={186.00,13.80}
	SetVariable cnumRotationAdjustment,limits={-5,5,0.1},value= numRotationAdjustment
	CheckBox SMAimagestack_check_fullcalc,pos={30.00,66.00},size={42.00,12.00},title="full calc"
	CheckBox SMAimagestack_check_fullcalc,variable= numFullCalcultions
	Button sizeAdjustment,pos={54.00,321.00},size={99.00,18.00},proc=ButtonProcSizeAdjustment,title="sizeAdjustment"
	SetVariable cnumMin,pos={36.00,120.00},size={60.00,13.80},title="min"
	SetVariable cnumMin,limits={0,255,1},value= numMinValue
	SetVariable cnumMax,pos={102.00,120.00},size={60.00,13.80},title="max"
	SetVariable cnumMax,limits={0,255,1},value= numMaxValue
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
				SVAR/Z axisName = root:Packages:WMAxisSlider:$(grfName):gAxisName
				if(!SVAR_EXISTS(axisName))
					break
				endif
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
	
	NVAR/Z cnumLayer = root:Packages:WM3DImageSlider:win_SMAimageStack:gLayer
	if(!NVAR_EXISTS(cnumLayer))
		return 0
	endif
	
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

Function ButtonProcMergeImages(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	variable numLayer = 0
	NVAR singleStack = root:numSizeAdjustmentSingleStack
	NVAR/Z cnumLayer = root:Packages:WM3DImageSlider:win_SMAimageStack:gLayer
	if(NVAR_EXISTS(cnumLayer))
		numLayer = cnumLayer
	endif

	switch( ba.eventCode )
		case 2: // mouse up
			smareset(power = 0, photon = 0)
			WAVE coordinates = PLEMd2getCoordinates(forceRenew = 0)

			if(singleStack)
				Wave fullimage = SMAmergeStack(coordinates, numLayer, 24)
				WAVE imagestack = root:SMAimagestack
				MultiThread imagestack[][][numLayer] = fullimage[p][q]
			else
				SMAprocessImageStack(coordinates = coordinates, createNew = 1)
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ButtonProcSizeAdjustment(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			SMAtestsizeAdjustment()
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

Window SMAwignerHor() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(1803,147.2,2486.4,1053.2)/L=left_LineProfileHor LineProfileHor as "SMAwignerHor"
	AppendToGraph/L=left_WignerProfileSumHor WignerProfileSumHor
	AppendImage/L=left_WignerImageHor WignerImageHor
	ModifyImage WignerImageHor ctab= {-10000000000,10000000000,RedWhiteBlue,0}
	AppendImage WignerSource
	ModifyImage WignerSource ctab= {*,*,BlueHot,0}
	ModifyImage WignerSource minRGB=0,maxRGB=NaN
	AppendImage/L=left_WignerHor WignerProfileHor
	ModifyImage WignerProfileHor ctab= {-39810717055349.7,39810717055349.7,RedWhiteBlue,0}
	ModifyGraph margin(left)=42,margin(right)=127,width={Plan,1,bottom,left}
	ModifyGraph grid(bottom)=1,grid(left_WignerImageHor)=1,grid(left)=1
	ModifyGraph mirror(bottom)=0,mirror(left)=0
	ModifyGraph nticks(left_LineProfileHor)=0,nticks(bottom)=2,nticks(left_WignerProfileSumHor)=0
	ModifyGraph nticks(left_WignerImageHor)=2,nticks(left)=2,nticks(left_WignerHor)=0
	ModifyGraph minor(bottom)=1
	ModifyGraph noLabel(bottom)=2,noLabel(left_WignerImageHor)=2,noLabel(left)=2
	ModifyGraph axOffset(left)=2.61538
	ModifyGraph gridRGB(bottom)=(34952,34952,34952),gridRGB(left_WignerImageHor)=(34952,34952,34952)
	ModifyGraph gridRGB(left)=(34952,34952,34952)
	ModifyGraph axRGB(bottom)=(0,0,0,0),axRGB(left_WignerProfileSumHor)=(65535,65535,65535,0)
	ModifyGraph axRGB(left_WignerImageHor)=(0,0,0,0),axRGB(left)=(0,0,0,0)
	ModifyGraph lblPosMode(left_LineProfileHor)=1,lblPosMode(left_WignerHor)=1
	ModifyGraph lblPos(bottom)=49,lblPos(left)=67,lblPos(left_WignerHor)=34
	ModifyGraph lblLatPos(left_WignerHor)=13
	ModifyGraph freePos(left_LineProfileHor)={0,kwFraction}
	ModifyGraph freePos(left_WignerProfileSumHor)={0,kwFraction}
	ModifyGraph freePos(left_WignerImageHor)={0,kwFraction}
	ModifyGraph freePos(left_WignerHor)={0,kwFraction}
	ModifyGraph axisEnab(left_LineProfileHor)={0.25,0.4}
	ModifyGraph axisEnab(left_WignerProfileSumHor)={0.85,1}
	ModifyGraph axisEnab(left_WignerImageHor)={0.6,0.85}
	ModifyGraph axisEnab(left)={0,0.25}
	ModifyGraph axisEnab(left_WignerHor)={0.4,0.6}
	ModifyGraph manTick(left_LineProfileHor)={0,0,0,2},manMinor(left_LineProfileHor)={0,50}
	ModifyGraph manTick(bottom)={0,2,0,0},manMinor(bottom)={0,50}
	ModifyGraph manTick(left_WignerProfileSumHor)={0,0,0,2},manMinor(left_WignerProfileSumHor)={0,50}
	ModifyGraph manTick(left_WignerImageHor)={0,2,0,0},manMinor(left_WignerImageHor)={0,50}
	ModifyGraph manTick(left)={0,2,0,0},manMinor(left)={0,0}
	ModifyGraph manTick(left_WignerHor)={0,0,0,2},manMinor(left_WignerHor)={0,50}
	Label left_LineProfileHor "spacial emission\rintensity [a.u]"
	Label left_WignerHor "momentum [1/µm]\r(k-space)"
	Cursor/P/I/S=2/H=3/NUML=2 A WignerProfileHor -1194,8
	ColorScale/C/N=WignerProfileColorScale/F=0/A=LB/X=74.01/Y=38.01/E=2
	ColorScale/C/N=WignerProfileColorScale image=WignerProfileHor, heightPct=25
	ColorScale/C/N=WignerProfileColorScale nticks=1, minor=1, prescaleExp=-12
	ColorScale/C/N=WignerProfileColorScale tickUnit=1, ZisZ=1
	AppendText "Wigner Intensity"
	ColorScale/C/N=WignerImageScaleBar/F=0/A=LB/X=74.45/Y=61.16/E=2
	ColorScale/C/N=WignerImageScaleBar image=WignerImageHor, heightPct=25, nticks=3
	ColorScale/C/N=WignerImageScaleBar highTrip=10, notation=1, ZisZ=1
	AppendText "Wigner Intensity |8⟩"
	ColorScale/C/N=imageColorScale/F=0/A=LB/X=74.01/Y=3.88/E=2 image=WignerSource
	ColorScale/C/N=imageColorScale heightPct=25
	AppendText "intensity [a.u.]"
	SetDrawLayer UserFront
	SetDrawEnv linethick= 4,linefgc= (65535,65535,65535),fillfgc= (0,0,0),fsize= 16,textrgb= (65535,65535,65535)
	SetDrawEnv gstart,gname= scalebarBottom
	DrawLine 0.1,0.777306733167082,0.3,0.777306733167082
	SetDrawEnv fsize= 16,textrgb= (65535,65535,65535)
	DrawText 0.133442126514132,0.800504987531172,"0µm"
	SetDrawEnv linethick= 4,linefgc= (65535,65535,65535),fillfgc= (0,0,0),fsize= 16,textrgb= (65535,65535,65535)
	SetDrawEnv gstop
	SetDrawEnv gstart,gname= scalebarTop
	SetDrawEnv linefgc= (0,0,0)
	DrawLine 0.1,0.177556109725685,0.3,0.177556109725685
	SetDrawEnv fsize= 16
	DrawText 0.133442126514132,0.200754364089775,"0µm"
	SetDrawEnv linethick= 4,linefgc= (65535,65535,65535),fillfgc= (0,0,0),fsize= 16,textrgb= (65535,65535,65535)
	SetDrawEnv gstop
	SetDrawEnv gstart,gname= wigner_selection
	SetDrawEnv xcoord= prel,ycoord= left_WignerHor,fillfgc= (65535,65535,65535,32768)
	DrawRect 0,0.51098896382061,1,0.579120825663358
	SetDrawEnv gstop
	NewPanel/HOST=#/EXT=1/W=(30,0,0,567) 
	ModifyPanel fixedSize=0
	SetDrawLayer UserBack
	SetDrawEnv gstart,gname= wigner_selection
	DrawRect 0.05,1.19586670935928,0.95,1.29552226847255
	SetDrawEnv gstop
	Slider slider0,pos={0.00,18.00},size={38.40,498.00},proc=SMASliderProcWignerHor
	Slider slider0,limits={0,64,1},value= 8
	RenameWindow #,P0
	SetActiveSubwindow ##
EndMacro

Function SMASliderProcWignerHor(sa) : SliderControl
	STRUCT WMSliderAction &sa

	switch( sa.eventCode )
		case -1: // control being killed
			break
		default:
			if( sa.eventCode & 1 ) // value set
				Variable curval = sa.curval
				DelayUpdate
				SMAWigner(sa.curval)

				WAVE wv = root:WignerImageHor
				Variable scaleEven = getEvenScale(wv)
				ModifyImage/W=SMAwignerHor WignerImageHor ctab= {-1 * scaleEven, scaleEven,RedWhiteBlue,0}
				DoWindow WignerGizmo
				if(V_flag)
					ModifyGizmo/N=WignerGizmo ModifyObject=WignerImage,objectType=surface,property={surfaceMaxRGBA, scaleEven, 0, 0, 1, 1}
					ModifyGizmo/N=WignerGizmo ModifyObject=WignerImage,objectType=surface,property={surfaceMinRGBA, -1 * scaleEven, 1, 0, 0, 1}
				endif
				WAVE wv = root:WignerProfileHor
				scaleEven = getEvenScale(wv)
				ModifyImage/W=SMAwignerHor WignerProfileHor ctab= {-1 * scaleEven,scaleEven,RedWhiteBlue,0}

				WAVE wv = root:WignerProfileHor
				Cursor/W=SMAwignerHor/I A WignerProfileHor 115.42, IndexToScale(wv, sa.curval, 1)
				ColorScale/W=SMAwignerHor/C/N=WignerImageScaleBar "Wigner Intensity |" + num2str(sa.curval) + "⟩"

				SetDrawLayer/W=SMAwignerHor UserFront
				DrawAction/W=SMAwignerHor getgroup=wigner_selection, delete
				if(sa.curval > 26)
					break
				endif
				SetDrawEnv/W=SMAwignerHor gstart, gname=wigner_selection
					SetDrawEnv/W=SMAwignerHor xcoord= prel,ycoord= left_WignerHor
					SetDrawEnv/W=SMAwignerHor fillfgc= (65535,65535,65535,32768)
					Variable rectStart = DimOffset(wv, 1) + (sa.curval - 0.5) * DimDelta(wv, 1)
					Variable rectEnd   = DimOffset(wv, 1) + (sa.curval + 0.5) * DimDelta(wv, 1)
					DrawRect/W=SMAwignerHor 0, rectStart, 1, rectEnd
				SetDrawEnv/W=SMAwignerHor gstop
			endif
			break
	endswitch

	return 0
End


Window WignerGizmo() : GizmoPlot
	PauseUpdate; Silent 1		// building window...
	// Building Gizmo 7 window...
	NewGizmo/T="WignerGizmo"/W=(1119.6,235.4,1609.8,474.8)
	ModifyGizmo startRecMacro=700
	ModifyGizmo scalingOption=63
	AppendToGizmo Surface=root:WignerImageHor,name=WignerImage
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ lineColorType,1}
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ fillMode,3}
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ lineWidth,2}
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ srcMode,0}
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ lineColor,0.666667,0.666667,0.666667,1}
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ surfaceCTab,RedWhiteBlue256}
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ SurfaceCTABScaling,100}
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ surfaceMinRGBA,-1e+10,1,0,0,1}
	ModifyGizmo ModifyObject=WignerImage,objectType=surface,property={ surfaceMaxRGBA,1e+10,0,0,1,1}
	ModifyGizmo modifyObject=WignerImage,objectType=Surface,property={calcNormals,1}
	AppendToGizmo Axes=boxAxes,name=axes0
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={-1,axisScalingMode,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={-1,axisColor,0,0,0,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={0,ticks,3}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={1,ticks,3}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={2,ticks,3}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={0,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={1,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={2,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={3,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={4,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={5,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={6,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={7,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={8,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={9,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={10,visible,0}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={11,visible,0}
	ModifyGizmo modifyObject=axes0,objectType=Axes,property={-1,Clipped,0}
	ModifyGizmo setDisplayList=0, object=axes0
	ModifyGizmo setDisplayList=1, object=WignerImage
	ModifyGizmo autoscaling=1
	ModifyGizmo currentGroupObject=""
	ModifyGizmo showInfo
	ModifyGizmo infoWindow={1863,0,2695,313}
	ModifyGizmo endRecMacro
	ModifyGizmo SETQUATERNION={0.551374,-0.180123,-0.254025,0.773960}
EndMacro

Window SMAmapsSum() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(412.5,56.75,799.5,303.5) peakExcitation vs peakEmission as "SMAmapsSum"
	AppendImage mapsSum
	ModifyImage mapsSum ctab= {0,*,Spectrum,0}
	ModifyGraph mode=3
	ModifyGraph marker=19
	ModifyGraph rgb=(65535,65535,65535)
	ModifyGraph useMrkStrokeRGB=1
	ModifyGraph zmrkSize(peakExcitation)={peakHeight,0,*,1,10}
	ModifyGraph mirror=0
	Label left "excitation / nm"
	Label bottom "emission / nm"
	SetAxis left 525,*
EndMacro

Window SMApeakMaximum() : Graph
	PauseUpdate; Silent 1		// building window...
	Display /W=(39,178.25,425.25,425) peakExcitation vs peakEmission as "SMApeakMaximum"
	ModifyGraph mode=3
	ModifyGraph marker=19
	ModifyGraph zmrkSize(peakExcitation)={peakHeight,0,*,1,10}
	Label left "excitation / nm"
	Label bottom "emission / nm"
	SetAxis left 525,765
EndMacro

Window SMAexactscanImage() : Graph
	PauseUpdate; Silent 1		// building window...
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:PLEMd2:
	Display /W=(963,138.5,1316.25,413.75) coordinates[*][0]/TN=AcN vs coordinates[*][1] as "SMAexactscanImage"
	AppendImage ::borders
	ModifyImage borders explicit= 1
	ModifyImage borders eval={0,65535,65535,65535}
	ModifyImage borders eval={255,-1,-1,-1}
	ModifyImage borders eval={1,13107,13107,13107}
	AppendImage ::trenches
	ModifyImage trenches explicit= 1
	ModifyImage trenches eval={0,65535,65535,65535}
	ModifyImage trenches eval={255,-1,-1,-1}
	ModifyImage trenches eval={1,52428,52428,52428}
	SetDataFolder fldrSav0
	ModifyGraph margin(left)=7,margin(bottom)=7,margin(top)=7,margin(right)=85,expand=-1
	ModifyGraph width={Plan,1,bottom,left}
	ModifyGraph mode=3
	ModifyGraph marker=29
	ModifyGraph mrkThick=0.1
	ModifyGraph gaps=0
	ModifyGraph mrkStrokeRGB=(0,0,0,6554)
	ModifyGraph zmrkSize(AcN)={peakHeight,0,*,0,5}
	ModifyGraph zColor(AcN)={peakLocation,800,1300,dBZ14}
	ModifyGraph mirror=0
	ModifyGraph noLabel=2
	ModifyGraph axRGB(left)=(0,0,0,0),axRGB(bottom)=(65535,65535,65535,0)
	ModifyGraph manTick(left)={0,40,0,0},manMinor(left)={9,5}
	ModifyGraph manTick(bottom)={0,40,0,0},manMinor(bottom)={9,5}
	SetAxis left -5,300
	SetAxis bottom -5,300
	ColorScale/C/N=text0/F=0/A=LB/X=102.55/Y=4.55 trace=AcN
	AppendText "central emission wavelength [nm]"
	SetDrawLayer UserFront
	SetDrawEnv xcoord= bottom,ycoord= left,linethick= 5
	DrawLine 308.107553969184,287.5,358.107553969184,287.5
	SetDrawEnv xcoord= bottom,ycoord= left
	DrawText 317.7649537407,269.625,"50µm"
EndMacro