on run argv
    set inputPath to item 1 of argv
    set outputPath to item 2 of argv
    tell application "Microsoft Word"
        activate
        open inputPath
        set activeDoc to active document
        try
            update fields of activeDoc
        end try
        save activeDoc
        save as activeDoc file name outputPath file format format PDF
        close activeDoc saving no
    end tell
end run
