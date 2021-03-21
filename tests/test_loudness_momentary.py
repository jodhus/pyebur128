import pytest

from pyebur128 import (
    ChannelType, MeasurementMode, R128State, get_loudness_momentary
)
import soundfile as sf


def get_max_loudness_momentary(filename):
    '''Open the WAV file and get the loudness in momentary (400ms) chunks.'''
    with sf.SoundFile(filename) as wav:
        state = R128State(wav.channels,
                          wav.samplerate,
                          MeasurementMode.ModeM)

        if wav.channels == 5:
            state.set_channel(0, ChannelType.Left)
            state.set_channel(1, ChannelType.Right)
            state.set_channel(2, ChannelType.Center)
            state.set_channel(3, ChannelType.LeftSurround)
            state.set_channel(4, ChannelType.RightSuround)

        # 10 ms buffer / 100 Hz refresh rate as 10 Hz refresh rate fails on
        # several tests.
        max_momentary = float('-inf')
        total_frames_read = 0
        for block in wav.blocks(blocksize=int(wav.samplerate / 100)):
            frames_read = len(block)
            total_frames_read += frames_read

            for sample in block:
                state.add_frames(sample, 1)

            # Invalid results before the first 400 ms.
            if total_frames_read >= 4 * wav.samplerate / 10:
                momentary = get_loudness_momentary(state)
                max_momentary = max(momentary, max_momentary)

    del state

    return max_momentary


def test_max_loudness_momentary(r128_test_data):
    '''Test for the loudness value of a single file in momentary (400ms)
    chunks.
    '''

    expected = [
        ('seq-3341-13-1-24bit.wav', -23.0),
        ('seq-3341-13-2-24bit.wav', -23.0),
        ('seq-3341-13-3-24bit.wav.wav', -23.0),
        ('seq-3341-13-4-24bit.wav.wav', -23.0),
        ('seq-3341-13-5-24bit.wav.wav', -23.0),
        ('seq-3341-13-6-24bit.wav.wav', -23.0),
        ('seq-3341-13-7-24bit.wav.wav', -23.0),
        ('seq-3341-13-8-24bit.wav.wav', -23.0),
        ('seq-3341-13-9-24bit.wav.wav', -23.0),
        ('seq-3341-13-10-24bit.wav.wav', -23.0),
        ('seq-3341-13-11-24bit.wav.wav', -23.0),
        ('seq-3341-13-12-24bit.wav.wav', -23.0),
        ('seq-3341-13-13-24bit.wav.wav', -23.0),
        ('seq-3341-13-14-24bit.wav.wav', -23.0),
        ('seq-3341-13-15-24bit.wav.wav', -23.0),
        ('seq-3341-13-16-24bit.wav.wav', -23.0),
        ('seq-3341-13-17-24bit.wav.wav', -23.0),
        ('seq-3341-13-18-24bit.wav.wav', -23.0),
        ('seq-3341-13-19-24bit.wav.wav', -23.0),
        ('seq-3341-13-20-24bit.wav.wav', -23.0),
    ]

    tolerance = 0.1
    status_msg = '==== \'{}\': want {} \u00b1 {} ---> '

    print('\n')
    for test in expected:
        print(status_msg.format(test[0], test[1], tolerance), end='')
        result = get_max_loudness_momentary(r128_test_data / test[0])
        print('got {} '.format(round(result, 1)), end='')
        assert (round(result, 1) <= test[1] + tolerance and
                round(result, 1) >= test[1] - tolerance)
        print('---> PASSED!')
