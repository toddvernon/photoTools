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
    NSPrint("photoTools is a common binary for photo management")
    NSPrint("create symbolinks to this binary as follows")
    NSPrint(" ln -s PhotoToolsSwift photoRenumber")
    NSPrint(" ln -s PhotoToolsSwift photoCopy")
    NSPrint(" ln -s PhotoToolsSwift photoDedup")
    NSPrint(" ln -s PhotoToolsSwift photoCheck")
    NSPrint(" ln -s PhotoToolsSwift photoCheckEXIF")
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
        } else {
            positionalArgs.append(arg)
        }
    }

    guard positionalArgs.count == 2 else {
        NSPrint("")
        NSPrint("[ photoCopy ]")
        NSPrint("")
        NSPrint("Usage: photocopy [--include-live] <sourcePhotoDirectory> <rootArchiveDirectory:ie /Volumes/Photos>")
        NSPrint("------------------------------------------------------------------")
        NSPrint("This application takes a source directory argument and copies each JPG")
        NSPrint("file to the archive directory argument placing the file in the correct YEAR")
        NSPrint("and DAY creating the directory if required.")
        NSPrint("")
        NSPrint("The application keeps track of modified YEAR/DAY directories")
        NSPrint("and then dedups the files in the directory and then renumbers the files.")
        NSPrint("")
        NSPrint("If a source JPG file contains no EXIF data with the photo creation")
        NSPrint("date, then the file is placed in a directory named UNKNOWN_DATE ")
        NSPrint("in the source directory.")
        NSPrint("")
        NSPrint("  --include-live   Include Live Photo MOV clips (skipped by default)")
        NSPrint("------------------------------------------------------------------")
        NSPrint(" ")
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
    
    guard arguments.count == 1 else {
        NSPrint("")
        NSPrint("[ photoCheckEXIF ]")
        NSPrint("")
        NSPrint("Usage: photoCheckEXIF <directory>")
        NSPrint("Usage: photoCheckEXIF <yearDirectory:ie 2014>")
        NSPrint("Usage: photoCheckEXIF <dayDirectory: ie 01-02-2014>")
        NSPrint("------------------------------------------------------------------")
        NSPrint("This application takes a directory argument and lists")
        NSPrint("all the photo files ending in .JPG.  If the photo file")
        NSPrint("contains EXIF data that contains the date and time the")
        NSPrint("photo was taken, it is listed as well.  If the file does")
        NSPrint("not contain the data then a blank is shown for the photo")
        NSPrint("creation date")
        NSPrint("")
        NSPrint("If the directory passed is a DAY directory (01-01-2018) or")
        NSPrint("application looks at each JPG file printing the file photo")
        NSPrint("photo time")
        NSPrint("")
        NSPrint("If the directory referenced is a YEAR directory then")
        NSPrint("then the application descends into each month directory listing")
        NSPrint("each file's attributes.")
        NSPrint("")
        NSPrint("If the directory passed is a directory of any other type")
        NSPrint("the application looks at each JPG file printing the photo")
        NSPrint("time")
        NSPrint("  ------------------------------------------------------------------")
        NSPrint(" ")
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
    
    guard arguments.count == 1 else {
        NSPrint("")
        NSPrint("[ photoDedup ]")
        NSPrint("")
        NSPrint("Usage: photoDedup <dayDirectory: ie 01-02-2014>")
        NSPrint("------------------------------------------------------------------")
        NSPrint("This application takes a DAY directory argument and compares each")
        NSPrint("JPG file against the others looking for duplicate files.  If it")
        NSPrint("encounters a duplicate it removes the duplicate.")
        NSPrint("")
        NSPrint("After deduping the files then firest renumbered.")
        NSPrint("------------------------------------------------------------------")
        NSPrint(" ")
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
    
    guard arguments.count == 1 else {
        NSPrint("")
        NSPrint("[ photoRenumber ]")
        NSPrint("")
        NSPrint("Usage: photoRenumber <dayDirectory: ie 01-02-2014>")
        NSPrint("Usage: photoRenumber <yearDirectory:ie 2014>")
        NSPrint("------------------------------------------------------------------")
        NSPrint("This application takes a DAY or YEAR directory argument")
        NSPrint("and renumbers all the JPG files in the DAY directory")
        NSPrint("")
        NSPrint("If the directory is a YEAR directory argument, the application")
        NSPrint("will descend into each DAY directory renumbering each")
        NSPrint("------------------------------------------------------------------")
        NSPrint(" ")
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
    
    guard arguments.count == 1 else {
        NSPrint("")
        NSPrint("[ photoCheck ]")
        NSPrint("")
        NSPrint("Usage: photoCheck <yearDirectory:ie 2014>")
        NSPrint("Usage: photoCheck <dayDirectory: ie 01-02-2014>")
        NSPrint("------------------------------------------------------------------")
        NSPrint("This application takes a DAY or YEAR directory argument and lists")
        NSPrint("all the photo files ending in .JPG comparing the files name format")
        NSPrint("against its EXIF data taken information.")
        NSPrint(" ")
        NSPrint("If the dates do not agree it prints to the screen the ")
        NSPrint("missclassification information but does not do anything else")
        NSPrint("")
        NSPrint("If the file contains no EXIF date taken information it simply")
        NSPrint("lists this fact.")
        NSPrint("  ------------------------------------------------------------------")
        NSPrint(" ")
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
