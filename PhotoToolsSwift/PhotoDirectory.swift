//---------------------------------------------------------------------------------------------------------------------
// PhotoDirectory Class
//
//
//---------------------------------------------------------------------------------------------------------------------

import Foundation


//---------------------------------------------------------------------------------------------------------------------
// DirectoryClassificationType:
//
//---------------------------------------------------------------------------------------------------------------------

enum DirectoryClassificationType {
    case year
    case day
    case other
}

//---------------------------------------------------------------------------------------------------------------------
// PhotoDirectory:
//
//---------------------------------------------------------------------------------------------------------------------

class PhotoDirectory {
    
    var fullPath: String = ""
    var directoryClassification: DirectoryClassificationType = .other
    var year: Int = 0
    var month: Int = 0
    var day: Int = 0
    var photoNameArray: [PhotoFile] = []
    var lastTryedPhotoNumber: Int = 0
    
    //-----------------------------------------------------------------------------------------------------------------
    // init:
    //
    //=================================================================================================================
    init() {
        initMemberVariables()
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // initMemberVariables:
    //
    //=================================================================================================================
    func initMemberVariables() {
        fullPath = ""
        lastTryedPhotoNumber = 0
        directoryClassification = .other
        year = 0
        month = 0
        day = 0
        photoNameArray = []
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // init: using directory name
    //
    //=================================================================================================================
    convenience init(directoryName: String) {
        self.init()
        if PhotoDirectory.isADirectory(directoryName) {
            fullPath = directoryName
            parseDirectoryName(fullPath)
            loadDirectory()
        }
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // renumberPhotoFiles:
    //
    //=================================================================================================================
    func renumberPhotoFiles() {
        
        //-------------------------------------------------------------------------------------------------------------
        // sort the array of photos accending by date/time photo was taken
        //-------------------------------------------------------------------------------------------------------------
        photoNameArray.sort(by: {$0.creationDate! < $1.creationDate!})
        
        //-------------------------------------------------------------------------------------------------------------
        // for each photo rename into the existing name plus a .tmp at the end
        //-------------------------------------------------------------------------------------------------------------
        for photo in photoNameArray {
            let tempFileName = photo.fullPathToFile + ".tmp"
            try? FileManager.default.moveItem(atPath: photo.fullPathToFile, toPath: tempFileName)
        }
        
        //-------------------------------------------------------------------------------------------------------------
        // now renumber each file using a created year/day-month-year format
        //-------------------------------------------------------------------------------------------------------------
        var fileNumber = 0
        
        for photo in photoNameArray {
        
            //---------------------------------------------------------------------------------------------------------
            // the source file we are going to rename from the array
            //---------------------------------------------------------------------------------------------------------
            let tempFileName = photo.fullPathToFile + ".tmp"
            var newFileName = ""
            
            //---------------------------------------------------------------------------------------------------------
            // if the EXIF data does not match the name we are constructing based on the day,month, year of the
            // directory, ignore the EXIF data.  We do this so we put photos with incorrect EXIF data in a known
            // good date directory.  Issue a warning that we did that in case it was not the correct thing to do
            //---------------------------------------------------------------------------------------------------------
            if (photo.year != year || photo.month != month || photo.day != day) {
                
                NSPrint("strictly misclassified photo: %@ ignoring file date and using directory name", photo.fullPathToFile)
                
                newFileName = PhotoFile.conformingFileNameForPhotoNameForYear(
                    year,
                    andMonth: month,
                    andDay: day,
                    andNumber: fileNumber,
                    andExt: photo.fileExtension)
                
                newFileName = (fullPath as NSString).appendingPathComponent(newFileName)
                
            //---------------------------------------------------------------------------------------------------------
            // the EXIF data did match the constructed file name
            //---------------------------------------------------------------------------------------------------------
            } else {
                
                newFileName = PhotoFile.conformingFileNameForPhotoNameForYear(
                    photo.year,
                    andMonth: photo.month,
                    andDay: photo.day,
                    andNumber: fileNumber,
                    andExt: photo.fileExtension)
                
                newFileName = (photo.directory as NSString).appendingPathComponent(newFileName)
            }
            
            //---------------------------------------------------------------------------------------------------------
            // now rename the file
            //---------------------------------------------------------------------------------------------------------
            try? FileManager.default.moveItem(atPath: tempFileName, toPath: newFileName)
            
            //---------------------------------------------------------------------------------------------------------
            // increment the file number
            //---------------------------------------------------------------------------------------------------------
            fileNumber += 1
        }
        
        NSPrint("photoRenumber: renumbered %d files", photoNameArray.count)
        reloadDirectory()
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // checkFilesForDate:
    //
    //=================================================================================================================
    func checkFilesForDate() {
        
        //-------------------------------------------------------------------------------------------------------------
        // make sure we are working with a day type directory
        //-------------------------------------------------------------------------------------------------------------
        if directoryClassification == .day {
            
            //---------------------------------------------------------------------------------------------------------
            // sort the array of photos assending
            //---------------------------------------------------------------------------------------------------------
            photoNameArray.sort(by: {$0.creationDate! < $1.creationDate!})

            for photo in photoNameArray {

                //-----------------------------------------------------------------------------------------------------
                // check to see if the photo has a time and date, if does compare against directory name
                //-----------------------------------------------------------------------------------------------------
                if (photo.hasPhotoDateTime()) {
                    
                    //-------------------------------------------------------------------------------------------------
                    // print a warning that the photo EXIF data does not match the directory name
                    //-------------------------------------------------------------------------------------------------
                    if photo.year != year || photo.month != month || photo.day != day {
                        NSPrint(" misclassified photo: %@ should be in %@", photo.fullPathToFile, photo.conformingDayDirectoryName())
                    }
                    
                } else {
                    
                    NSPrint(" no date information for photo: %@ leaving in current directory", photo.fullPathToFile)
                }
            }
        }
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // loadDirectory:
    //
    //=================================================================================================================
    func loadDirectory() {
        
        var isDir: ObjCBool = false
                
        if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
            
            if let contentOfDirectory = try? FileManager.default.contentsOfDirectory(atPath: fullPath) {
                
                for file in contentOfDirectory {
                
                    let fileFullPath = (fullPath as NSString).appendingPathComponent(file);
                    let photoFile    = PhotoFile(withFile: fileFullPath)
                                        
                    if photoFile.fileClassification == FileClassification.imageNameConforming || 
                       photoFile.fileClassification == FileClassification.imageNameNonconforming {
                        
                        photoNameArray.append(photoFile)
                    }
                }
            }
        }
    }
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    func reloadDirectory() {
        let thePath = fullPath
        initMemberVariables()
        fullPath = thePath
        parseDirectoryName(thePath)
        loadDirectory()
    }
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    static func isADirectory(_ path: String) -> Bool {
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            return true
        }
        
        return false
    }
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    func parseDirectoryName(_ path: String) {
        directoryClassification = PhotoDirectory.parseDirectoryName(path, forYear: &year, forMonth: &month, forDay: &day)
    }
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    static func parseDirectoryName(_ path: String, forYear year: inout Int, forMonth month: inout Int, forDay day: inout Int) -> DirectoryClassificationType {
        
        year  = 0
        month = 0
        day   = 0
        
        var dt: DirectoryClassificationType = .other
        
        var isDir: ObjCBool = false
        
        //-------------------------------------------------------------------------------------------------------------
        // load the directory if it is actually a directory
        //-------------------------------------------------------------------------------------------------------------
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
            
            //---------------------------------------------------------------------------------------------------------
            // get the short name
            //---------------------------------------------------------------------------------------------------------
            let theDirectoryName = (path as NSString).lastPathComponent
            
            //---------------------------------------------------------------------------------------------------------
            // seperate into the individual parts
            //---------------------------------------------------------------------------------------------------------
            let directoryNameParts = theDirectoryName.components(separatedBy: "-")
            
            //---------------------------------------------------------------------------------------------------------
            // if the directory has only one part, we will check if it looks like a year
            //---------------------------------------------------------------------------------------------------------
            if directoryNameParts.count == 1 {
                
                //-----------------------------------------------------------------------------------------------------
                // check if its and integer and looks plausable
                //-----------------------------------------------------------------------------------------------------
                let part = directoryNameParts[0]
                
                if let yearValue = Int(part), yearValue > 1960, yearValue < 2050 {
                    year = yearValue
                    return .year
                }
                return .other
            }
            
            //---------------------------------------------------------------------------------------------------------
            // if the directory name has 3 parts, we will see if it matches mm-dd-yyyy
            //---------------------------------------------------------------------------------------------------------
            if directoryNameParts.count == 3 {
                
                //-----------------------------------------------------------------------------------------------------
                // for now we will assume its a day type directory
                //-----------------------------------------------------------------------------------------------------
                dt = .day
                
                let part0 = directoryNameParts[0];
                let part1 = directoryNameParts[1];
                let part2 = directoryNameParts[2];
                
                //-------------------------------------------------------------------------------------------------
                // test if the directory name parts look legit
                //-------------------------------------------------------------------------------------------------
                guard Int(part0) != nil else {
                    dt = .other
                    return dt
                }
                
                guard Int(part1) != nil else {
                    dt = .other
                    return dt
                }
                
                guard Int(part2) != nil else {
                    dt = .other
                    return dt
                }
                
                let part0int = Int(part0)
                let part1int = Int(part1)
                let part2int = Int(part2)
                
                if part2int! < 1960 || part2int! > 2050 {
                    dt = .other
                    return dt
                }
                
                month = part0int!
                day   = part1int!
                year  = part2int!
                                
                return dt
            }
        }
        return dt
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    func dedup() {
        
        for file in photoNameArray {
            compareAgainstOthers(file)
        }
        reloadDirectory()
    }
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    func compareAgainstOthers(_ thePhotoFile: PhotoFile) {
        
        guard FileManager.default.fileExists(atPath: thePhotoFile.fullPathToFile) else {
            return
        }
        
        for nextFile in photoNameArray {
            
            guard FileManager.default.fileExists(atPath: nextFile.fullPathToFile) else {
                continue
            }
            
            if thePhotoFile.fullPathToFile != nextFile.fullPathToFile {
                if FileManager.default.contentsEqual(atPath: thePhotoFile.fullPathToFile, andPath: nextFile.fullPathToFile) {
                    NSPrint("removing duplicate: %@ same as --> %@", nextFile.fullPathToFile, thePhotoFile.fullPathToFile)
                    try? FileManager.default.removeItem(atPath: nextFile.fullPathToFile)
                }
            }
        }
    }
}


