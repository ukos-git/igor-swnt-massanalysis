#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// require igor-common-utilities
// https://github.com/ukos-git/igor-common-utilities
Function SMApeakFindMass(wv)
    WAVE/WAVE wv

    variable i

    STRUCT SMAinfo info
    SMAstructureLoad(info)
    STRUCT SMAprefs prefs
    SMAloadPackagePrefs(prefs)

    info.numSpectra = DimSize(wv, 0)
    for(i = 0; i < info.numSpectra; i += 1)
        SMApeakFind(wv[i])
    endfor
End

Function SMApeakFind(wv)
    WAVE wv
End
