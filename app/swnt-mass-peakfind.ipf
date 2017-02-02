#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

// require igor-common-utilities
// https://github.com/ukos-git/igor-common-utilities
#include "utilities-peakfind"

Function SMApeakFindMass()
    variable i

    STRUCT SMAinfo info
    SMAstructureLoad(info)
    STRUCT SMAprefs prefs
    SMAloadPackagePrefs(prefs)

    if(info.numSpectra != DimSize(info.wavSpectra, 0))
        print "SMApeakFindMass: error in SMAinfo structure"
        return 0
    endif

    Redimension/N=(info.numSpectra) info.wavPeakFind
    for(i = 0; i < info.numSpectra; i += 1)
        info.wavPeakFind[i] = SMApeakFind(info.wavSpectra[i])
    endfor
End

Function/WAVE SMApeakFind(wv)
    WAVE wv

    variable numResults, i

    WAVE result = Utilities#PeakFind(wv)
    numResults = Dimsize(result, 0)
    for(i = 0; i < numResults; i += 1)
        printf "%d,\t" result[i][%wavelength]
    endfor
    printf "\r"

    return result
End
