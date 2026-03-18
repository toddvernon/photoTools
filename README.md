# PhotoToolsSwift

A macOS command-line tool for organizing and backing up photos into a structured directory hierarchy based on EXIF creation dates.

## Directory Structure

Photos are organized into:

```
<archive>/
└── YYYY/
    └── MM-DD-YYYY/
        ├── YYYY-MM-DD-0000.JPG
        ├── YYYY-MM-DD-0001.HEIC
        └── ...
```

## Tools

The project builds a single binary that operates as five different tools via symbolic links:

| Command | Description |
|---------|-------------|
| `photocopy` | Copy photos from a source directory into the archive, organizing by EXIF date |
| `photorenumber` | Re-sort and sequentially renumber photos in a directory by creation date |
| `photodedup` | Remove duplicate files (binary comparison) and renumber |
| `photocheck` | Validate that photo EXIF dates match their directory placement |
| `photocheckexif` | Display EXIF creation date metadata for photos |

## Usage

```
photocopy <sourceDirectory> <archiveDirectory>
photorenumber <dayDirectory|yearDirectory>
photodedup <dayDirectory>
photocheck <yearDirectory|dayDirectory>
photocheckexif <directory>
```

## Supported Formats

- JPG / JPEG
- HEIC

## Building

Open `PhotoToolsSwift.xcodeproj` in Xcode and build, or use `xcodebuild` from the command line.

## Setup

After building, create symbolic links to the binary for each tool:

```bash
ln -s PhotoToolsSwift photocopy
ln -s PhotoToolsSwift photorenumber
ln -s PhotoToolsSwift photodedup
ln -s PhotoToolsSwift photocheck
ln -s PhotoToolsSwift photocheckexif
```
