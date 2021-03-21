import pytest

from pyebur128 import (
    ChannelType, MeasurementMode, R128State, get_loudness_range
)
import soundfile as sf


def get_single_loudness_range(filename):
    '''Open the WAV file and get the loudness range.'''
    with sf.SoundFile(filename) as wav:
        state = R128State(wav.channels,
                          wav.samplerate,
                          MeasurementMode.ModeLRA)

        if wav.channels == 5:
            state.set_channel(0, ChannelType.Left)
            state.set_channel(1, ChannelType.Right)
            state.set_channel(2, ChannelType.Center)
            state.set_channel(3, ChannelType.LeftSurround)
            state.set_channel(4, ChannelType.RightSuround)

        for sample in wav.read():
            state.add_frames(sample, 1)

    loudness = get_loudness_range(state)
    del state

    return loudness


def test_loudness_range(r128_test_data):
    '''Test for the loudness range value of a single file.

    NOTE: the tests have a second unused value of the exact expected value. We
    are choosing to ignore this for now since it's overkill for most needs.
    HOWEVER--passing the tests does not mean that the library is 100% EBU R 128
    compliant either!
    '''

    expected = [
        ('seq-3342-1-16bit.wav', 10.0, 1.0001105488329134e+01),
        ('seq-3342-2-16bit.wav', 5.0, 4.9993734051522178e+00),
        ('seq-3342-3-16bit.wav', 20.0, 1.9995064067783115e+01),
        ('seq-3342-4-16bit.wav', 15.0, 1.4999273937723455e+01),
        ('seq-3341-7_seq-3342-5-24bit.wav', 5.0, 4.9747585878473721e+00),
        ('seq-3341-2011-8_seq-3342-6-24bit-v02.wav', 15.0, 1.4993650849123316e+01), # noqa
    ]

    tolerance = 1
    status_msg = '==== \'{}\': want {} \u00b1 {} ---> '

    print('\n')
    for test in expected:
        print(status_msg.format(test[0], test[1], tolerance), end='')
        result = get_single_loudness_range(r128_test_data / test[0])
        print('got {} '.format(round(result, 1)), end='')
        assert (round(result, 1) <= test[1] + tolerance and
                round(result, 1) >= test[1] - tolerance)
        print('---> PASSED!')
