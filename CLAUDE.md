# PhotoToolsSwift

## Rules

### No file deletion unless explicitly approved
The only place a file is deleted is in `photodedup` (`PhotoDirectory.compareAgainstOthers`), which removes byte-identical duplicates. No new code should ever delete a file unless the user explicitly says it's OK. This includes `removeItem`, `trashItem`, or any other form of file removal.

### Directory date takes precedence over file metadata
When a file is in a day directory (MM-DD-YYYY), the directory's date is the source of truth for naming. If the file's embedded metadata (EXIF or QuickTime) disagrees with the directory date, ignore the metadata and use the directory date. Print a "strictly misclassified" warning so the user knows. Never silently move or re-sort a file out of a directory based on its metadata — the user placed it there intentionally.

## Architecture

- Single binary, five tools via symlink: `photocopy`, `photorenumber`, `photodedup`, `photocheck`, `photocheckexif`
- `main.swift` dispatches based on program name
- `PhotoFile` handles individual file metadata extraction and naming
- `PhotoDirectory` handles batch operations on directories of files
- Supported formats: JPG, JPEG, HEIC, MOV

## Naming Conventions

- Conforming filename: `YYYY-MM-DD-XXXX.EXT` (4-digit zero-padded sequence number)
- Day directory: `MM-DD-YYYY`
- Year directory: `YYYY`
