//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------

import Foundation

let defaultRootArchiveDirectory = "/Users/toddvernon/Pictures"


//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------
func NSPrint(_ format: String, _ args: CVarArg...) {
    let string = String(format: format, arguments: args)
    print(string)
}

//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------
func photoTools()
{
    NSPrint("")
    NSPrint("PhotoToolsSwift — Photo and video backup and organization tools")
    NSPrint("")
    NSPrint("This binary provides five tools via symbolic links:")
    NSPrint("")
    NSPrint("  photocopy       Copy photos/videos into a date-organized archive")
    NSPrint("  photorenumber   Sort and renumber files chronologically")
    NSPrint("  photodedup      Remove duplicate files and renumber")
    NSPrint("  photocheck      Validate file dates match directory placement")
    NSPrint("  photocheckexif  Display creation date metadata")
    NSPrint("")
    NSPrint("Run any tool with --help for detailed usage.")
    NSPrint("")
    NSPrint("Setup: create symbolic links to this binary:")
    NSPrint("  ln -s PhotoToolsSwift photocopy")
    NSPrint("  ln -s PhotoToolsSwift photorenumber")
    NSPrint("  ln -s PhotoToolsSwift photodedup")
    NSPrint("  ln -s PhotoToolsSwift photocheck")
    NSPrint("  ln -s PhotoToolsSwift photocheckexif")
    NSPrint("")
}


//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------
@discardableResult func main() -> Int {
    
    NSPrint("CWD=\(FileManager.default.currentDirectoryPath)")
    
    var arguments = CommandLine.arguments
    let appName = (arguments.removeFirst() as NSString).lastPathComponent
    
    //return photoCopy(arguments: arguments);
    
    switch appName.lowercased() {
        
        case "photocopy":
            return photoCopy(arguments: arguments)
        case "photorenumber":
            return photoRenumber(arguments: arguments)
        case "photodedup":
            return photoDedup(arguments: arguments)
        case "photocheck":
            return photoCheck(arguments: arguments)
        case "photocheckexif":
            return photoCheckEXIF(arguments: arguments)
        default:
        photoTools()
            
    }
    
    return 0
}


//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------

func showHelp(_ arguments: [String]) -> Bool {
    return arguments.contains("-help") || arguments.contains("--help")
}

func photoCopy(arguments: [String]) -> Int {

    var sourceDirectory = ""
    var rootArchiveDirectory = ""
    var includeLive = false

    //-------------------------------------------------------------------------------------------------------------
    // parse flags
    //-------------------------------------------------------------------------------------------------------------
    var positionalArgs: [String] = []
    for arg in arguments {
        if arg == "--include-live" {
            includeLive = true
        } else if arg == "-help" || arg == "--help" {
            // handled below
        } else {
            positionalArgs.append(arg)
        }
    }

    guard positionalArgs.count == 2, !showHelp(arguments) else {
        NSPrint("")
        NSPrint("photocopy — Copy photos and videos into a date-organized archive")
        NSPrint("")
        NSPrint("Usage: photocopy [--include-live] <sourceDirectory> <archiveDirectory>")
        NSPrint("")
        NSPrint("Reads each JPG, JPEG, HEIC, and MOV file in the source directory,")
        NSPrint("extracts the creation date from EXIF (photos) or QuickTime (videos)")
        NSPrint("metadata, and copies the file into the archive under YYYY/MM-DD-YYYY/.")
        NSPrint("")
        NSPrint("After copying, each modified destination directory is automatically")
        NSPrint("deduplicated (byte-for-byte comparison) and renumbered chronologically.")
        NSPrint("This means you can re-import the same photos without worrying about")
        NSPrint("duplicates — they are removed automatically.")
        NSPrint("")
        NSPrint("Files without creation date metadata are placed in an UNKNOWN_DATES")
        NSPrint("directory inside the source directory for manual review.")
        NSPrint("")
        NSPrint("Live Photo MOV clips (short companion videos) are skipped by default.")
        NSPrint("")
        NSPrint("Options:")
        NSPrint("  --include-live   Include Live Photo MOV clips (skipped by default)")
        NSPrint("  -help, --help    Show this help message")
        NSPrint("")
        return 0
    }

    sourceDirectory = positionalArgs[0]
    rootArchiveDirectory = positionalArgs[1]

    NSPrint("photocopy:\(sourceDirectory) --> \(rootArchiveDirectory)/")
    
    var modifiedDestDirectorySet = Set<String>()
    
    //-----------------------------------------------------------------------------------------------------------------
    // got all the image file names in the source directory
    //-----------------------------------------------------------------------------------------------------------------
    let pd = PhotoDirectory(directoryName: sourceDirectory)
    
    //-----------------------------------------------------------------------------------------------------------------
    // for each image file copy to the correct day directory
    //-----------------------------------------------------------------------------------------------------------------
    for photoFile in pd.photoNameArray {

        var isDir: ObjCBool = false

        //-------------------------------------------------------------------------------------------------------------
        // skip Live Photo MOV clips unless --include-live is specified
        //-------------------------------------------------------------------------------------------------------------
        if !includeLive {
            if !photoFile.isLivePhoto {
                photoFile.checkDurationForLivePhoto()
            }
            if photoFile.isLivePhoto {
                NSPrint(" skipping Live Photo: %@", photoFile.fullPathToFile)
                continue
            }
        }

        //-------------------------------------------------------------------------------------------------------------
        // if the photo has EXIF data for creation date and time taken, then construct the correct path name
        //-------------------------------------------------------------------------------------------------------------
        if (photoFile.hasPhotoDateTime()) {
            
            //---------------------------------------------------------------------------------------------------------
            // the destination path is the root of the archive passed in by the user, followed by the year, and
            // the followed by the day-month-year
            //---------------------------------------------------------------------------------------------------------
            var destDirectory = rootArchiveDirectory
            destDirectory = (destDirectory as NSString).appendingPathComponent(photoFile.conformingYearDirectoryName())
            destDirectory = (destDirectory as NSString).appendingPathComponent(photoFile.conformingDayDirectoryName())
            
            //---------------------------------------------------------------------------------------------------------
            // keep track of the directory we are creating or adding to so we can go back renumber the files later
            //---------------------------------------------------------------------------------------------------------
            modifiedDestDirectorySet.insert(destDirectory)
            
            //---------------------------------------------------------------------------------------------------------
            // create the directory if required
            //---------------------------------------------------------------------------------------------------------
            if FileManager.default.fileExists(atPath: destDirectory, isDirectory: &isDir) && isDir.boolValue {
                //NSPrint(" directory: exists --> \(destDirectory)")
            } else {
                NSPrint(" directory: created --> \(destDirectory)")
                try? FileManager.default.createDirectory(atPath: destDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            //---------------------------------------------------------------------------------------------------------
            // replace the actual name with a GUID so as not to run into the same existing name, the GUID name
            // will be replaced later with a photo number
            //---------------------------------------------------------------------------------------------------------
            var destFileName = destDirectory
            destFileName = (destFileName as NSString).appendingPathComponent(Util.createGUID())
            destFileName = (destFileName as NSString).appendingPathExtension(photoFile.fileExtension)!
            
            //---------------------------------------------------------------------------------------------------------
            // copy the file
            //---------------------------------------------------------------------------------------------------------
            NSPrint(" copy: \(photoFile.fullPathToFile) --> \(destFileName)")
            try? FileManager.default.copyItem(atPath: photoFile.fullPathToFile, toPath: destFileName)
            
        //-------------------------------------------------------------------------------------------------------------
        // this file did not have EXIF data, so we throw it into a directory called unknown
        //-------------------------------------------------------------------------------------------------------------
        } else {
            
            let unknownFileDirectory = (sourceDirectory as NSString).appendingPathComponent("UNKNOWN_DATES")
        
            if FileManager.default.fileExists(atPath: unknownFileDirectory, isDirectory: &isDir) && isDir.boolValue {
                //NSPrint(" directory: exists --> \(unknownFileDirectory)")
            } else {
                NSPrint(" directory: created --> \(unknownFileDirectory)")
                try? FileManager.default.createDirectory(atPath: unknownFileDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            
            var destFileName = unknownFileDirectory
            destFileName = (destFileName as NSString).appendingPathComponent(Util.createGUID())
            destFileName = (destFileName as NSString).appendingPathExtension(photoFile.fileExtension)!
            
            NSPrint(" copy: \(photoFile.fullPathToFile) --> \(destFileName)")
            try? FileManager.default.copyItem(atPath: photoFile.fullPathToFile, toPath: destFileName)
    
        }
    }
    
    //-----------------------------------------------------------------------------------------------------------------
    // we've moved all the files around so now we just go back through each directory we touched, dedup the
    // the files that are identical and rename them with photo numbers
    //-----------------------------------------------------------------------------------------------------------------
    for destDir in modifiedDestDirectorySet {
        
        NSPrint(" directory: renumber --> \(destDir)")
        
        let modDir = PhotoDirectory(directoryName: destDir)
        modDir.dedup()
        modDir.renumberPhotoFiles()
    }
    
    return 0
}


//---------------------------------------------------------------------------------------------------------------------
// photoCheckEXIF: Used to look for photos and print their EXIF data or lack there of
//
//---------------------------------------------------------------------------------------------------------------------
func photoCheckEXIF(arguments: [String]) -> Int 
{
    var directory = ""
    
    guard arguments.count == 1, !showHelp(arguments) else {
        NSPrint("")
        NSPrint("photocheckexif — Display creation date metadata for photos and videos")
        NSPrint("")
        NSPrint("Usage: photocheckexif <directory>")
        NSPrint("")
        NSPrint("Lists every supported file (JPG, JPEG, HEIC, MOV) in the given directory")
        NSPrint("and displays its embedded creation date (EXIF for photos, QuickTime for")
        NSPrint("videos). Files without creation date metadata are flagged.")
        NSPrint("")
        NSPrint("Accepts any directory type:")
        NSPrint("  Day directory   (MM-DD-YYYY)  — lists files in that day")
        NSPrint("  Year directory  (YYYY)        — descends into each day subdirectory")
        NSPrint("  Other directory               — lists files directly")
        NSPrint("")
        NSPrint("Options:")
        NSPrint("  -help, --help   Show this help message")
        NSPrint("")
        return 0
    }
    
    directory = arguments[0]
    
    var year:  Int = 0
    var month: Int = 0
    var day:   Int = 0
    
    //-----------------------------------------------------------------------------------------------------------------
    // Parse the directory name to see if its a year directory, day directory, or an other directory type
    //-----------------------------------------------------------------------------------------------------------------
    let dc = PhotoDirectory.parseDirectoryName(directory, forYear: &year, forMonth: &month, forDay: &day)
    
    switch( dc ) {
        
        //-------------------------------------------------------------------------------------------------------------
        // This is a YEAR directory
        //-------------------------------------------------------------------------------------------------------------
        case .year:
    
            //---------------------------------------------------------------------------------------------------------
            // get all the contents of the year directory
            //---------------------------------------------------------------------------------------------------------
            if let contentOfDirectory = try? FileManager.default.contentsOfDirectory(atPath: directory) {
                
                //-----------------------------------------------------------------------------------------------------
                // for each directory in the Year directory (should be a month directory) parse out the
                // date of each from the filename.
                //-----------------------------------------------------------------------------------------------------
                for subDirectory in contentOfDirectory {
                    
                    var numberWithMissingPhotoDate = 0
                    var subYear:  Int = 0
                    var subMonth: Int = 0
                    var subDay:   Int = 0

                    //-------------------------------------------------------------------------------------------------
                    // parse the directory name to see if conforms to a photo day directory
                    //-------------------------------------------------------------------------------------------------
                    let subDirectoryPath = (directory as NSString).appendingPathComponent(subDirectory)
                    let subDirectoryType = PhotoDirectory.parseDirectoryName(subDirectoryPath, forYear: &subYear, forMonth: &subMonth, forDay: &subDay)
                    
                    //-------------------------------------------------------------------------------------------------
                    // if its a day type directory, then load all the photo files names in that directory
                    //-------------------------------------------------------------------------------------------------
                    if subDirectoryType == .day {
                        
                        NSPrint(" [ photoCheck: \(subDirectoryPath) ]")
                        
                        let pd = PhotoDirectory(directoryName: subDirectoryPath)
                    
                        for photoFile in pd.photoNameArray {
                            
                            if photoFile.hasPhotoDateTime() {
                                NSPrint(" EXIF(\(String(describing: photoFile.photoDate))): \(photoFile.fullPathToFile)")
                            } else {
                                numberWithMissingPhotoDate += 1
                                NSPrint(" EXIF(          ): \(photoFile.fullPathToFile)")
                            }
                        }
                    
                        NSPrint("  \(pd.photoNameArray.count) photos, \(numberWithMissingPhotoDate) missing photo creation date\n")
                    }
                }
            }

        //-------------------------------------------------------------------------------------------------------------
        // get all the contents of the day directory
        //-------------------------------------------------------------------------------------------------------------
        case .day:
            
            NSPrint(" [ photoCheck: \(directory) ]")
            var numberWithMissingPhotoDate = 0
            let pd = PhotoDirectory(directoryName: directory)
        
            //---------------------------------------------------------------------------------------------------------
            // for each photo in the day directory, print out the EXIF data we retreived
            //---------------------------------------------------------------------------------------------------------
            for photoFile in pd.photoNameArray {
                if photoFile.hasPhotoDateTime() {
                    NSPrint(" EXIF(\(String(describing: photoFile.photoDate))): \(photoFile.fullPathToFile)")
                } else {
                    numberWithMissingPhotoDate += 1
                    NSPrint(" EXIF(          ): \(photoFile.fullPathToFile)")
                }
            }
        
            NSPrint("  \(pd.photoNameArray.count) photos, \(numberWithMissingPhotoDate) missing photo creation date\n")
            break
    
        //-------------------------------------------------------------------------------------------------------------
        // its another kind of directory entirely, might be a directory a new photos dumped from a phone
        //-------------------------------------------------------------------------------------------------------------
        case .other:
        
            NSPrint(" [ photoCheck: \(directory) ]")
            var numberWithMissingPhotoDate = 0
            let pd = PhotoDirectory(directoryName: directory)
            
            //---------------------------------------------------------------------------------------------------------
            // for each photo in the directory, print out the EXIF data
            //---------------------------------------------------------------------------------------------------------
            for photoFile in pd.photoNameArray {
                if photoFile.hasPhotoDateTime() {
                    NSPrint(" EXIF(\(String(describing: photoFile.photoDate))): \(photoFile.fullPathToFile)")
                } else {
                    numberWithMissingPhotoDate += 1
                    NSPrint(" EXIF(          ): \(photoFile.fullPathToFile)")
                }
            }
        
            NSPrint("  \(pd.photoNameArray.count) photos, \(numberWithMissingPhotoDate) missing photo creation date\n")
    }
    
    return 0
}


//---------------------------------------------------------------------------------------------------------------------
// photoDedup: 
//
//   this application walks through a day directory type and removes photos that are identical but
//   by alternate names.  Once its done removing identical photos the files are renumbered
//
//---------------------------------------------------------------------------------------------------------------------
func photoDedup(arguments: [String]) -> Int 
{
    var directory = ""
    
    guard arguments.count == 1, !showHelp(arguments) else {
        NSPrint("")
        NSPrint("photodedup — Remove duplicate files and renumber")
        NSPrint("")
        NSPrint("Usage: photodedup <dayDirectory>")
        NSPrint("")
        NSPrint("Compares every file in a day directory (MM-DD-YYYY) against every")
        NSPrint("other file using byte-for-byte comparison. When two files are")
        NSPrint("identical, the duplicate is removed. After deduplication, the")
        NSPrint("remaining files are renumbered chronologically by creation date.")
        NSPrint("")
        NSPrint("Only operates on day directories (e.g. 01-19-2018).")
        NSPrint("")
        NSPrint("Options:")
        NSPrint("  -help, --help   Show this help message")
        NSPrint("")
        return 0
    }
    
    directory = arguments[0]
    
    NSPrint("photoDedup:\(directory)")
    
    var year:  Int = 0
    var month: Int = 0
    var day:   Int = 0
    
    //-----------------------------------------------------------------------------------------------------------------
    // parse the directory name to make sure its a day directory
    //-----------------------------------------------------------------------------------------------------------------
    let dc = PhotoDirectory.parseDirectoryName(directory, forYear: &year, forMonth: &month, forDay: &day)
    
    //-----------------------------------------------------------------------------------------------------------------
    // if it is a day directory, then dedup the files and renumber them if required
    //-----------------------------------------------------------------------------------------------------------------
    if (dc == .day) {
        let pd = PhotoDirectory(directoryName: directory)
        pd.dedup()
        pd.renumberPhotoFiles()
    } else {
        NSPrint("photoDedup: '%@' is not a day directory (expected MM-DD-YYYY), skipping", directory)
    }

    return 0
}


//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------
func photoRenumber(arguments: [String]) -> Int 
{
    var directory = ""
    
    guard arguments.count == 1, !showHelp(arguments) else {
        NSPrint("")
        NSPrint("photorenumber — Sort and renumber files chronologically")
        NSPrint("")
        NSPrint("Usage: photorenumber <dayDirectory>")
        NSPrint("")
        NSPrint("Sorts all files in a day directory (MM-DD-YYYY) by their creation")
        NSPrint("date and renumbers them sequentially (YYYY-MM-DD-0000, 0001, ...).")
        NSPrint("This ensures files are in chronological order after adding or")
        NSPrint("removing files.")
        NSPrint("")
        NSPrint("Only operates on day directories (e.g. 01-19-2018).")
        NSPrint("")
        NSPrint("Options:")
        NSPrint("  -help, --help   Show this help message")
        NSPrint("")
        return 0
    }
    
    directory = arguments[0]
    
    var year:  Int = 0
    var month: Int = 0
    var day:   Int = 0
    
    //-----------------------------------------------------------------------------------------------------------------
    // parse the directory name to make sure its a day directory
    //-----------------------------------------------------------------------------------------------------------------

    let dc = PhotoDirectory.parseDirectoryName(directory, forYear: &year, forMonth: &month, forDay: &day)
    
    //-----------------------------------------------------------------------------------------------------------------
    // if it is a day directory, then dedup the files and renumber them if required
    //-----------------------------------------------------------------------------------------------------------------

    if ( dc == .day) {
        NSPrint("photoRenumber: \(directory)")
        let pd = PhotoDirectory(directoryName: directory)
        pd.renumberPhotoFiles()
    } else {
        NSPrint("photoRenumber: '%@' is not a day directory (expected MM-DD-YYYY), skipping", directory)
    }

    return 0
}

//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------

func photoCheck(arguments: [String]) -> Int 
{
    var directory = ""
    
    guard arguments.count == 1, !showHelp(arguments) else {
        NSPrint("")
        NSPrint("photocheck — Validate that file dates match their directory placement")
        NSPrint("")
        NSPrint("Usage: photocheck <dayDirectory | yearDirectory>")
        NSPrint("")
        NSPrint("Compares each file's embedded creation date against the date implied")
        NSPrint("by the directory it lives in. Reports any mismatches where a file's")
        NSPrint("metadata says it belongs in a different day directory. Also flags")
        NSPrint("files that have no creation date metadata.")
        NSPrint("")
        NSPrint("This is a read-only check — no files are moved or modified.")
        NSPrint("")
        NSPrint("Accepts:")
        NSPrint("  Day directory   (MM-DD-YYYY)  — checks files in that day")
        NSPrint("  Year directory  (YYYY)        — descends into each day subdirectory")
        NSPrint("")
        NSPrint("Options:")
        NSPrint("  -help, --help   Show this help message")
        NSPrint("")
        return 0
    }
    
    directory = arguments[0]
    
    var year:  Int = 0
    var month: Int = 0
    var day:   Int = 0
    
    //-----------------------------------------------------------------------------------------------------------------
    // parse the directory name to make sure its a day directory
    //-----------------------------------------------------------------------------------------------------------------

    let dc = PhotoDirectory.parseDirectoryName(directory, forYear: &year, forMonth: &month, forDay: &day)
    
    switch ( dc )
    {
        //-------------------------------------------------------------------------------------------------------------
        // if this is a year directory
        //-------------------------------------------------------------------------------------------------------------
        case .year:
        
            //---------------------------------------------------------------------------------------------------------
            // get the contents of the directory
            //---------------------------------------------------------------------------------------------------------
            if let contentOfDirectory = try? FileManager.default.contentsOfDirectory(atPath: directory) {
                
                //-----------------------------------------------------------------------------------------------------
                // for every subdirectory in the year directory check to see if its a day directory and if it
                // is save its name
                //-----------------------------------------------------------------------------------------------------
                for subDirectory in contentOfDirectory {
                    
                    let subDirectoryPath = (directory as NSString).appendingPathComponent(subDirectory)
                    var subYear: Int = 0
                    var subMonth: Int = 0
                    var subDay: Int = 0
                    
                    //-------------------------------------------------------------------------------------------------
                    // parse the name to make sure it matches the day format
                    //-------------------------------------------------------------------------------------------------
                    let subDirectoryType = PhotoDirectory.parseDirectoryName(subDirectoryPath, forYear: &subYear, forMonth: &subMonth, forDay: &subDay)
                    
                    //-------------------------------------------------------------------------------------------------
                    // if its a day directory, then check all the files to see if their EXIF data matches the
                    // directory and advise if it does not.  This is not an error condition as sometime we want
                    // files in the directory becuase the EXIF data is mission or inaccurate
                    //-------------------------------------------------------------------------------------------------
                    if (subDirectoryType == .day) {
                        
                        NSPrint(" [ photoCheck: \(subDirectoryPath) ]")
                        let pd = PhotoDirectory(directoryName: subDirectoryPath)
                        pd.checkFilesForDate()
                        NSPrint("")
                    }
                }
            }
            break
        
        //-------------------------------------------------------------------------------------------------------------
        // this is a day directory type
        //-------------------------------------------------------------------------------------------------------------
        case .day:
            
            NSPrint(" [ photoCheck: \(directory) ]")
            
            //---------------------------------------------------------------------------------------------------------
            // if its a day directory, then check all the files to see if their EXIF data matches the
            // directory and advise if it does not.  This is not an error condition as sometime we want
            // files in the directory becuase the EXIF data is mission or inaccurate
            //---------------------------------------------------------------------------------------------------------
            let pd = PhotoDirectory(directoryName: directory)
            pd.checkFilesForDate()
            NSPrint("")
            break
        
        //-------------------------------------------------------------------------------------------------------------
        // this is an other type directory.  We don't have any date from the directory name to check against the
        // photo EXIF data se we just return
        //-------------------------------------------------------------------------------------------------------------
        case .other:
            NSPrint("photoCheck: '%@' is not a day or year directory, skipping", directory)
            return(0)

    }

    return(0);

}


//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------

func CreateGUID() -> String 
{
    return UUID().uuidString
}


//---------------------------------------------------------------------------------------------------------------------
//
//
//---------------------------------------------------------------------------------------------------------------------

main()
