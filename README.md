# PhotoToolsSwift

A macOS command-line tool for organizing and backing up photos and videos into a structured directory hierarchy based on EXIF/QuickTime creation dates.

## Directory Structure

Photos and videos are organized into:

```
<archive>/
└── YYYY/
    └── MM-DD-YYYY/
        ├── YYYY-MM-DD-0000.JPG
        ├── YYYY-MM-DD-0001.HEIC
        ├── YYYY-MM-DD-0002.MOV
        └── ...
```

## Typical Workflow

1. Connect your iPhone (or any camera) to your Mac
2. Open **Image Capture** and download photos/videos into a folder (e.g. `~/Downloads/phone-photos`)
3. Run `photocopy ~/Downloads/phone-photos /Volumes/Photos`

That's it. `photocopy` reads the creation date from each file, copies it into the correct year and day directory, deduplicates, and renumbers everything chronologically. If a file already exists in the archive, the dedup step removes the duplicate automatically.

You don't need to keep track of which photos you've already imported — just download everything and let `photocopy` sort it out. Duplicates are handled, and new photos are merged into the correct position.

This works great as a family photo archive. Each family member connects their phone, downloads to a folder, and runs `photocopy` against the same archive. Everyone's photos and videos end up organized together by date.

You can also export originals from the Photos app (File > Export > Export Unmodified Originals) to preserve the embedded metadata, then run `photocopy` on the export folder.

## Tools

The project builds a single binary that operates as five different tools via symbolic links:

| Command | Description |
|---------|-------------|
| `photocopy` | Copy photos/videos from a source directory into the archive, organizing by creation date |
| `photorenumber` | Re-sort and sequentially renumber files in a directory by creation date |
| `photodedup` | Remove duplicate files (binary comparison) and renumber |
| `photocheck` | Validate that file creation dates match their directory placement |
| `photocheckexif` | Display creation date metadata for photos and videos |

## Usage

```
photocopy [--include-live] <sourceDirectory> <archiveDirectory>
photorenumber <dayDirectory|yearDirectory>
photodedup <dayDirectory>
photocheck <yearDirectory|dayDirectory>
photocheckexif <directory>
```

### Live Photo Handling

`photocopy` skips Live Photo MOV clips by default. Live Photos are detected by:
- **Paired name** — a MOV file with a matching HEIC/JPG in the same directory
- **Duration** — MOV files 4.5 seconds or shorter

Use `--include-live` to copy Live Photo clips along with everything else.

## Supported Formats

- JPG / JPEG (EXIF metadata)
- HEIC (EXIF metadata)
- MOV (QuickTime metadata)

## Building

```bash
make            # Debug build
make release    # Release build
make clean      # Clean build artifacts
make install    # Release build + install to /usr/local/bin with symlinks
```

Or open `PhotoToolsSwift.xcodeproj` in Xcode.

## Setup

Run `make install` to copy the binary to `/usr/local/bin` and create all symbolic links, or manually:

```bash
ln -s PhotoToolsSwift photocopy
ln -s PhotoToolsSwift photorenumber
ln -s PhotoToolsSwift photodedup
ln -s PhotoToolsSwift photocheck
ln -s PhotoToolsSwift photocheckexif
```