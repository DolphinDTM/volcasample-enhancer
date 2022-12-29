# MIDI Enhancer for volca sample 2 (using Csound)
This Csound code lets you use Csound as a MIDI intercepter in order to make the most out of your KORG volca sample 2.\
Currently it supports translating MIDI note numbers to chromatic pitch control, velocity to amp level, pitchbend to pitch EG, and modwheel (CC#01) to hicut. Pitchbend range can also be changed with a single variable.\
You can also set up several "groups" in order to set up several sampler instruments, each with customizable polyphony, responding to whatever MIDI channel you want it to.\
Note Off messages will cut the playback of the samples too, making it possible to use long sustained samples without worrying about overlapping tails. You can adjust the release decay if you want, or set it to max for one-shot sample playback.

**IMPORTANT: The current code has been made to work with volca sample 2 from 2020.\
It will not work as intended with the original volca sample.**

## Preqrequisites:
- Csound version 6.16 or higher
- A MIDI device (i.e. keyboard, pads, etc. to control your volca sample with)
- volca sample set to multi channel mode

## How to use:
1. Download ``sampleEnhance.csd``. Place it anywhere you feel like.
2. Run the code in your preferred terminal using: \
`csound "$FILE_LOCATION/sampleEnhance.csd"` OR \
`csound sampleEnhance.csd` directly from the folder where the Csound document is located.
3. You may receive a realtime MIDI error. In the `<CsOptions>...</CsOptions>` section of the code, make the necessary edits for your setup.\
`-Ma` means "listen to all MIDI devices." You can change the `a` to a MIDI input device name or number.\
For output devices, the same is true for `-Q2` where the `2` means output MIDI to device number 2.\
Csound will print a list of available MIDI devices when launching. Use those numbers or device names.

## Things I plan on implementing:
- Better organized variables for parameter controls and easier param routing
- The ability to change the loaded sample for each part in a group all at once (possible using CC#03 as MSB and CC#35 as LSB)
- Sustain pedal support
- Graphical User Interface (using Cabbage, likely)
- Add a volca sample (old gen) mode?

## Known bugs
- When changing many parameters at once, you may experience some stutters or input lag in the MIDI output. This is likely due to Csound's control rate (k-rate) being throttled by some default settings.
