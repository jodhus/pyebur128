import pytest

from pyebur128 import (
    ChannelType, MeasurementMode, R128State, get_loudness_shortterm
)
import soundfile as sf


def get_max_loudness_shortterm(filename):
    '''Open the WAV file and get the loudness in short-term (3s) chunks.'''
    with sf.SoundFile(filename) as wav:
        state = R128State(wav.channels,
                          wav.samplerate,
                          MeasurementMode.ModeS)

        if wav.channels == 5:
            state.set_channel(0, ChannelType.Left)
            state.set_channel(1, ChannelType.Right)
            state.set_channel(2, ChannelType.Center)
            state.set_channel(3, ChannelType.LeftSurround)
            state.set_channel(4, ChannelType.RightSuround)

        # 10 ms buffer / 10 Hz refresh rate.
        max_shortterm = float('-inf')
        total_frames_read = 0
        for block in wav.blocks(blocksize=int(wav.samplerate / 10)):
            frames_read = len(block)
            total_frames_read += frames_read

            for sample in block:
                state.add_frames(sample, 1)

            # Invalid results before the first 3 seconds.
            if total_frames_read >= 3 * wav.samplerate:
                shortterm = get_loudness_shortterm(state)
                max_shortterm = max(shortterm, max_shortterm)

    del state

    return max_shortterm


def test_max_loudness_shortterm(r128_test_data):
    '''Test for the loudness value of a single file in short-term (3s)
    chunks.
    '''

    expected = [
        ('seq-3341-10-1-24bit.wav', -23.0),
        ('seq-3341-10-2-24bit.wav', -23.0),
        ('seq-3341-10-3-24bit.wav', -23.0),
        ('seq-3341-10-4-24bit.wav', -23.0),
        ('seq-3341-10-5-24bit.wav', -23.0),
        ('seq-3341-10-6-24bit.wav', -23.0),
        ('seq-3341-10-7-24bit.wav', -23.0),
        ('seq-3341-10-8-24bit.wav', -23.0),
        ('seq-3341-10-9-24bit.wav', -23.0),
        ('seq-3341-10-10-24bit.wav', -23.0),
        ('seq-3341-10-11-24bit.wav', -23.0),
        ('seq-3341-10-12-24bit.wav', -23.0),
        ('seq-3341-10-13-24bit.wav', -23.0),
        ('seq-3341-10-14-24bit.wav', -23.0),
        ('seq-3341-10-15-24bit.wav', -23.0),
        ('seq-3341-10-16-24bit.wav', -23.0),
        ('seq-3341-10-17-24bit.wav', -23.0),
        ('seq-3341-10-18-24bit.wav', -23.0),
        ('seq-3341-10-19-24bit.wav', -23.0),
        ('seq-3341-10-20-24bit.wav', -23.0),
    ]

    tolerance = 0.1
    status_msg = '==== \'{}\': want {} \u00b1 {} ---> '

    print('\n')
    for test in expected:
        print(status_msg.format(test[0], test[1], tolerance), end='')
        result = get_max_loudness_shortterm(r128_test_data / test[0])
        print('got {} '.format(round(result, 1)), end='')
        assert (round(result, 1) <= test[1] + tolerance and
                round(result, 1) >= test[1] - tolerance)
        print('---> PASSED!')
