#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3

#include <Peak AutoFind>

// prefs idea taken from WMs example and FILO (igor-file-loader)
// https://github.com/ukos-git/igor-file-loader
// released under MIT license by same author @ukos-git

static Constant cversion = 0002
static StrConstant cstrPackageName = "Spectra Mass Analysis"
static StrConstant cstrPreferencesFileName = "SMA.bin"
// The recordID is a unique number identifying a record within the preference file.
static Constant cPrefsRecordID = 0
static Constant reserved = 90

Structure SMAprefs
	double version
	char   strBasePath[40]

	// reserved forfuture use
	uchar  strReserved1[256]
	uchar  strReserved2[256]
	double dblReserved[100]
	uint32 intReserved[reserved]
EndStructure

static Function DefaultPackagePrefs(package)
	STRUCT SMAprefs &package

	Variable i

	package.version = 0
	package.strBasePath = ""

	// reserved forfuture use
	package.strReserved1 = ""
	package.strReserved2 = ""
	for(i = 0; i < reserved; i += 1)
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

// Save the location of the base path.
// All files will be saved/updated relative to this path.
// This function originates at swnt-plem.
//
// DisplayHelpTopic "Symbolic Paths"
Function SMASetBasePath()
	String strBasePath

	Struct SMAprefs prefs
	SMAloadPackagePrefs(prefs)

	strBasePath = prefs.strBasePath
	NewPath/O/Q/Z SMAbasePath, strBasePath
	if(!V_flag)
		PathInfo/S path
	endif

	NewPath/O/Q/Z/M="Set SMA base path" SMAbasePath
	if(V_flag)
		return 0 // user canceled
	endif

	PathInfo SMAbasePath
	strBasePath = S_path
	if(!V_flag)
		return 0 // invalid path
	endif

	strBasePath = RemoveEnding(strBasePath, ":")
	GetFileFolderInfo/Q/Z=1 strBasePath
	if(!V_flag && V_isFolder)
		prefs.strBasePath = strBasePath
		SMAsavePackagePrefs(prefs)
	endif
End

Function SMAloadBasePath()
	String path
	PathInfo SMAbasePath
	if(V_flag)
		return 0
	endif

	Struct SMAprefs prefs
	SMAloadPackagePrefs(prefs)

	path = prefs.strBasePath
	NewPath/O/Q/Z SMAbasePath, path
	if(V_flag)
		printf "error setting base path to %s\r", path
		return 1
	endif

	return 0
End
