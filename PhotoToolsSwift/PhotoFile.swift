//---------------------------------------------------------------------------------------------------------------------
//
//  PhotoFile.swift
//  PhotoToolsSwift
//
//  Created by Todd Vernon on 2/26/24.
//
//---------------------------------------------------------------------------------------------------------------------

import Foundation
import ImageIO
import CoreImage
import AVFoundation
import Darwin


//---------------------------------------------------------------------------------------------------------------------
// FileClassification
//
//---------------------------------------------------------------------------------------------------------------------

enum FileClassification {
    case imageNameNonconforming
    case imageNameConforming
    case other
}


//---------------------------------------------------------------------------------------------------------------------
// PhotoFile
//
//---------------------------------------------------------------------------------------------------------------------

class PhotoFile {
    var fullPathToFile: String = ""
    var directory: String = ""
    var fileName: String = ""
    var fileExtension: String = ""
    var fileNameAndExtension: String = ""
    var year: Int = 0
    var month: Int = 0
    var day: Int = 0
    var hour: Int = 0
    var minute: Int = 0
    var second: Int = 0
    var creationDate: Date?
    var hasEXIFdata: Bool = false
    var number: Int = 0
    var fileClassification: FileClassification = .other
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================

    init() {
        initMemberVariables()
    }
    
    //-----------------------------------------------------------------------------------------------------------------
    // init:
    //
    //=================================================================================================================
    init(withFile filePath: String) {
        initMemberVariables()
        parseFileName(filePath)
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // initMemberVariables:
    //
    //=================================================================================================================
    func initMemberVariables() {
        fullPathToFile = ""
        directory = ""
        fileName = ""
        fileExtension = ""
        fileNameAndExtension = ""
        year = 0
        month = 0
        day = 0
        hour = 0
        minute = 0
        second = 0
        creationDate = nil
        hasEXIFdata = false
        number = 0
        fileClassification = .other
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    func isImageFile() -> Bool {
        return fileClassification == .imageNameConforming || fileClassification == .imageNameNonconforming
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    func hasPhotoDateTime() -> Bool {
        return hasEXIFdata
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    func parseFileName(_ filePath: String) {
        
        fullPathToFile = filePath
        fileNameAndExtension = (fullPathToFile as NSString).lastPathComponent
        directory = (fullPathToFile as NSString).deletingLastPathComponent
        fileExtension = (fileNameAndExtension as NSString).pathExtension
        fileName = (fileNameAndExtension as NSString).deletingPathExtension
        
        //-------------------------------------------------------------------------------------------------------------
        // check if the file ends in JPG, JPEG, or HEIC
        //-------------------------------------------------------------------------------------------------------------
                
        if fileExtension.caseInsensitiveCompare("JPG") != .orderedSame {
            if fileExtension.caseInsensitiveCompare("JPEG") != .orderedSame {
                if fileExtension.caseInsensitiveCompare("HEIC") != .orderedSame {
                    fileClassification = .other
                    return
                }
            }
        }
        
        //-------------------------------------------------------------------------------------------------------------
        // get the embedded EXIF creation time/date if its there
        //
        //-------------------------------------------------------------------------------------------------------------
        getEXIFdata()
        
        //-------------------------------------------------------------------------------------------------------------
        // create an date object so we can use to compare when sorting
        //-------------------------------------------------------------------------------------------------------------
     
        var comps = DateComponents()
        comps.day = day
        comps.month = month
        comps.year = year
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        let cal = Calendar(identifier: .gregorian)
        creationDate = cal.date(from: comps)
        
        //-------------------------------------------------------------------------------------------------------------
        // now see if the existing file name is conforming or nonconforming.  If the file name is conforming we will
        // use it as classified event if the embedded data is incorrect.  This allows us to place photos in a directory
        // we know to be correct even if the file itself is wrong (ie date was incorrect on camera)
        //
        // IMAGE_FILE_NAME_CONFORMING = 2018-01-19-0000.JPG
        // IMAGE_FILE_NAME_NONCONFORMING = fred.JPG
        //-------------------------------------------------------------------------------------------------------------

        let filePathParts = fileName.components(separatedBy: "-")
        if filePathParts.count != 4 {
            fileClassification = .imageNameNonconforming
            return
        }
        
        fileClassification = .imageNameConforming
        
        //-------------------------------------------------------------------------------------------------------------
        // for each segment of the name (check that its just digits), then check the year to be sure it looks correct
        //-------------------------------------------------------------------------------------------------------------
        for part in filePathParts {
          
            //---------------------------------------------------------------------------------------------------------
            // first just check of the part is a number
            //---------------------------------------------------------------------------------------------------------
            if !Util.isStringOfDigits(part) {
                fileClassification = .imageNameNonconforming
            }
            
            //---------------------------------------------------------------------------------------------------------
            // second just look if the data is reasonable
            //---------------------------------------------------------------------------------------------------------
            if let integerValue = Int(part) {
                let value = integerValue
                if value < 1960 || value > 2050 {
                    fileClassification = .imageNameNonconforming
                }
            }
        }
    }
    
    //-----------------------------------------------------------------------------------------------------------------
    // conformingFileNameForPhotoNameForYear:
    //
    //=================================================================================================================
    static func conformingFileNameForPhotoNameForYear(_ y: Int, andMonth m: Int, andDay d: Int, andNumber number: Int, andExt e: String) -> String {
        return "\(yearAsString(y))-\(monthAsString(m))-\(dayAsString(d))-\(numberAsString(number)).\(e)"
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // conformingFileName:
    //
    //=================================================================================================================
    func conformingFileName() -> String {
        return PhotoFile.conformingFileNameForPhotoNameForYear(year, andMonth: month, andDay: day, andNumber: number, andExt: fileExtension)
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // conformingFileNameFromFileDateWithNumber:
    //
    //=================================================================================================================
    func conformingFileNameFromFileDateWithNumber(_ photoNumber: Int) -> String {
        return "\(PhotoFile.yearAsString(year))-\(PhotoFile.monthAsString(month))-\(PhotoFile.dayAsString(day))-\(PhotoFile.numberAsString(photoNumber)).\(fileExtension)"
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    //
    //
    //=================================================================================================================
    func photoDate() -> String {
        return "\(PhotoFile.yearAsString(year))-\(PhotoFile.monthAsString(month))-\(PhotoFile.dayAsString(day))"
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // conformingFileNameWithPathFromFileDateWithNumber:
    //
    //=================================================================================================================
    func conformingFileNameWithPathFromFileDateWithNumber(_ photoNumber: Int) -> String {
        return "\(directory)/\(conformingFileNameFromFileDateWithNumber(photoNumber))"
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // conformingDayDirectoryName:
    //
    //-================================================================================================================
    func conformingDayDirectoryName() -> String {
        return "\(PhotoFile.monthAsString(month))-\(PhotoFile.dayAsString(day))-\(PhotoFile.yearAsString(year))"
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // conformingYearDirectoryName:
    //
    //=================================================================================================================
    func conformingYearDirectoryName() -> String {
        return "\(PhotoFile.yearAsString(year))"
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // yearAsString:
    //
    //=================================================================================================================
    static func yearAsString(_ year: Int) -> String {
        return String(format: "%04d", year)
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // monthAsString:
    //
    //=================================================================================================================
    static func monthAsString(_ month: Int) -> String {
        return String(format: "%02d", month)
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // dayAsString:
    //
    //=================================================================================================================
    static func dayAsString(_ day: Int) -> String {
        return String(format: "%02d", day)
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // numberAsString:
    //
    //=================================================================================================================
    static func numberAsString(_ number: Int) -> String {
        return String(format: "%04d", number)
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // getEXIFdata: get the photo creation date and time embedded in the photo
    //
    //=================================================================================================================
    
     
    

    func getEXIFdata() {

        let imageFileURL = URL(fileURLWithPath: fullPathToFile)

        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let imageSource = CGImageSourceCreateWithURL(imageFileURL as CFURL, options as CFDictionary) else {
            return
        }

        //-------------------------------------------------------------------------------------
        // NOTE
        // Suppress the CoreFoundation warning emitted during metadata parsing.
        // ------------------------------------------------------------------------------------
        let imagePropertiesAny: CFDictionary? = withStderrSuppressed {
            CGImageSourceCopyPropertiesAtIndex(imageSource, 0, options as CFDictionary)
        }

        guard let imageProperties = imagePropertiesAny as? [CFString: Any] else {
            return
        }

        guard let exifTree = imageProperties[kCGImagePropertyExifDictionary] as? [CFString: Any] else {
            return
        }

        guard let stringValue = exifTree[kCGImagePropertyExifDateTimeOriginal] as? String else {
            return
        }

        let dateTimeArray = stringValue.components(separatedBy: " ")
        guard dateTimeArray.count == 2 else { return }

        let dateParts = dateTimeArray[0].components(separatedBy: ":")
        let timeParts = dateTimeArray[1].components(separatedBy: ":")

        guard dateParts.count == 3, timeParts.count == 3 else { return }

        guard
            let y = Int(dateParts[0]),
            let m = Int(dateParts[1]),
            let d = Int(dateParts[2]),
            let h = Int(timeParts[0]),
            let min = Int(timeParts[1]),
            let sec = Int(timeParts[2])
        else { return }

        year = y
        month = m
        day = d
        hour = h
        minute = min
        second = sec
        hasEXIFdata = true
    }
    
    
    //-----------------------------------------------------------------------------------------------------------------
    // withStderrSuppressed: redirects stderr to /dev/null for a single call.  Used to prevent stderr getting ELIF
    // data.  Appled added some stuff that throws errors on certain files with proprietary data.
    //
    // Its a hack but the only way to keep the annoying error from popping up.
    //
    //=================================================================================================================
    @discardableResult
    func withStderrSuppressed<T>(_ body: () throws -> T) rethrows -> T {
        // Save current stderr
        fflush(stderr)
        let savedStderr = dup(fileno(stderr))

        // Redirect stderr -> /dev/null
        guard let devNull = fopen("/dev/null", "w") else {
            return try body()
        }
        dup2(fileno(devNull), fileno(stderr))

        defer {
            // Restore stderr
            fflush(stderr)
            dup2(savedStderr, fileno(stderr))
            close(savedStderr)
            fclose(devNull)
        }

        return try body()
    }
    

    //-----------------------------------------------------------------------------------------------------------------
    // debugPrint: a method prints out stats on the photo files for debug
    //
    //=================================================================================================================
    func debugPrint() {
        var s = ""
        switch fileClassification {
            case .imageNameNonconforming:
                s = "IMAGE_FILE_NAME_NONCONFORMING"
            case .imageNameConforming:
                s = "IMAGE_FILE_NAME_CONFORMING"
            case .other:
                s = "OTHER_FILE"
        }
        
        NSPrint("-------")
        NSPrint("currentNameConforming=\(s)")
        NSPrint("fullPathToFile=\(fullPathToFile)")
        NSPrint("fileName=\(fileName)")
        NSPrint("fileExtension=\(fileExtension)")
        NSPrint("fileNameAndExtension=\(fileNameAndExtension)")
        NSPrint("number=\(number)")
        NSPrint("Date Created: Year=\(year), Month=\(month), Day=\(day), Hour=\(hour), Minute=\(minute), Second=\(second)")
        NSPrint("ConformingYearDirectoryName=\(conformingDayDirectoryName())")
        NSPrint("ConformingDayDirectoryName=\(conformingDayDirectoryName())")
        NSPrint("ConformingFileName=\(conformingFileNameFromFileDateWithNumber(0))")
    }
}
