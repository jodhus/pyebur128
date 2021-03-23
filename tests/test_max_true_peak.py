from math import log10

import pytest

from pyebur128 import (
    ChannelType, MeasurementMode, R128State, get_true_peak
)
import soundfile as sf


def get_max_true_peak(filename):
    '''Open the WAV file and get the maximum true loudness peak.'''
    with sf.SoundFile(filename) as wav:
        state = R128State(wav.channels,
                          wav.samplerate,
                          MeasurementMode.MODE_TRUE_PEAK)

        if wav.channels == 5:
            state.set_channel(0, ChannelType.LEFT)
            state.set_channel(1, ChannelType.RIGHT)
            state.set_channel(2, ChannelType.CENTER)
            state.set_channel(3, ChannelType.LEFT_SURROUND)
            state.set_channel(4, ChannelType.RIGHT_SURROUND)

        for sample in wav.read():
            state.add_frames(sample, 1)

    max_true_peak = float('-inf')
    for channel in range(state.channels):
        true_peak = get_true_peak(state, channel)
        max_true_peak = max(true_peak, max_true_peak)
    del state

    return 20 * log10(max_true_peak)


def test_max_true_peak(r128_test_data):
    '''Test for the maximum true loudness peak value of a single file.'''

    expected = [
        ('seq-3341-15-24bit.wav.wav', -6.0),
        ('seq-3341-16-24bit.wav.wav', -6.0),
        ('seq-3341-17-24bit.wav.wav', -6.0),
        ('seq-3341-18-24bit.wav.wav', -6.0),
        ('seq-3341-19-24bit.wav.wav', 3.0),
        ('seq-3341-20-24bit.wav.wav', 0.0),
        ('seq-3341-21-24bit.wav.wav', 0.0),
        ('seq-3341-22-24bit.wav.wav', 0.0),
        ('seq-3341-23-24bit.wav.wav', 0.0),
    ]

    tolerance = 0.4
    status_msg = '==== \'{}\': want {} \u00b1 {} ---> '

    print('\n')
    for test in expected:
        print(status_msg.format(test[0], test[1], tolerance), end='')
        result = get_max_true_peak(r128_test_data / test[0])
        print('got {} '.format(round(result, 1)), end='')
        assert (round(result, 1) <= test[1] + tolerance and
                round(result, 1) >= test[1] - tolerance)
        print('---> PASSED!')
