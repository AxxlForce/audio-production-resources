-- @description Combine selected tracks into multichannel PROXY (pre-FX)
-- @version 2.0
-- @about
--   Selected tracks are placed into a MONITOR folder.
--   A multichannel PROXY track is created outside the folder.
--
--   Each source track is routed PRE-FX to one channel of PROXY.
--
--   MONITOR:
--     - Master send disabled
--     - Hardware output 1/2 enabled
--
--   PROXY:
--     - N channels
--     - Source track 1 -> channel 1
--     - Source track 2 -> channel 2
--     - etc.
--
--   Master track is also expanded to N channels.

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

local MONITOR_NAME = "MONITOR"
local PROXY_NAME   = "PROXY"

------------------------------------------------------------
-- VALIDATION
------------------------------------------------------------

local num_tracks = reaper.CountSelectedTracks(0)

if num_tracks < 1 then
    reaper.ShowMessageBox(
        "Please select the source tracks in channel order.",
        "Multichannel Proxy",
        0
    )
    return
end

if num_tracks > 64 then
    reaper.ShowMessageBox(
        "REAPER supports a maximum of 64 track channels.",
        "Multichannel Proxy",
        0
    )
    return
end

------------------------------------------------------------
-- STORE SOURCE TRACKS
------------------------------------------------------------

local source_tracks = {}

for i = 0, num_tracks - 1 do
    source_tracks[#source_tracks + 1] =
        reaper.GetSelectedTrack(0, i)
end

------------------------------------------------------------
-- BEGIN
------------------------------------------------------------

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

------------------------------------------------------------
-- FIND INSERT POSITION
------------------------------------------------------------

local first_index =
    reaper.GetMediaTrackInfo_Value(
        source_tracks[1],
        "IP_TRACKNUMBER"
    ) - 1

local last_index =
    reaper.GetMediaTrackInfo_Value(
        source_tracks[#source_tracks],
        "IP_TRACKNUMBER"
    ) - 1

------------------------------------------------------------
-- CREATE MONITOR FOLDER
--
-- Insert immediately before the first source track.
------------------------------------------------------------

reaper.InsertTrackAtIndex(first_index, true)

local monitor_track =
    reaper.GetTrack(0, first_index)

reaper.GetSetMediaTrackInfo_String(
    monitor_track,
    "P_NAME",
    MONITOR_NAME,
    true
)

-- Folder parent
reaper.SetMediaTrackInfo_Value(
    monitor_track,
    "I_FOLDERDEPTH",
    1
)

-- Give the folder enough channels for stereo monitoring
reaper.SetMediaTrackInfo_Value(
    monitor_track,
    "I_NCHAN",
    2
)

------------------------------------------------------------
-- DISABLE MONITOR MASTER SEND
------------------------------------------------------------

reaper.SetMediaTrackInfo_Value(
    monitor_track,
    "B_MAINSEND",
    0
)

------------------------------------------------------------
-- HARDWARE OUTPUT 1/2
------------------------------------------------------------

local hw_send =
    reaper.CreateTrackSend(
        monitor_track,
        nil
    )

if hw_send >= 0 then

    -- Hardware output send
    reaper.SetTrackSendInfo_Value(
        monitor_track,
        1,
        hw_send,
        "I_DSTCHAN",
        0
    )

    -- Unity gain
    reaper.SetTrackSendInfo_Value(
        monitor_track,
        1,
        hw_send,
        "D_VOL",
        1.0
    )
end

------------------------------------------------------------
-- MOVE SOURCE TRACKS INTO FOLDER
------------------------------------------------------------

-- Since inserting the folder shifted the original tracks by +1,
-- they are now directly below the folder.
--
-- We don't need to physically move them: the folder hierarchy
-- is established by I_FOLDERDEPTH.

for i = 1, num_tracks do

    local track =
        reaper.GetTrack(0, first_index + i)

    if i == num_tracks then

        -- Last source track closes the folder
        reaper.SetMediaTrackInfo_Value(
            track,
            "I_FOLDERDEPTH",
            -1
        )

    else

        reaper.SetMediaTrackInfo_Value(
            track,
            "I_FOLDERDEPTH",
            0
        )

    end
end

------------------------------------------------------------
-- CREATE PROXY TRACK
--
-- Insert after the entire monitor folder.
------------------------------------------------------------

local proxy_index = first_index + num_tracks + 1

reaper.InsertTrackAtIndex(proxy_index, true)

local proxy_track =
    reaper.GetTrack(0, proxy_index)

reaper.GetSetMediaTrackInfo_String(
    proxy_track,
    "P_NAME",
    PROXY_NAME,
    true
)

------------------------------------------------------------
-- PROXY CHANNEL COUNT
------------------------------------------------------------

reaper.SetMediaTrackInfo_Value(
    proxy_track,
    "I_NCHAN",
    num_tracks
)

------------------------------------------------------------
-- ROUTE EACH SOURCE TRACK -> PROXY
--
-- PRE-FX
--
-- I_SENDMODE:
--   0 = post-fader
--   1 = pre-FX
--   2 = pre-fader
------------------------------------------------------------

for i = 1, num_tracks do

    local source_track =
        reaper.GetTrack(0, first_index + i)

    local send_index =
        reaper.CreateTrackSend(
            source_track,
            proxy_track
        )

    if send_index >= 0 then

        -- PRE-FX
        reaper.SetTrackSendInfo_Value(
            source_track,
            0,
            send_index,
            "I_SENDMODE",
            1
        )

        -- Source channel 1
        reaper.SetTrackSendInfo_Value(
            source_track,
            0,
            send_index,
            "I_SRCCHAN",
            1024
        )

        -- Destination channel i
        reaper.SetTrackSendInfo_Value(
            source_track,
            0,
            send_index,
            "I_DSTCHAN",
            1024 + (i - 1)
        )

        -- Unity gain
        reaper.SetTrackSendInfo_Value(
            source_track,
            0,
            send_index,
            "D_VOL",
            1.0
        )
    end
end

------------------------------------------------------------
-- EXPAND MASTER TRACK
------------------------------------------------------------

local master =
    reaper.GetMasterTrack(0)

reaper.SetMediaTrackInfo_Value(
    master,
    "I_NCHAN",
    num_tracks
)

------------------------------------------------------------
-- SELECT PROXY
------------------------------------------------------------

reaper.SetOnlyTrackSelected(proxy_track)

------------------------------------------------------------
-- FINISH
------------------------------------------------------------

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

reaper.Undo_EndBlock(
    "Create pre-FX multichannel proxy",
    -1
)
