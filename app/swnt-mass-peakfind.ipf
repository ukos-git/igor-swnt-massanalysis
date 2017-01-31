#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include <Peak AutoFind>

Function SMApeakFindMass(wv)
    WAVE/WAVE wv

    variable numWaves, i

    numWaves = DimSize(wv, 0)
    for(i = 0; i < numWaves; i += 1)
        SMApeakFind(wv[i])
    endfor
End

Function SMApeakFind(wv)
    WAVE wv
End

