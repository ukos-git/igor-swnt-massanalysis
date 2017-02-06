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

Function/WAVE SMApeakFind(wv, [verbose])
    WAVE wv
    variable verbose

    variable numResults, i

    if(ParamIsDefault(verbose))
        verbose = 0
    endif

    WAVE result = Utilities#PeakFind(wv, maxPeaks = 4, minPeakPercent = 90, noiselevel = 10, smoothingFactor = 1)

    if(verbose)
        numResults = Dimsize(result, 0)
        for(i = 0; i < numResults; i += 1)
            printf "%d,\t" result[i][%wavelength]
        endfor
        printf "\r"
    endif

    return result
End

Function SMApeakAnalysis()
    variable i, j, numPeaks, offset

    STRUCT SMAinfo info
    SMAstructureLoad(info)

    for(i = 0; i < info.numSpectra; i += 1)
        numPeaks += DimSize(info.wavPeakFind[i], 0)
    endfor

    Make/O/N=(numPeaks) root:peakfind_wl/WAVE=wl
    Make/O/N=(numPeaks) root:peakfind_int/WAVE=int
    Make/O/N=(numPeaks) root:peakfind_fwhm/WAVE=fwhm

    for(i = 0; i < info.numSpectra; i += 1)
        wave peakfind = info.wavPeakFind[i]
        numPeaks = DimSize(peakfind, 0)
        for(j = 0; j < numPeaks; j += 1)
            //PLEMd2DisplayByNum(i)
            wl[offset + j]  = peakfind[j][0]
            int[offset + j] = peakfind[j][1]
            fwhm[offset + j] = peakfind[j][2]
        endfor
        offset += numPeaks
    endfor

End
