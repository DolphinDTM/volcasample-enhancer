<CsoundSynthesizer>

<CsOptions> 
-n   ;Do not send to sound disk
-m16 ;Supress console messages
-Ma  ;Listen to all MIDI input devices
-Q2  ;Send to MIDI output device 5 - Change the number for your own device.
</CsOptions>

<CsInstruments>
ksmps = 1

;MIDI Status Types
#define NOTE_OFF   # 128 # ;Note Number      | Velocity
#define NOTE_ON    # 144 # ;Note Number      | Velocity
#define POLY_AFTER # 160 # ;Note Number      | Value
#define CONTROL    # 176 # ;Control Number   | Value
#define PROGRAM    # 192 # ;Program          | N/A
#define CHAN_AFTER # 208 # ;Value            | N/A
#define PITCHBEND  # 224 # ;LSB              | MSB

;volca sample CC params
#define VOLCA_LEVEL     #  7 #
#define VOLCA_PAN       # 10 #

#define VOLCA_START     # 40 #
#define VOLCA_LENGTH    # 41 #

#define VOLCA_HICUT     # 42 #

#define VOLCA_SPEED     # 43 #
#define VOLCA_CHROMATIC # 49 #

#define VOLCA_PITCH     # 44 #
#define VOLCA_PITCHATK  # 45 #
#define VOLCA_PITCHDEC  # 46 #

#define VOLCA_ATTACK    # 47 #
#define VOLCA_DECAY     # 48 #

#define VOLCA_DELAY     # 50 #

#define VOLCA_LOOP      # 68 # ;ON/OFF 
#define VOLCA_REVERB    # 70 # ;ON/OFF
#define VOLCA_REVERSE   # 75 # ;ON/OFF

#define VOLCA_REVERBMIX # 91 # ;Channel 1 only
/*********************************************/

maxalloc  1, 1 ;Max 1 instance of the input intercepter
massign   0, 1 ;Send all MIDI to intercepter
pgmassign 0, 1 ;Send all Programs to intercepter

alwayson 1

instr 1
    kGroup[][]   init      2, 10
    kGroup       fillarray 1,  2,  3,  0,  0,  0,  0,  0,  0,  0, \ ;Group MIDI Rx (0 = Disabled)
                           5,  3,  1,  1,  0,  0,  0,  0,  0,  0    ;Group Polyphony/Size (Sum of row cannot exceed 10)
    kLastNote[]  init      16    ;Array with the last note for each of the 16 MIDI channels
    kNoteCh[][]  init      2, 10 ;Array storing NoteNum and Channel pairs in an order corresponding to MIDI Tx
    kPolyCycle[] fillarray 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ;Array storing current increment for each group
    ;printarray kPolyCycle, 1, "%d"

    while (sumarray(getrow(kGroup, 1)) > 10) do
        printf "ERROR: Sum of group polyphonies exceeds 10! (Currently: %d)\nPlease lower the polyphony limit of one or several groups.\n", 1, sumarray(getrow(kGroup, 1))
    od

    /*
    DISABLE (-1): Do not send any MIDI OUT messages.

    MIDI THRU (0): Send input MIDI as is without modifications. 
    Same as connecting your MIDI device directly to the volca sample.

    SINGLE MODE (1): MIDI Note and Velocity is turned into CC to 
    control chromatic pitch, level and/or hicut. 
    Channel corresponds to sample part.

    POLYPHONIC MODE (2): Customizable polyphony across several groups, with
    features similar to SINGLE MODE. 
    Channel corresponds to group, rather than sample part.
    */
    kMode = 2
    kGroupAmount = 3

    kDecay   = 127
    kRelease = 13

    kBendRange = 0.5 ;0-1
    kMaxBend   = 64+round(63*kBendRange)
    kMinBend   = 64-round(64*kBendRange)

    printf "Groups Enabled: %d | Mode Selected: %d\n", 1, kGroupAmount, kMode
    printf "Pitchbend Range: %d-%d\n", 1, kMinBend, kMaxBend

    kStatus, kChan, kData1, kData2 midiin

    ;Uncomment and change to whatever Channel you want to send to.
    ;Useful if your MIDI equipment only sends to one channel with no option to change.
    ;kChan = 2 

    ;MIDI THRU: Output MIDI as is.
    if (kMode == 0) then
        midiout kStatus, kChan, kData1, kData2

    endif
    
    ;SINGLE MODE: Monophonic per sample part with chromatic pitch, gate and velocity.
    if (kMode == 1) then
        if (kStatus == $NOTE_ON) then 
            ;Turn MIDI NN into chromatic pitch
            midiout $CONTROL, kChan, $VOLCA_CHROMATIC, kData1

            ;Turn velocity into playback level and hicut
            midiout $CONTROL, kChan, $VOLCA_LEVEL, kData2
            ;midiout $CONTROL, kChan, $VOLCA_HICUT, kData2

            ;NOTE ON to trigger sample playback
            midiout $NOTE_ON, kChan, kData1, kData2
            midiout $CONTROL, kChan, $VOLCA_DECAY, kDecay

            ;Store the last note input to make playing and note release feel more natural.
            kLastNote[kChan-1] = kData1

            printsk "Channel %d | NOTE ON %s with velocity %d\n", kChan, mton(kData1), kData2

        elseif (kStatus == $POLY_AFTER) then
            ;Turn polyphonic aftertouch into playback level and hicut
            midiout $CONTROL, kChan, $VOLCA_LEVEL, kData2
            midiout $CONTROL, kChan, $VOLCA_HICUT, kData2

        elseif (kStatus == $CHAN_AFTER) then
            ;Turn channel (monophonic) aftertouch into playback level and hicut
            midiout $CONTROL, kChan, $VOLCA_LEVEL, kData1
            midiout $CONTROL, kChan, $VOLCA_HICUT, kData1

        elseif (kStatus == $NOTE_OFF && kLastNote[kChan-1] == kData1) then
            ;NOTE OFF to end sample playback
            midiout $CONTROL, kChan, $VOLCA_DECAY, kRelease

            ;Send NOTE OFF to avoid issues // volca sample doesn't respond to these
            midiout $NOTE_OFF, kChan, kData1, kData2 

            printsk "Channel %d | NOTE OFF %s with velocity %d\n", kChan, mton(kData1), kData2

        elseif (kStatus == $CONTROL && kData1 == 1) then
            ;Modwheel to hicut filter
            midiout $CONTROL, kChan, $VOLCA_HICUT, kData2

        elseif (kStatus == $PITCHBEND) then
            ;Pitchbend to Pitch EG
            kBend limit kData2, kMinBend, kMaxBend
            midiout $CONTROL, kChan, $VOLCA_PITCH, kBend

        endif

    endif

    ;POLYPHONIC MODE: Customizable polyphony per group, supporting chromatic pitch, gate and velocity
    if (kMode == 2) then
        if (kStatus == $NOTE_ON) then

            ;Check each enabled group.
            kIndex = 0
            until (kIndex == kGroupAmount) do

                ;Check if MIDI Tx and MIDI Rx matches for this group.
                if (kChan == kGroup[0][kIndex]) then
                    printf "MIDI Rx %d recognized by Group %d\n", kChan, kChan, kIndex+1

                    ;Calculate channel offset for this group.
                    kIndex2 = 0
                    kOffset = 0
                    while (kIndex2 < kIndex) do
                        kOffset += kGroup[1][kIndex2]
                        ;printf "Col %d: %d\n", kIndex2+1, kIndex2, kGroup[1][kIndex2]
                        ;printf "Offset: %d\n", kOffset, kOffset
                        kIndex2 += 1
                    od

                    ;Check if the MIDI Tx exceeds the polyphony limit.
                    if (kOffset+kPolyCycle[kIndex] > kOffset+kGroup[1][kIndex]) then
                        kPolyCycle[kIndex] = 1
                    endif
                    
                    ;Turn MIDI NN into chromatic pitch
                    midiout $CONTROL, kOffset+kPolyCycle[kIndex], $VOLCA_CHROMATIC, kData1

                    ;Turn velocity into playback level and hicut
                    midiout $CONTROL, kOffset+kPolyCycle[kIndex], $VOLCA_LEVEL, kData2
                    ;midiout $CONTROL, kOffset+kPolyCycle[kIndex], $VOLCA_HICUT, kData2

                    ;NOTE ON to trigger sample playback
                    midiout $NOTE_ON, kOffset+kPolyCycle[kIndex], kData1, kData2
                    midiout $CONTROL, kOffset+kPolyCycle[kIndex], $VOLCA_DECAY, kDecay

                    ;Store the last note input to make playing and note release feel more natural.
                    kNoteCh[0][kOffset+kPolyCycle[kIndex]-1] = kChan
                    kNoteCh[1][kOffset+kPolyCycle[kIndex]-1] = kData1

                    printsk "Channel %d -> %d | NOTE ON %d with velocity %d ", kChan, kOffset+kPolyCycle[kIndex], kData1, kData2
                    printsk "(Offset %d + Polyphony %d = Channel %d)\n", kOffset, kGroup[1][kIndex], kOffset+kPolyCycle[kIndex]

                    kPolyCycle[kIndex] = kPolyCycle[kIndex]+1

                endif

                kIndex += 1
            od
        elseif (kStatus == $POLY_AFTER) then
            kIndex = 0
            until (kIndex == 10) do
                if (kChan == kNoteCh[0][kIndex] && kData1 == kNoteCh[1][kIndex]) then

                    ;Turn polyphonic aftertouch into playback level and hicut
                    midiout $CONTROL, kIndex+1, $VOLCA_LEVEL, kData2
                    midiout $CONTROL, kIndex+1, $VOLCA_HICUT, kData2
                endif
                
                kIndex += 1
            od

        elseif (kStatus == $CHAN_AFTER) then
            kIndex = 0
            until (kIndex == kGroupAmount) do

                ;Check if MIDI Tx and MIDI Rx matches for this group.
                if (kChan == kGroup[0][kIndex]) then

                    ;Calculate channel offset for this group.
                    kIndex2 = 0
                    kOffset = 0
                    while (kIndex2 < kIndex) do
                        kOffset += kGroup[1][kIndex2]
                        ;printf "Col %d: %d\n", kIndex2+1, kIndex2, kGroup[1][kIndex2]
                        ;printf "Offset: %d\n", kOffset, kOffset
                        kIndex2 += 1
                    od

                    kIndex3 = 0
                    ;Repeat adjustments for every channel used in the group.
                    until (kIndex3 == kOffset+kGroup[1][kIndex]) do

                        ;Turn velocity into playback level and hicut
                        midiout $CONTROL, kOffset+kIndex3+1, $VOLCA_LEVEL, kData1
                        midiout $CONTROL, kOffset+kIndex3+1, $VOLCA_HICUT, kData1

                        kIndex3 += 1
                    od

                endif

                kIndex += 1
            od

        elseif (kStatus == $NOTE_OFF) then

            ;Match combination with all the stored Tx messages
            kIndex = 0 
            until (kIndex == 10) do
                if (kChan == kNoteCh[0][kIndex] && kData1 == kNoteCh[1][kIndex]) then
                    ;NOTE OFF to end sample playback
                    midiout $CONTROL, kIndex+1, $VOLCA_DECAY, kRelease

                    ;Send NOTE OFF to avoid issues // volca sample doesn't respond to these
                    midiout $NOTE_OFF, kIndex+1, kData1, kData2

                    printsk "Channel %d -> %d | NOTE OFF %d with velocity %d\n", kChan, kIndex+1, kData1, kData2

                    ;Empty the current table column to avoid collisions
                    kNoteCh[0][kIndex] = 0
                    kNoteCh[1][kIndex] = 0
                endif
                
                kIndex += 1
                ;printarray kPolyCycle, 1, "%d"
            od 
        elseif (kStatus == $PITCHBEND) then
            kIndex = 0
            until (kIndex == kGroupAmount) do

                ;Check if MIDI Tx and MIDI Rx matches for this group.
                if (kChan == kGroup[0][kIndex]) then

                    ;Calculate channel offset for this group.
                    kIndex2 = 0
                    kOffset = 0
                    while (kIndex2 < kIndex) do
                        kOffset += kGroup[1][kIndex2]
                        ;printf "Col %d: %d\n", kIndex2+1, kIndex2, kGroup[1][kIndex2]
                        ;printf "Offset: %d\n", kOffset, kOffset
                        kIndex2 += 1
                    od

                    kIndex3 = 0
                    ;Repeat adjustments for every channel used in the group.
                    until (kIndex3 == kOffset+kGroup[1][kIndex]) do

                        ;Pitchbend to Pitch EG
                        kBend limit kData2, kMinBend, kMaxBend
                        midiout $CONTROL, kOffset+kIndex3+1, $VOLCA_PITCH, kBend

                        kIndex3 += 1
                    od

                endif

                kIndex += 1
            od
        elseif (kStatus == $CONTROL && kData1 == 1) then
            kIndex = 0
            until (kIndex == kGroupAmount) do

                ;Check if MIDI Tx and MIDI Rx matches for this group.
                if (kChan == kGroup[0][kIndex]) then

                    ;Calculate channel offset for this group.
                    kIndex2 = 0
                    kOffset = 0
                    while (kIndex2 < kIndex) do
                        kOffset += kGroup[1][kIndex2]
                        ;printf "Col %d: %d\n", kIndex2+1, kIndex2, kGroup[1][kIndex2]
                        ;printf "Offset: %d\n", kOffset, kOffset
                        kIndex2 += 1
                    od

                    kIndex3 = 0
                    ;Repeat adjustments for every channel used in the group.
                    until (kIndex3 == kOffset+kGroup[1][kIndex]) do

                        ;Pitchbend to Pitch EG
                        midiout $CONTROL, kOffset+kIndex3+1, $VOLCA_HICUT, kData2

                        kIndex3 += 1
                    od

                endif

                kIndex += 1
            od
        endif
    endif
endin

</CsInstruments>

<CsScore>
</CsScore>

</CsoundSynthesizer>