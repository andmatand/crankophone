import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/ui"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound

local MAX_LENGTH_SECONDS <const> = 10
local FPS <const> = 40

local samplePlayer
local rate = 1
local vx = 0

local downArrowImage = gfx.image.new("images/down_arrow.png")

local micLevels = {}
local waveformImage = gfx.image.new(400, 240, gfx.kColorWhite)

local state_initial = 0
local state_play = 1
local state_recording = 2

local crankIndicatorIsEnabled = true
local crankFrames = 0

local playhead

function init()
    playdate.display.setRefreshRate(FPS)

    playhead = create_playhead_sprite()
    playhead:add()

    gfx.sprite.setBackgroundDrawingCallback(function(x, y, w, h)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        waveformImage:draw(0, 0)
    end)

    local font = gfx.font.new("font/Roobert-11-Medium")
    gfx.setFont(font)

    state = state_initial
end

function playdate.update()
    if playdate.buttonJustPressed(playdate.kButtonB) then
        state = state_recording
        gfx.clear(gfx.kColorWhite)
        micLevels = {}
        playdate.sound.micinput.startListening()

        if samplePlayer then
            samplePlayer:stop()
        end

        local buffer = snd.sample.new(MAX_LENGTH_SECONDS, snd.kFormat16bitMono)
        snd.micinput.recordToSample(buffer, function(sample)
            -- fix weird initial pop when using headset mic
            -- if snd.micinput.getSource() == "headset" then
            --     local sampleRate = sample:getSampleRate()
            --     local frameCount = sampleRate * sample:getLength()
            --     local startOffset = math.floor(frameCount * .33)
            --     local micLevelIndexOffset = (startOffset / sampleRate) * FPS

            --     trimmed = sample:getSubsample(startOffset, frameCount)
            --     if trimmed ~= nil then
            --         sample = trimmed

            --         local newMicLevels = {}
            --         for i, level in ipairs(micLevels) do
            --             if i > micLevelIndexOffset then
            --                 table.insert(newMicLevels, level)
            --             end
            --         end
            --         micLevels = newMicLevels
            --     else
            --         print('subsample failed for some reason')
            --     end
            -- end

            state = state_play
            if crankIndicatorIsEnabled then
                playdate.ui.crankIndicator:start()
            end

            gfx.pushContext(waveformImage)
            gfx.clear(gfx.kColorWhite)
            render_waveform()
            gfx.popContext()

            samplePlayer = snd.sampleplayer.new(sample)
            samplePlayer:setVolume(1.0)
            samplePlayer:play(0)
        end)
    elseif playdate.buttonJustReleased(playdate.kButtonB) then
        playdate.sound.micinput.stopRecording()
        playdate.sound.micinput.stopListening()
    end

    local crankChange = playdate.getCrankChange()
    rate *= .8
    rate += crankChange / 45

    if playdate.buttonIsPressed(playdate.kButtonLeft) then
        rate = -1
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        rate = 1
    end

    if state == state_play and crankIndicatorIsEnabled and crankChange ~= 0 then
        crankFrames += 1
        if crankFrames > FPS then
            crankIndicatorIsEnabled = false
        end
    end

    if samplePlayer then
        samplePlayer:setRate(rate)
    end

    if state == state_recording then
        local micLevel = snd.micinput.getLevel()
        table.insert(micLevels, micLevel)
    end

    playdate.timer.updateTimers()

    if state == state_play then
        update_playhead()
        gfx.sprite.update()
    else
        draw_non_play_state()
    end

    if state == state_play and crankIndicatorIsEnabled then
        playdate.ui.crankIndicator:update()
    end
end

function draw_non_play_state()
    if state == state_initial then
        local cx = 274

        gfx.drawTextAligned("hold Ⓑ\nto record", cx, 180, kTextAlignment.center)
        downArrowImage:draw(cx - 9, 228)
    elseif state == state_recording then
        render_waveform()
    end
end

function update_playhead()
    local x = (samplePlayer:getOffset() / samplePlayer:getLength()) * 400

    playhead:moveTo(x, 0)
end

function render_waveform()
    gfx.setColor(gfx.kColorBlack)

    local sliceWidth = 400 / (MAX_LENGTH_SECONDS * FPS)
    local normalizationFactor = 1

    if state == state_play then
        sliceWidth = 400 / #micLevels

        local highestMicLevel = 0
        for _, level in pairs(micLevels) do
            highestMicLevel = math.max(level, highestMicLevel)
        end
        normalizationFactor = 1 / highestMicLevel
    end

    for i, level in ipairs(micLevels) do
        local x = (i - 1) * sliceWidth
        local h = math.max(1, level * normalizationFactor * 240)

        gfx.fillRect(x, 120 - (h / 2), sliceWidth, h)
    end
end

function create_playhead_sprite()
    local image = gfx.image.new(2, 240, gfx.kColorClear)

    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 2, 240)
    gfx.popContext()

    local sprite = gfx.sprite.new(image)
    sprite:setCenter(0, 0)
    sprite:setImageDrawMode(gfx.kDrawModeXOR)
    sprite:setImageDrawMode(gfx.kDrawModeNXOR)

    return sprite
end

init()
