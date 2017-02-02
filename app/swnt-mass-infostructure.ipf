#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// structure idea taken from info (igor-file-loader)
// https://github.com/ukos-git/igor-file-loader
// released under MIT license by same author @ukos-git

// require igor-common-utilities
// https://github.com/ukos-git/igor-common-utilities
#include "utilities-globalvar"

static strConstant cstructure = "structure" // path for global vars in Package dfr
static Constant    cversion   = 0002

Structure SMAinfo
    Variable numVersion, numSpectra

    DFREF dfrPackage
    DFREF dfrStructure

    WAVE/WAVE wavSpectra
EndStructure

static Function SMAstructureInitGlobalVariables()
    DFREF dfrStructure = $SMAstructureDF()

    Utilities#createNVAR("numVersion", dfr = dfrStructure, set = cversion)
    Utilities#createNVAR("numSpectra", dfr = dfrStructure, init = 0)
End

static Function SMAstructureInitWaves()
    DFREF dfrStructure = $SMAstructureDF()

    WAVE/Z/WAVE/SDFR=dfrStructure wavSpectra = spectra
    if(!WaveExists(wavSpectra))
        Make/WAVE dfrStructure:spectra/WAVE=wavSpectra
    endif
End

Function SMAstructureLoad(info)
    STRUCT SMAinfo &info
    Variable SetDefault = 0

    if(!SMAstructureIsInit())
        SMAstructureInitDF(info)
        SMAstructureUpdate(info)
    endif

    DFREF info.dfrStructure = $SMAstructureDF()
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
End

Function SMAstructureSave(info)
    STRUCT SMAinfo &info

    DFREF dfrstructure = $SMAstructureDF()

    Utilities#saveNVAR("numVersion", info.numVersion, dfr = dfrStructure)
    Utilities#saveNVAR("numSpectra", info.numSpectra, dfr = dfrStructure)
End

static Function/S SMAstructureDF()
    return "root:Packages:" + PossiblyQuoteName(cSMApackage) + ":" + cstructure
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

static Function SMAstructureInitDF(info)
    STRUCT SMAinfo &info
    DFREF dfrSave = GetDataFolderDFR()

    SetDataFolder root:
    NewDataFolder/O/S Packages
    NewDataFolder/O/S $cSMApackage
    NewDataFolder/O/S $cstructure

    SetDataFolder dfrSave
End

static Function SMAstructureUpdate(info)
    STRUCT SMAinfo &info

    SMAstructureInitGlobalVariables()
    SMAstructureInitWaves()
End
