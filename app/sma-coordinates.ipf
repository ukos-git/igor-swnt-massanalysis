#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

Function SMA_FindMatchingSpectra(coordinates)
	WAVE coordinates

	variable dim0, numMatches, numMatchesOld, i, j
	variable tolerance = 1 // tolerance in um around coordinate

	Make/O/N=(0) root:matches/WAVE=matches

	WAVE spectra = PLEMd2getCoordinates()
	dim0 = DimSize(coordinates, 0)
	for(i = 0; i < dim0; i += 1)
		WAVE indices = CoordinateFinderXYrange(spectra, coordinates[i][0] - tolerance, coordinates[i][0] + tolerance, coordinates[i][1] - tolerance, coordinates[i][1] + tolerance, verbose = 1)
		numMatches = DimSize(indices, 0)
		numMatchesOld = DimSize(matches, 0)
		Redimension/N=(numMatchesOld + numMatches) matches
		for(j = 0; j < numMatches; j += 1)
			matches[numMatchesOld + j] = indices[j]
			PLEMd2Displaybynum(indices[j])
		endfor
	endfor
End

Function SMA_ExportCoordinates()
	Variable i, numMaps
	String name, file
	String baseName, maps

	SMAupdatePath()

	STRUCT FILO#experiment filos
	FILO#structureLoad(filos)

	baseName = IgorInfo(1)
	WAVE allCoordinates = PLEMd2getCoordinates(forceRenew = 1)
	maps = PLEMd2getStrMapsAvailable()

	WAVE/Z indices = root:peakIndex // one spectrum per exactscan
	if(!WaveExists(indices))
		numMaps = ItemsInList(maps)
		Make/FREE/N=(numMaps) indices = p
	endif

	// quick validation if files were only loaded with SMAread()
	if(ItemsInList(maps) != ItemsInList(filos.strFileList))
		Abort "SMA_ExportCoordinates: Missmatch"
	endif

	numMaps = DimSize(indices, 0)
	Make/O/N=(numMaps, 3) root:$(basename + "_coordinates")/WAVE=coordinates
	Make/T/O/N=(numMaps) root:$(basename + "_originals")/WAVE=files
	for(i = 0; i < numMaps; i += 1)
		name = StringFromList(indices[i], maps)
		file = StringFromList(indices[i], filos.strFileList)
		if(!!cmpstr(name, CleanupName(ParseFilePath(3, file, ":", 0, 0), 0)))
			Abort "smaload not valid for " + num2str(i)
		endif
		files[i] = file
		coordinates[i][] = allCoordinates[indices[i]][q]
	endfor

	file = files[0]
	if(!!cmpstr(file[0], ":"))
		print files
		print filos.strFolder
		Abort "Lecacy Format detected"
	endif

	// save to home
	Save/C/O/P=home files
	Save/C/O/P=home coordinates
End

// merge two PLEM ranges and save them as a new ibw file
// only works for single background
Function SMA_MergeMaps(indices0, indices1)
	WAVE indices0, indices1

	String wavenote0, wavenote1, strPath, strPLEM
	Variable i, numMaps
	Variable start, ende
	STRUCT PLEMd2Stats stats
	Variable skip = 2 // skip the last 2 entries in the first wave

	if(DimSize(indices0, 0) != DimSize(indices1, 0))
		Abort "Size Missmatch"
	endif

	PathInfo home
	strPath = S_Path + IgorInfo(1)
	NewPath/C/O/Z newmaps, strPath

	numMaps = DimSize(indices0, 0)
	for(i = 0; i < numMaps; i += 1)
		strPLEM = PLEMd2strPLEM(indices0[i])
		PLEMd2statsLoad(stats, strPLEM)
		DFREF dfr = $(GetWavesDataFolder(stats.wavPLEM, 1) + "ORIGINAL")
		WAVE original0 = WaveRefIndexedDFR(dfr, 0)

		PLEMd2statsLoad(stats, PLEMd2strPLEM(indices1[i]))
		DFREF dfr = $(GetWavesDataFolder(stats.wavPLEM, 1) + "ORIGINAL")
		WAVE original1 = WaveRefIndexedDFR(dfr, 0)

		Duplicate/O original0 root:$strPLEM/WAVE=dest
		Redimension/N=(-1, DimSize(original0, 1) + DimSize(original1, 1) - 2 - skip) dest // single bg
		dest[][DimSize(original0, 1) - skip, *] = original1[p][q - DimSize(original0, 1) + skip + 2]

		wavenote0 = note(original0)
		start = strsearch(wavenote0, "Max Central Wavelength (nm): ", start)
		ende  = strsearch(wavenote0, "\r", start)
		wavenote0 = wavenote0[0, start - 1] + "Max Central Wavelength (nm): " + num2str(stats.numEmissionEnd) + wavenote0[ende, inf]

		wavenote1 = note(original1)
		start = strsearch(wavenote1, "Power at Glass Plate (µW):", 0) + 28
		ende  = strsearch(wavenote1, "\r", start) - 1
		wavenote1 = wavenote1[start, ende]
		start = strsearch(wavenote0, "Power at Glass Plate", 0) + 28
		ende  = strsearch(wavenote0, "\r", start) - 9 * skip
		wavenote0 = wavenote0[0, ende] + wavenote1 + wavenote0[ende + 9 * skip, inf]

		wavenote1 = note(original1)
		start = strsearch(wavenote1, "IGOR3:WL;BG;PL", 0) + 12 + skip * 12 + skip // skip "IGOR3:WL;BG;" and n x "PL_6875_7125"
		wavenote0 += wavenote1[start, inf]
		Note/K dest wavenote0

		Save/C/O/P=newmaps dest
		KillWaves dest
	endfor
End

// see ACW_EraseMarqueeArea.
Function SMA_EraseMarqueeArea()
	variable dim0, numMatches, i

	GetMarquee left, bottom //V_bottom, V_top, V_left and V_right
	if (V_flag == 0)
		return 0
	endif

	WAVE coordinates = SMA_PromptTrace()
	WAVE indices2 = CoordinateFinderXYrange(coordinates, V_bottom, V_top, V_left, V_right, verbose = 1)
	numMatches = DimSize(indices2, 0)
	if(!numMatches)
		return 0
	endif

	// delete Points
	WAVE/Z deleted = root:coordinates_deleted
	if(!WaveExists(deleted))
		Make/N=(numMatches, 3) root:coordinates_deleted/WAVE=deleted
	else
		dim0 = DimSize(deleted, 0)
		dim0 = 0 // reset deleted wave
		Redimension/N=(dim0 + numMatches, -1) deleted
	endif
	Sort/R indices2, indices2
	if(!cmpstr(NameOfWave(coordinates), "coordinates"))
		WAVE/Z l1 = root:legende
		WAVE/Z l2 = root:legend_text
	endif
	for(i = 0; i < numMatches; i += 1)
		deleted[dim0 + i][] = coordinates[indices2[i]][q]
		DeletePoints/M=0 indices2[i], 1, coordinates
		if(!cmpstr(NameOfWave(coordinates), "coordinates"))
			if(WaveExists(l1) && WaveExists(l2))
				DeletePoints/M=0 indices2[i], 1, l1, l2
			endif
		endif
	endfor

	// Append coordinates_deleted wave to top graph if not present
	CheckDisplayed deleted
	if(V_flag == 0)
		AppendToGraph deleted[][0]/TN=deleted vs deleted[][1]
		ModifyGraph mode(deleted)=4,marker(deleted)=8,opaque(deleted)=1,rgb(deleted)=(0,65535,0)
	endif
End

// @brief Delete entities in @p coordinates that are duplicate values in @p reference
//
// give a @p companion wave that is connected with its rows to coordinates and delete from there as well.
// @returns number of points deleted
Function SMAdeleteDuplicateCoordinates(coordinates, reference, [companion])
	WAVE coordinates, reference, companion

	Variable i, j, numMatches, dim0

	if(ParamIsDefault(companion))
		if(DimSize(companion, 0) != DimSize(coordinates, 0))
			Abort "SMAdeleteDuplicateCoordinates: companion and coordinates need to have the same number of rows."
		endif
	endif

	Make/FREE/N=0 indices
	dim0 = DimSize(reference, 0)
	for(i = 0; i < dim0; i += 1)
		WAVE duplicates = CoordinateFinderXYrange(coordinates, reference[i][0] - 1.5, reference[i][0] + 1.5, reference[i][1] - 1, reference[i][1] + 1, verbose = 0)

		numMatches = DimSize(duplicates, 0)
		if(!cmpstr(GetWavesDataFolder(coordinates, 2), GetWavesDataFolder(reference, 2))) // check if acting on the same wave
			Extract/FREE duplicates, duplicates, (duplicates[p] > i)
		endif
		if(!WaveExists(duplicates))
			continue
		endif

		Concatenate/FREE {indices, duplicates}, dummy
		Duplicate/FREE dummy indices
		WaveClear dummy
	endfor

	if(Dimsize(indices, 0) == 0)
		return 0
	endif

	if(DimSize(indices, 0) > 1)
		Sort indices, indices
		FindDuplicates/FREE/RN=dummy/TOL=0 indices
		if(!WaveExists(dummy))
			return 0
		endif
		Duplicate/FREE dummy indices
	endif

	Extract/FREE indices, matches, numtype(indices[p]) == 0
	numMatches = DimSize(matches, 0)
	for(i = numMatches - 1; i > -1; i -= 1)
		if(numtype(matches[i]) != 0)
			numMatches -= 1
			continue
		endif
		if(ParamIsDefault(companion))
			DeletePoints matches[i], 1, coordinates
		else
			DeletePoints matches[i], 1, coordinates, companion
		endif
	endfor

	// always be verbose due to the delete
	printf "deleted %d matches in %s.\r", numMatches, GetWavesDataFolder(coordinates, 2)
	return numMatches
End

Function/Wave SMA_PromptTrace()
	String itemName
	Variable selectedItem

	string itemsList = ""
	Variable numItems = 0

	String topWindowImages =	ImageNameList("", ";")
	String topWindowTraces =	TraceNameList("", ";", 1)
	
	Variable numTraces = ItemsInList(topWindowTraces)
	Variable numImages = ItemsInList(topWindowImages)
	
	// remove trailing ";"
	if(!cmpstr(topWindowImages[(strlen(topWindowImages) - 1), strlen(topWindowImages)], ";"))
		topWindowImages = topWindowImages[0, strlen(topWindowImages) - 1]
	endif
	itemsList = AddListItem(topWindowImages, topWindowTraces, ";", numTraces)
	numItems = numTraces + numImages

	if(numItems == 0)
		print "No traces found in top graph"
		return $""
	endif

	if(numItems == 1)
		if(numTraces)
			return TraceNameToWaveRef("", StringFromList(0, itemsList))
		else
			return ImageNameToWaveRef("", StringFromList(0, itemsList))
		endif
	endif

	Prompt selectedItem, "Choose Trace", popup, itemsList
	DoPrompt "Enter wave", selectedItem
	if(V_flag)
		print "SMA_PromptTrace: catched Cancel"
		return $""
	endif
	selectedItem -= 1 // zero based index
	itemName = StringFromList(selectedItem, itemsList)

	if(selectedItem < numTraces)
		return TraceNameToWaveRef("", itemName)
	else
		return ImageNameToWaveRef("", itemName)
	endif
End

Function GetCoordinates()
	Variable temp, i, j
	Variable numCoords, numPeaks
	Variable numSize = 1024
	String topWindowImages =	ImageNameList("", ";")
	String topWindowTraces =	TraceNameList("", ";", 1)

	if(ItemsInList(topWindowImages) == 0)
		print "no Image found in top graph"
		return 0
	endif

	WAVE/Z image = ImageNameToWaveRef("", StringFromList(0, topWindowImages))
	if(!WaveExists(image))
		print "image wave does not exist."
		return 0
	endif

	STRUCT PLEMd2Stats stats
	PLEMd2statsLoad(stats, PLEMd2strPLEM(0))

	// start fresh
	Make/O/N=(numSize, 3) root:coordinates/Wave=wavCoordinates = NaN
	Make/O/N=(numSize, 3) root:legende/Wave=wavLegend = NaN
	Make/O/T/N=(numSize) root:legend_text/Wave=wavLegendText = ""

	// display coordinates
	if(FindListItem("coordinates", topWindowTraces) == -1)
		AppendToGraph wavCoordinates[][0]/TN=coordinates vs wavCoordinates[][1]
		ModifyGraph mode(coordinates)=3,marker(coordinates)=1,msize(coordinates)=2
	endif
	if(FindListItem("legend", topWindowTraces) == -1)
		AppendToGraph wavLegend[][0]/TN=legend vs wavLegend[][1]
		ModifyGraph mode(legend)=3
		ModifyGraph textMarker(legend)={wavLegendText,"default",0,0,5,0.00,0.00}
		ModifyGraph msize(legend)=3
	endif

	Duplicate/FREE image, currentImage

	// prepare: remove offset
	ImageFilter/O/N=5 gauss currentImage
	temp = WaveMin(currentImage)
	currentImage -= temp

	for(i = 0; i <= 300; i += 4)
		Duplicate/FREE/R=(0, 300)(i) currentImage lineProfile
		WAVE peaks = SMApeakFind(lineProfile, maxPeaks = 30, minPeakPercent = 0.1, smoothingfactor = NaN)
		WaveClear lineProfile
		numPeaks = DimSize(peaks, 0)
		for(j = 0; j < numPeaks; j += 1)
			if(peaks[j][%fwhm] > 5)
				continue
			endif
			if(numSize < numCoords)
				Redimension/N=(numCoords + 10, -1) wavCoordinates, wavLegend, wavLegendText
				numSize = numCoords + 10
			endif

			wavCoordinates[numCoords][0] = i
			wavCoordinates[numCoords][1] = peaks[j][%location]
			wavCoordinates[numCoords][2] = stats.numPositionZ

			wavLegend[numCoords][0] = wavCoordinates[numCoords][0]
			wavLegend[numCoords][1] = wavCoordinates[numCoords][1]
			wavLegendText[numCoords] = "i=" + num2str(peaks[j][%height]) + "\r f=" + num2str(peaks[j][%fwhm])
			numCoords += 1
		endfor
		DoUpdate
		WaveClear peaks
	endfor

	Redimension/N=(numCoords, -1) wavCoordinates, wavLegendText, wavLegend
	SortColumns/KNDX={0,1} sortwaves=wavCoordinates
End

Function AddCoordinatesFromGraph()
	Variable numItems
	Variable aExists = 0

	aExists= strlen(CsrInfo(A)) > 0
	if(!aExists)
		print "Cursor A not in Graph"
		return 0
	endif
	WAVE/Z coordinates = root:coordinates
	if(!WaveExists(coordinates))
		SMAresetCoordinates()
		WAVE coordinates = root:coordinates
	endif
	WAVE/T/Z legende = root:legend_text

	numItems = DimSize(coordinates, 0)
	Redimension/N=(numItems + 1, 3) coordinates
	coordinates[numItems][0]=vcsr(A)
	coordinates[numItems][1]=hcsr(A)
	WAVE/Z normal = root:SMAcameraPlaneNormal
	WAVE/Z distance = root:SMAcameraPlaneDistance
	if(!WaveExists(normal) || !WaveExists(distance))
		coordinates[numItems][2]=150
		print "AddCoordinatesFromGraph: missing tilt plane parameters"
	else
		coordinates[numItems][2]= SMAcameraGetTiltPlane(coordinates[numItems][0],coordinates[numItems][1])
	endif

	if(WaveExists(legende))
		Redimension/N=(numItems + 1, -1) legende
		legende[numItems]="manual"
	endif

	// Append coordinates_deleted wave to top graph if not present
	CheckDisplayed coordinates
	if(V_flag == 0)
		AppendToGraph coordinates[][0]/TN=coordinates vs coordinates[][1]
		ModifyGraph mode(coordinates)=4,marker(coordinates)=8
	endif
End

Function DeleteCoordinates(rangeMin, rangeMax)
	Variable rangeMin, rangeMax
	Variable numItems, i, deleteMe
	Variable numDelete = 0

	WAVE/Z coordinates = root:coordinates
	WAVE/T/Z legende = root:legend_text

	if(!WaveExists(coordinates))
		print "required waves do not exist. Start SMAgetCoordinates first"
		return 0
	endif

	Duplicate/FREE coordinates original
	numItems = DimSize(original, 0)
	for(i = 0; i < numItems; i += 1)
		deleteMe = 0
		if((coordinates[i - numDelete][0] < rangeMin) || (coordinates[i - numDelete][0] > rangeMax))
			deleteMe = 1
		endif
		if((coordinates[i - numDelete][1] < rangeMin) || (coordinates[i - numDelete][1] > rangeMax))
			deleteMe = 1
		endif
		if(deleteMe)
			DeletePoints/M=0 i - numDelete, 1, coordinates
			if(WaveExists(legende))
				DeletePoints/M=0 i - numDelete, 1, legende
			endif
			numDelete += 1
		endif
	endfor
End

Function SortCoordinates()
	WAVE/Z coordinates = root:coordinates
	WAVE/T/Z legende = root:legend_text

	if(!WaveExists(coordinates))
		print "required waves do not exist. Start SMAgetCoordinates first"
		return 0
	endif

	if(WaveExists(legende))
		SortColumns/KNDX={0,1} keyWaves=coordinates, sortWaves={coordinates, legende}
	else
		SortColumns/KNDX={0,1} sortWaves=coordinates
	endif
End

Function RoundCoordinates([accuracy])
	Variable accuracy

	WAVE/Z coordinates = root:coordinates

	accuracy = ParamIsDefault(accuracy) ? 4 : accuracy

	if(!WaveExists(coordinates))
		print "required waves do not exist. Start SMAgetCoordinates first"
		return 0
	endif

	coordinates[][0] = round(coordinates[p][0] / accuracy) * accuracy
End

Function SMAcalcZcoordinateFromTiltPlane([wv, zOffset])
	WAVE wv
	variable zOffset

	zOffset = ParamIsDefault(zOffset) ? SMAcameraGetTiltPlane(0,0) : zOffset

	if(ParamIsDefault(wv))
		WAVE wv = root:coordinates
	endif
	if(!WaveExists(wv))
		print "SMAcalcZcoordinateFromTiltPlane: input wave does not exist"
		return 0
	endif

	WAVE/Z normal = root:SMAcameraPlaneNormal
	WAVE/Z distance = root:SMAcameraPlaneDistance
	if(!WaveExists(normal) || !WaveExists(distance))
		print "SMAcalcZcoordinateFromTiltPlane: nothing done"
		return 0
	endif

	wv[][2] = SMAcameraGetTiltPlane(wv[p][0], wv[p][1], zOffset = zOffset)
End

// @brief search trenches for carbon nanotubes (considered experimental)
Function SMAgetCoordinates()
	Variable i
	STRUCT PLEMd2Stats stats

	variable numMaps = PLEMd2getMapsAvailable()

	SMAresetCoordinates()
	SMAbuildGraphPLEM()
	//WAVE fullimage = SMAmergeImages(0, createNew = 0)
	//Duplicate/FREE fullimage, currentImage
	//SMAparticleAnalysis(currentImage)

	WAVE background = SMAestimateBackground()
	for(i = 0; i < numMaps; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		Duplicate/FREE stats.wavPLEM, currentImage
		ImageFilter/O /N=5 median currentImage // remove spikes
		currentImage -= background
		SMAsearchTrenches(currentImage, trenchpitch = 4)
	endfor

	return 1
End

Function SMAsearchTrenches(currentImage, [trenchpitch])
	WAVE currentImage
	Variable trenchpitch 	// distance from one trench to the next

	Variable i, numPeaks, numCoords
	Variable dim0, dim0offset, dim0delta, dim1
	Variable Pmin, Pmax, Ymin, Ymax, Qdelta
	Variable rangePdelta, rangeYdelta
	Variable currentY, QcenterTrench

	Variable rangeXmin = 5, rangeXmax = 300
	Variable rangeYmin = 0, rangeYmax = 300
	Variable Ydelta = 4/3 * 1 // size of trench area in y-direction

	trenchpitch = ParamIsDefault(trenchpitch) ? 4 : trenchpitch

	dim0 = DimSize(currentImage, 0)
	dim0delta = DimDelta(currentImage, 0)
	dim0offset = DimOffset(currentImage, 0)
	Pmin = limit(ScaleToIndex(currentImage, rangeXmin, 0), 0, dim0 - 1)
	Pmax = limit(ScaleToIndex(currentImage, rangeXmax, 0), 0, dim0 - 1)
	Qdelta = floor(abs(ScaleToIndex(currentImage, Ydelta, 1) - ScaleToIndex(currentImage, 0, 1)))

	dim1 = DimSize(currentImage, 1)
	Ymin = IndexToScale(currentImage, 0, 1)
	Ymax = IndexToScale(currentImage, dim1 - 1, 1)
	SMAorderAsc(Ymin, Ymax)
	Ymin = limit(ceil((Ymin + Ydelta) / trenchpitch) * trenchpitch, rangeYmin, rangeYmax)
	Ymax = limit(floor((Ymax - Ydelta) / trenchpitch) * trenchpitch, rangeYmin, rangeYmax)

	rangePdelta = abs(Pmax - Pmin) + 1
	rangeYdelta = abs(Ymax - Ymin) / trenchpitch + 1

	// differentiate 2 times along trench area
	ImageFilter/O/N=5 gauss currentImage
	Differentiate/DIM=0 currentImage
	Differentiate/DIM=0 currentImage
	ImageFilter/O/N=11 gauss currentImage

	// extract all trenches. Trench width is Qdelta
	Make/O/N=(rangePdelta, rangeYdelta) root:trenches/WAVE=wavTrenches = NaN
	for(i = 0; i < rangeYdelta; i += 1)
		currentY = Ymin + trenchpitch * i
		QcenterTrench = ScaleToIndex(currentImage, currentY, 1)
		Duplicate/FREE/R=[Pmin, Pmax][floor(QcenterTrench - Qdelta), ceil(QcenterTrench + Qdelta)] currentImage, currentTrench
		MatrixOP/FREE currentTrenchAvg = sumRows(currentTrench)
		wavTrenches[][i] = currentTrenchAvg[p]
	endfor

	// substract a median trench to see the peaks better
	Make/O/N=(rangePdelta) root:averageTrench/WAVE=averageTrench
	for(i = 0; i < rangePdelta; i += 1)
		MatrixOP/FREE currentPixel = row(wavTrenches, i)
		averageTrench[i] = median(currentPixel)
	endfor
	Smooth 50, averageTrench
	wavTrenches[][] -= averageTrench[p]

	// find the peaks and store them
	Make/FREE/N=(rangePdelta) positionX = dim0offset + (Pmin + p) * dim0delta
	Make/FREE/N=(0, 2)   currentCoordinates
	Make/FREE/N=(0, 0)/T description
	for(i = 0; i < rangeYdelta; i += 1)
		currentY = Ymin + trenchpitch * i
		Duplicate/FREE/R=[][i] wavTrenches, currentTrenchAvg
		WAVE peaks = PeakFind(currentTrenchAvg, wvXdata = positionX, maxPeaks = 10, minPeakPercent = 90)
		numPeaks = DimSize(peaks, 0)
		if(numPeaks == 0)
			continue
		endif

		Redimension/N=(numPeaks, -1) currentCoordinates, description
		currentCoordinates[][0] = currentY
		currentCoordinates[][1] = peaks[p][%location]
		description[] = num2str(round(peaks[p][%height]))

		SMAaddCoordinates(currentCoordinates, text = description)
		numCoords += numPeaks
	endfor

	return numCoords
End

Function SMAparticleAnalysis(currentImage)
	WAVE currentImage

	variable numPeaks

	// differentiate 2 times to get the peaks without background
	ImageFilter/O/N=5 gauss currentImage
	Differentiate/DIM=0 currentImage
	Differentiate/DIM=0 currentImage
	ImageFilter/O/N=11 gauss currentImage

	// remove 2nd derivative sattelites
	currentImage *= -1 // inverted image
	currentImage[][] = currentImage[p][q] < 0 ? 0 : currentImage[p][q]

	// calculate Threshold
	//StatsQuantiles/Q/ALL currentImage
	//Wave W_StatsQuantiles
	//myThreshold = W_StatsQuantiles[%upperOuterFence]
	//print "Threshold set to ", myThreshold
	//MatrixFilter/O NanZapMedian currentImage
	//ImageThreshold/I/O/Q/M=0/T=(myThreshold) currentImage
	ImageThreshold/I/O/Q/M=5 currentImage

	// particle size: elipse with defined circularity, min and max area
	ImageAnalyzeParticles/A=20/MAXA=500/CIRC={0.75 , 1.75}/W/M=2 stats currentImage

	WAVE W_SpotX, W_spotY
	WAVE W_BoundaryX, W_BoundaryY
	WAVE W_ImageObjArea, M_rawMoments, W_circularity

	numPeaks = DimSize(W_SpotX, 0)

	if((numPeaks == 0) || (numPeaks > 3000))
		print "Error: non reasonable peak count", numPeaks
		return 0
	endif

	Make/FREE/N=(numPeaks, 2) currentCoordinates
	currentCoordinates[][0] = IndexToScale(currentImage, M_rawMoments[p][1] / W_ImageObjArea[p], 1)
	currentCoordinates[][1] = IndexToScale(currentImage, M_rawMoments[p][0] / W_ImageObjArea[p], 0)

	return SMAaddCoordinates(currentCoordinates)
End

Function SMAresetCoordinates()
	Make/O/N=(0, 3) root:coordinates/Wave=wavCoordinates = NaN
End

Function SMAaddCoordinates(currentCoordinates, [text])
	WAVE currentCoordinates
	WAVE/T text

	Variable j, k, numPeaks, numCoords, numSize
	Variable coordinateX, coordinateY, duplicateValue

	numPeaks = DimSize(currentCoordinates, 0)
	if(numPeaks == 0)
		return 0
	endif
	WAVE/Z wavCoordinates = root:coordinates
	if(!WaveExists(wavCoordinates))
		Make/O/N=(0, 3) root:coordinates/Wave=wavCoordinates = NaN
	endif
	numCoords = DimSize(wavCoordinates, 0)
	numSize = numCoords + numPeaks

	WAVE/T/Z wavLegendText = root:legend_text
	if(!WaveExists(wavLegendText))
		Make/O/T/N=(numSize) root:legend_text/Wave=wavLegendText = ""
	endif
	Make/FREE/D/N=(numSize) coordinatesX = 0, coordinatesY = 0

	Redimension/N=(numSize, -1) wavCoordinates, wavLegendText, coordinatesX, coordinatesY
	for(j = 0; j < numPeaks; j += 1)
		if(numSize < numCoords)
			numSize = numCoords + 10
		endif

		// get coordinates (rounded to 0.1)
		coordinateX = round(currentCoordinates[j][0]/0.1)*0.1
		coordinateY = round(currentCoordinates[j][1]/0.1)*0.1

		// compare to currently saved coordinates
		k = -1
		duplicateValue = 0
		do
			FindValue/S=(k+1)/T=1/V=(coordinateX) coordinatesX
			k = V_Value
			if(k == -1)
				break
			endif
			// min. range for a new coordinate is 2 µm
			if(round(coordinatesY[k]/2)*2 == round(coordinateY/2)*2)
				duplicateValue = 1
				break
			endif
		while(k < numCoords)

		if(duplicateValue)
			wavCoordinates[k][0] = (wavCoordinates[V_Value][0] + coordinateX) / 2
			wavCoordinates[k][1] = (wavCoordinates[V_Value][1] + coordinateY) / 2
			continue
		endif

		coordinatesX[numCoords] = coordinateX
		coordinatesY[numCoords] = coordinateY

		wavCoordinates[numCoords][0] = coordinateX
		wavCoordinates[numCoords][1] = coordinateY
		wavCoordinates[numCoords][2] = 150 // fixed

		if(!ParamIsDefault(text))
			wavLegendText[numCoords] = text[j]
		else
			wavLegendText[numCoords] = "(" + num2str(coordinateX) + ", " + num2str(coordinateY) + ")"
		endif

		numCoords += 1
	endfor

	Redimension/N=(numCoords, -1) wavCoordinates, wavLegendText
	SortColumns/KNDX={0,1} sortwaves=wavCoordinates

	return numCoords
End

Function/S SMAsearchCoordinate(coordinateX, coordinateY)
	Variable coordinateX, coordinateY

	Variable k
	String listFound = ""
	WAVE coordinates = PLEMd2getCoordinates()

	// round coordinates
	coordinateX = round(coordinateX/0.1)*0.1
	coordinateY = round(coordinateY/0.1)*0.1

	// separate Waves
	Duplicate/FREE/R=[][0] coordinates coordinatesX
	Duplicate/FREE/R=[][1] coordinates coordinatesY
	Redimension/N=(-1, 0) coordinatesX, coordinatesY

	k = -1
	do
		if(k==57)
			print "hier"
		endif
		FindValue/S=(k+1)/T=1/V=(coordinateX) coordinatesX
		k = V_Value
		if(k == -1)
			break
		endif

		if(round(coordinatesY[k]/2)*2 == round(coordinateY/2)*2)
			listFound = AddListItem(num2str(k), listFound)
			continue
		endif
	while(k < DimSize(coordinates, 0))

	return listFound
End

// Zzero is the new zero position to which the z values will be corrected
// i.e. the new focus point at (x,y) = (0,0)
Function/WAVE SMAcameraCoordinates([Zzero, export])
	Variable Zzero
	Variable export

	export = ParamIsDefault(export) ? 1 : !!export

	Variable xstep = 48, ystep = 80, zstep = -1

	Zzero = ParamIsDefault(Zzero) ? SMAcameraGetTiltPlane(0, 0) : Zzero

	printf "SMAcameraCoordinates(Zzero = %.2f, export = %d)\r", Zzero, export

	// 4 scans in x = 300/64
	// 6 scans in y = 300/48
	// 8 scans in z direction (4um from laserfocus to bottom of trench in 0.5um steps)
	// --> 16 hours when integrating 300s.

	Make/O/N=(4 * 6 * 8, 3) root:SMAfullscan/WAVE=wv

	wv[][0] = 4 * 6 + mod(floor(p / 4), 6) * xstep
	wv[][1] = 30 + mod(p, 4) * ystep
	wv[][2] = SMAcameraGetTiltPlane(wv[p][0], wv[p][1], zOffset = zZero) + floor(p / (4 * 6)) * zstep

	Duplicate/O/R=[0 * 4 * 6, 1 * 4 * 6 - 1] wv root:SMAsinglescan00/WAVE=singlescan00
	singlescan00[][2] = SMAcameraGetTiltPlane(wv[p][0], wv[p][1], zOffset = zZero)

	Duplicate/O/R=[0 * 4 * 6, 1 * 4 * 6 - 1] wv root:SMAsinglescan10/WAVE=singlescan10
	singlescan10[][2] = SMAcameraGetTiltPlane(wv[p][0], wv[p][1], zOffset = zZero) - 1

	Duplicate/O/R=[0 * 4 * 6, 1 * 4 * 6 - 1] wv root:SMAsinglescan15/WAVE=singlescan15
	singlescan15[][2] = SMAcameraGetTiltPlane(wv[p][0], wv[p][1], zOffset = zZero) - 1.5

	Duplicate/O/R=[0 * 4 * 6, 1 * 4 * 6 - 1] wv root:SMAsinglescan20/WAVE=singlescan20
	singlescan20[][2] = SMAcameraGetTiltPlane(wv[p][0], wv[p][1], zOffset = zZero) - 2

	Duplicate/O/R=[0 * 4 * 6, 1 * 4 * 6 - 1] wv root:SMAsinglescan25/WAVE=singlescan25
	singlescan25[][2] = SMAcameraGetTiltPlane(wv[p][0], wv[p][1], zOffset = zZero) - 2.5

	Duplicate/O/R=[0 * 4 * 6, 1 * 4 * 6 - 1] wv root:SMAsinglescan40/WAVE=singlescan40
	singlescan40[][2] = SMAcameraGetTiltPlane(wv[p][0], wv[p][1], zOffset = zZero) - 4

	if(export)
		Save/J/O/DLIM=","/P=home singlescan00 as "singlescan00.csv"
		Save/J/O/DLIM=","/P=home singlescan10 as "singlescan10.csv"
		Save/J/O/DLIM=","/P=home singlescan15 as "singlescan15.csv"
		Save/J/O/DLIM=","/P=home singlescan20 as "singlescan20.csv"
		Save/J/O/DLIM=","/P=home singlescan25 as "singlescan25.csv"
		Save/J/O/DLIM=","/P=home singlescan40 as "singlescan40.csv"
		Save/J/O/DLIM=","/P=home wv as "fullscan.csv"
	endif
	
	return wv
End

Function SMAcameraGetIntensity()
	variable i
	STRUCT PLEMd2Stats stats
	variable numMaps = PLEMd2getMapsAvailable()
	variable V_FitError = 0

	if(numMaps == 0)
		SMAload()
		numMaps = PLEMd2getMapsAvailable()
	endif

	Make/O/N=(numMaps) root:SMAcameraIntensity/WAVE=intensity
	Make/O/N=(numMaps, 3) root:SMAcameraIntensityCoordinates/WAVE=coordinates

	for(i = 0; i < numMaps; i += 1)
		PLEMd2statsLoad(stats, PLEMd2strPLEM(i))
		V_FitError = 0
		if(DimSize(stats.wavPLEM, 1) > 1)
			CurveFit/Q/M=0/W=2 Gauss2D stats.wavPLEM
		else
			CurveFit/Q/M=0/W=2 Gauss stats.wavPLEM
		endif
		if(V_FitError == 0)
			WAVE W_Coef
			intensity[i] = W_Coef[1]
		else
			intensity[i] = WaveMax(stats.wavPLEM)
		endif

		coordinates[i][0] = stats.numPositionX
		coordinates[i][1] = stats.numPositionY
		coordinates[i][2] = stats.numPositionZ
	endfor
End

Function/WAVE SMAcameraGetTiltPlaneParameters([createNew])
	variable createNew

	variable numPeaks

	createNew = ParamIsDefault(createNew) ? 0 : !!createNew

	WAVE/Z focuspoints = root:SMAcameraFocusPoints
	if(createNew || !WaveExists(focuspoints))
		WAVE focuspoints = SMAgetFocuspoints(graph = 1, createNew = createNew)
	endif

	numPeaks = DimSize(focuspoints, 0)
	if(!WaveExists(focuspoints) || (numPeaks != 3))
		print "SMAcameraGetTiltPlaneParameters(): Please correct manually and call again."
		edit focuspoints
		print "call: to add from graph"
		print "root:SMAcameraFocusPoints[2] = root:SMAcameraIntensityCoordinates[pcsr(a)][q]"
		print "call after manual editing root:SMAcameraFocusPoints:"
		print "SMAcameraGetTiltPlaneParameters(createNew=0)"
		Abort "Error in peakfind"
	endif

	return SMAHessePlaneParameters(focuspoints)
End

/// @brief search for laserspot maxima in loaded images
Function/WAVE SMAgetFocuspoints([graph, createNew])
	variable graph, createNew

	variable numPeaks, i, step, pStart, pEnd, pPeak
	variable numSpectra = PLEMd2getMapsAvailable()
	variable numFocuspoints = 3
	variable pOffset = 5

	graph = ParamIsDefault(graph) ? 0 : !!graph
	createNew = ParamIsDefault(createNew) ? 0 : !!createNew

	WAVE/Z intensity = root:SMAcameraIntensity
	WAVE/Z coordinates = root:SMAcameraIntensityCoordinates
	if(!WaveExists(intensity) || !WaveExists(coordinates) || createNew)
		SMAcameraGetIntensity()
		WAVE intensity = root:SMAcameraIntensity
		WAVE coordinates = root:SMAcameraIntensityCoordinates
	endif

	Duplicate/O intensity root:SMAcameraIntensitySmth/WAVE=intensity_smooth
	Smooth 5, intensity_smooth

	Make/O/N=(numFocuspoints, 3) root:SMAcameraFocusPoints/WAVE=focuspoints = 0
	Make/O/N=(numFocuspoints) root:SMAcameraPlanePeakMaximum/WAVE=focuspointsPval = 0
	for(i = 0; i < numFocuspoints; i += 1)
		pStart = i * round(numSpectra / 3)
		pEnd = (i + 1) * round(numSpectra / 3) - 1

		// quick fix: experimentally the first points are often garbage
		pStart += pOffset

		Duplicate/FREE/R=[pStart,pEnd] intensity_smooth singlePeakY
		Duplicate/FREE/R=[pStart,pEnd][2] coordinates singlePeakX
		Redimension/N=(-1, 0) singlePeakX

		WAVE guess = PeakFind(singlePeakY, wvXdata = singlePeakX, maxPeaks = 1)
		WAVE/WAVE coef = BuildCoefWv(singlePeakY, wvXdata = singlePeakX, peaks = guess)

		WAVE/WAVE/Z peakParam = fitGauss(singlePeakY, wvXdata = singlePeakX, wvCoef = coef)
		if(!WaveExists(peakParam))
			// revert to guess
			WAVE/WAVE coef = BuildCoefWv(singlePeakY, wvXdata = singlePeakX, peaks = guess)
			WAVE/WAVE peakParam = GaussCoefToPeakParam(coef)
		endif

		WAVE peakfind = peakParamToResult(peakParam)
		if(!WaveExists(peakfind))
			print "SMAgetFocuspoints(): Please correct manually and call again."
			Abort "Error in peakfind"
		endif

		numPeaks = DimSize(peakfind, 0)
		if(numPeaks == 1)
			pPeak = pStart - pOffset
			FindLevel singlePeakX, peakfind[0][%location]
			if(!V_flag)
				pPeak = V_LevelX
			endif
			focuspointsPval[i] = pPeak
			focuspoints[i][] = coordinates[pPeak][q]
			focuspoints[i][2] = peakfind[0][%location]
			printf "peak%d: \t x-Axis: \t%06.2f \ty-Axis: \t%06.2f \tz-Axis: \t%06.2f\r", i, focuspoints[i][0], focuspoints[i][1], focuspoints[i][2]
		endif
	endfor
	
	//output the results as graph
	if(graph)
		Make/O/T/N=(numFocuspoints) root:SMAcameraPlanePeakMaximumT = "(" + num2str(focuspoints[p][0]) + "," + num2str(focuspoints[p][1]) + ")"
		step = floor(DimSize(coordinates, 0) / 10 / 2) * 2
		Make/O/N=10 root:SMAcameraPlanePeakMaximumZ/WAVE=zWave = step / 2 + p * step
		Make/O/T/N=10 root:SMAcameraPlanePeakMaximumZT = num2str(round(coordinates[zWave[p]][2] * 10) / 10)
		Execute/Z "SMAcameraFocusPointsGraph()"
		SavePICT/O/P=home/E=-5/B=72
	endif

	return focuspoints
End

Function/WAVE SMAHessePlaneParameters(focuspoints)
	WAVE focuspoints

	printf "SMAHessePlaneParameters(%s)\r", GetWavesDataFolder(focuspoints, 2)

	Make/O/N=3 root:SMAcameraPlaneNormal/WAVE=normal
	Make/O/N=1 root:SMAcameraPlaneDistance/WAVE=distance

	MatrixOP/FREE row0 = row(focuspoints, 0)^t
	MatrixOP/FREE row1 = row(focuspoints, 1)^t
	MatrixOP/FREE row2 = row(focuspoints, 2)^t
	MatrixOP/FREE temp1 = row1 - row0
	MatrixOP/FREE temp2 = row2 - row0
	Cross/T/DEST=normal temp1, temp2

	MatrixOP/O distance = normal . averageCols(focuspoints)

	print "calculated plane in Hesse Normal form. Saving to home folder."
	Save/C/O/P=home distance, normal

	return focuspoints
End

Function SMAcameraGetTiltPlane(coordinateX, coordinateY, [zOffset])
	variable coordinateX, coordinateY, zOffset

	variable coordinateZ
	
	if(ParamIsDefault(zOffset))
		zOffset = 0
	else
		zOffset -= SMAcameraGetTiltPlane(0, 0)
	endif

	WAVE/Z normal = root:SMAcameraPlaneNormal
	WAVE/Z distance = root:SMAcameraPlaneDistance
	if(!WaveExists(normal) || !WaveExists(distance))
		SMAcameraGetTiltPlaneParameters()
		WAVE normal = root:SMAcameraPlaneNormal
		WAVE distance = root:SMAcameraPlaneDistance
	endif

	return zOffset + (distance[0] - normal[0] * coordinateX - normal[1] * coordinateY) / normal[2]
End

/// @brief Return a Wave of Waves with all matching PLEM indices for the supplied coordinates wave
Function/WAVE SMAfindCoordinatesInPLEM(coordinates, [verbose, accuracy])
	WAVE coordinates
	Variable verbose, accuracy

	Variable i, dim0

	verbose = ParamIsDefault(verbose) ? 0 : !!verbose

	WAVE PLEMcoordinates = PLEMd2getCoordinates()

	dim0 = DimSize(coordinates, 0)
	Make/FREE/U/I/WAVE/N=(dim0) indices
	if(ParamIsDefault(accuracy))
		indices[] = CoordinateFinderXYZ(PLEMcoordinates, coordinates[p][0], coordinates[p][1], coordinates[p][2], verbose = verbose)
	else
		indices[] = CoordinateFinderXYZ(PLEMcoordinates, coordinates[p][0], coordinates[p][1], coordinates[p][2], verbose = verbose, accuracy = accuracy)
	endif

	return indices
End

// @brief reduce the found indices from @c SMAfindCoordinatesInPLEM  to the first match
// @return unsigned integer wavv
Function/WAVE SMAreduceIndices(wv)
	WAVE/WAVE wv

	Variable i, numMaps = DimSize(wv, 0)
	Make/N=(numMaps)/U/I/FREE indices
	for(i = 0; i < numMaps; i += 1)
		WAVE matches = wv[i]
		indices[i] = matches[0]
	endfor

	return indices
End
