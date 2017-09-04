#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// structure idea taken from info (igor-file-loader)
// https://github.com/ukos-git/igor-file-loader
// released under MIT license by same author @ukos-git

// require igor-common-utilities
// https://github.com/ukos-git/igor-common-utilities
#include "utilities-globalvar"

static strConstant cstructure = "structure" // path for global vars in Package dfr
static strConstant cpeakfit   = "peakFit"   // path for temp peakfit waves
static Constant    cversion   = 0004

Structure SMAinfo
	Variable numVersion, numSpectra

	DFREF dfrStructure
	DFREF dfrPeakFit

	WAVE/WAVE wavSpectra, wavPeakFind
EndStructure

static Function SMAstructureInitGlobalVariables()
	DFREF dfrStructure = $SMAstructureDF()
	DFREF dfrPeakFit   = $SMApeakfitDF()

	Utilities#createNVAR("numVersion", dfr = dfrStructure, set = cversion)
	Utilities#createNVAR("numSpectra", dfr = dfrStructure, init = 0)
End

static Function SMAstructureInitWaves()
	DFREF dfrStructure = $SMAstructureDF()

	WAVE/Z/WAVE/SDFR=dfrStructure wavSpectra = spectra
	if(!WaveExists(wavSpectra))
		Make/WAVE dfrStructure:spectra/WAVE=wavSpectra
	endif
	WAVE/Z/WAVE/SDFR=dfrStructure wavPeakFind = peakfind
	if(!WaveExists(wavPeakFind))
		Make/WAVE dfrStructure:peakfind/WAVE=wavPeakFind
	endif
End

Function SMAstructureLoad(info)
	STRUCT SMAinfo &info
	Variable SetDefault = 0

	if(!SMAstructureIsInit())
		SMApackageInitDF(info)
		SMAstructureUpdate(info)
	endif

	DFREF info.dfrStructure = $SMAstructureDF()
	if(DataFolderRefStatus(info.dfrStructure) == 0)
		print "SMAstructureLoad: \tUnexpected Behaviour."
	endif
	DFREF info.dfrPeakFit   = $SMApeakfitDF()
	if(DataFolderRefStatus(info.dfrStructure) == 0)
		print "SMAstructureLoad: \tUnexpected Behaviour."
	endif

	NVAR/Z/SDFR=info.dfrStructure numVersion

	if(numVersion < cversion)
		print "SMAstructureLoad: \tVersion Change detected."
		printf "current Version: \t%04d\r", numVersion
		SMAstructureUpdate(info)
		printf "new Version: \t%04d\r", numVersion
	endif
	info.numVersion = numVersion

	info.numSpectra = Utilities#loadNVAR("numSpectra", dfr = info.dfrStructure)

	WAVE/WAVE/SDFR=info.dfrStructure info.wavSpectra = spectra
	WAVE/WAVE/SDFR=info.dfrStructure info.wavPeakFind = peakfind
End

Function SMAstructureSave(info)
	STRUCT SMAinfo &info

	DFREF dfrstructure = $SMAstructureDF()

	Utilities#saveNVAR("numVersion", info.numVersion, dfr = dfrStructure)
	Utilities#saveNVAR("numSpectra", info.numSpectra, dfr = dfrStructure)
End

static Function/S SMApackageDF()
	return "root:Packages:" + PossiblyQuoteName(cSMApackage)
End

static Function/S SMAstructureDF()
	return SMApackageDF() + ":" + cstructure
End

static Function/S SMApeakfitDF()
	return SMApackageDF() + ":" + cpeakfit
End

static Function SMAstructureIsInit()
	String strDataFolder = SMAstructureDF()

	if(!DataFolderExists(strDataFolder))
		return 0
	endif

	DFREF dfrStructure = $SMAstructureDF()
	NVAR/Z/SDFR=dfrStructure numVersion
	if(!NVAR_EXISTS(numVersion))
		return 0
	endif

	return 1
End

static Function SMApackageInitDF(info)
	STRUCT SMAinfo &info
	DFREF dfrSave = GetDataFolderDFR()

	SetDataFolder root:
	NewDataFolder/O/S Packages
	NewDataFolder/O $cSMApackage

	SetDataFolder dfrSave
End

static Function SMAstructureInitDF(info)
	STRUCT SMAinfo &info

	DFREF dfr = $SMApackageDF()
	DFREF new = dfr:$cstructure
	if(DataFolderRefStatus(new) == 0)
		NewDataFolder dfr:$cstructure
	endif
End

static Function SMApeakfitInitDF(info)
	STRUCT SMAinfo &info

	DFREF dfr = $SMApackageDF()
	DFREF new = dfr:$cpeakfit
	if(DataFolderRefStatus(new) == 0)
		NewDataFolder dfr:$cpeakfit
	endif
End

static Function SMAstructureUpdate(info)
	STRUCT SMAinfo &info

	SMAstructureInitDF(info)
	SMApeakfitInitDF(info)
	SMAstructureInitGlobalVariables()
	SMAstructureInitWaves()
End
