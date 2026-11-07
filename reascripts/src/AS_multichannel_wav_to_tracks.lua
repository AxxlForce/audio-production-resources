-- @description Distribute multichannel WAV to selected tracks (Ch 1 upward)
-- @version 1.0
-- @about
--   select one multichannel audio item and the destination tracks.
--   the item is copied to the selected tracks and each copy is assigned
--   to consecutive source channels starting with channel 1.
--
--   Example:
--     Track 1  -> WAV channel 1
--     Track 2  -> WAV channel 2
--     ...
--     Track 18 -> WAV channel 18

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function chanmode_from_channel(ch)
    -- REAPER channel mode:
    -- 3 = mono channel 1
    -- 4 = mono channel 2
    -- 5 = mono channel 3
    -- ...
    return ch + 2
end


local function copy_item_to_track(source_item, dest_track)

    -- Create a new item on destination track
    local new_item = reaper.AddMediaItemToTrack(dest_track)

    -- Copy complete item state
    local _, chunk = reaper.GetItemStateChunk(source_item, "", false)

    if not chunk then
        reaper.DeleteTrackMediaItem(dest_track, new_item)
        return nil
    end

    reaper.SetItemStateChunk(new_item, chunk, false)

    return new_item
end


------------------------------------------------------------
-- VALIDATION
------------------------------------------------------------

local selected_items = reaper.CountSelectedMediaItems(0)

if selected_items ~= 1 then
    reaper.ShowMessageBox(
        "Please select exactly one multichannel WAV item.",
        "Multichannel Distributor",
        0
    )
    return
end


local source_item = reaper.GetSelectedMediaItem(0, 0)
local source_take = reaper.GetActiveTake(source_item)

if not source_take or reaper.TakeIsMIDI(source_take) then
    reaper.ShowMessageBox(
        "The selected item must contain an audio take.",
        "Multichannel Distributor",
        0
    )
    return
end


local source = reaper.GetMediaItemTake_Source(source_take)

if not source then
    reaper.ShowMessageBox(
        "Could not access the audio source.",
        "Multichannel Distributor",
        0
    )
    return
end


local num_channels = reaper.GetMediaSourceNumChannels(source)

if num_channels < 2 then
    reaper.ShowMessageBox(
        "The selected WAV is not multichannel.",
        "Multichannel Distributor",
        0
    )
    return
end


------------------------------------------------------------
-- GET DESTINATION TRACKS
------------------------------------------------------------

local tracks = {}

for i = 0, reaper.CountSelectedTracks(0) - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(0, i)
end


if #tracks == 0 then
    reaper.ShowMessageBox(
        "Please select the destination tracks.",
        "Multichannel Distributor",
        0
    )
    return
end


if #tracks > num_channels then
    reaper.ShowMessageBox(
        string.format(
            "You selected %d tracks, but the WAV only has %d channels.",
            #tracks,
            num_channels
        ),
        "Multichannel Distributor",
        0
    )
    return
end


------------------------------------------------------------
-- CREATE COPIES
------------------------------------------------------------

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local created_items = {}

for i, track in ipairs(tracks) do

    local channel = i

    -- Copy the complete media item
    local new_item = copy_item_to_track(source_item, track)

    if new_item then

        local take = reaper.GetActiveTake(new_item)

        if take then

            -- Assign this take to one specific source channel
            reaper.SetMediaItemTakeInfo_Value(
                take,
                "I_CHANMODE",
                chanmode_from_channel(channel)
            )

            -- Give the take a useful name
            reaper.GetSetMediaItemTakeInfo_String(
                take,
                "P_NAME",
                string.format("CH %02d", channel),
                true
            )

            created_items[#created_items + 1] = new_item
        end
    end
end


------------------------------------------------------------
-- SELECT NEW ITEMS
------------------------------------------------------------

-- clear item selection
reaper.SelectAllMediaItems(0, false)

-- select newly created items
for _, item in ipairs(created_items) do
    reaper.SetMediaItemSelected(item, true)
end

-- group them items
reaper.Main_OnCommand(40032, 0)


------------------------------------------------------------
-- FINISH
------------------------------------------------------------

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()

reaper.Undo_EndBlock(
    "Distribute multichannel WAV to selected tracks",
    -1
)
