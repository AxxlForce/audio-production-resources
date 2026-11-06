# REAPER Lua + IntelliJ API definitions

This project generates EmmyLua definitions directly from REAPER's generated
ReaScript documentation.

## 1. IntelliJ

Install the Lua/EmmyLua plugin in IntelliJ IDEA.

Open this directory as the project.

Mark `api/` as a source/library directory if IntelliJ does not automatically
index it.

Your scripts go in `scripts/`.

## 2. Update the REAPER API

From the project root:

    python tools/update_reaper_api.py

This downloads:

    https://www.reaper.fm/sdk/reascript/reascripthelp.html

and creates:

    api/reaper_api.lua

For a REAPER-generated local documentation file:

    python tools/update_reaper_api.py --input "/path/to/reascripthelp.html"

The generated file is deliberately disposable: never edit it manually.

## 3. Use in scripts

The generated definitions are only for the IDE. They do not get loaded by
REAPER at runtime.

Example:

    local track = reaper.GetSelectedTrack(0, 0)
    reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", 18)

IntelliJ should now provide completion and parameter/type information.

## Notes

REAPER's official documentation states that up-to-date ReaScript documentation
can be generated from Help -> ReaScript documentation, so the local-input mode
is useful when the online documentation is behind your installed REAPER version.
