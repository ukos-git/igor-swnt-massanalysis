#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include <Peak AutoFind>

// prefs idea taken from WMs example and FILO (igor-file-loader)
// https://github.com/ukos-git/igor-file-loader
// released under MIT license by same author @ukos-git

static Constant cversion = 0001
static StrConstant cstrPackageName = "Spectra Mass Analysis"
static StrConstant cstrPreferencesFileName = "SMA.bin"
// The recordID is a unique number identifying a record within the preference file.
static Constant cPrefsRecordID = 0

Structure SMAprefs
	double version

	// reserved forfuture use
	uchar  strReserved1[256]
	uchar  strReserved2[256]
	double dblReserved[100]
	uint32 intReserved[100]
EndStructure

static Function DefaultPackagePrefs(package)
	STRUCT SMAprefs &package

	Variable i

	package.version = 0

	// reserved forfuture use
	package.strReserved1 = ""
	package.strReserved2 = ""
	for(i = 0; i < 100; i += 1)
		package.dblReserved[i] = 0
		package.intReserved[i] = 0
	endfor
End

static Function ResetPackagePrefs(package)
	STRUCT SMAprefs &package

	package.strReserved1 = ""
	package.strReserved2 = ""
End

static Function SyncPackagePrefs(package)
	STRUCT SMAprefs &package

	package.version = cversion
End

Function SMAloadPackagePrefs(package, [id])
	STRUCT SMAprefs &package
	Variable id

	if(ParamIsDefault(id))
		id = cPrefsRecordID
	endif

	LoadPackagePreferences cstrPackageName, cstrPreferencesFileName, id, package
	if(V_flag != 0 || V_bytesRead == 0)
		print "SMAloadPackagePrefs: \tPackage not initialized"
		DefaultPackagePrefs(package)
	endif

	if(package.version < cversion)
		print "SMALoadPackagePrefs: \tVersion change detected:"
		printf "\tcurrent Version: \t%04d\r", package.version
		ResetPackagePrefs(package)
		SMAsavePackagePrefs(package)
		printf "\tnew Version: \t%04d\r", cversion
	endif
End

Function SMAsavePackagePrefs(package, [id])
	STRUCT SMAprefs &package
	Variable id

	if(ParamIsDefault(id))
		id = cPrefsRecordID
	endif

	SyncPackagePrefs(package)
	SavePackagePreferences cstrPackageName, cstrPreferencesFileName, id, package
End
