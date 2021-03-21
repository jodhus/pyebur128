import pytest

from pyebur128 import (
    ChannelType, MeasurementMode, R128State,
    get_loudness_global, get_loudness_global_multiple
)
import soundfile as sf


def get_single_loudness(filename):
    '''Open the WAV file and get the global loudness.'''
    with sf.SoundFile(filename) as wav:
        state = R128State(wav.channels, wav.samplerate, MeasurementMode.ModeI)

        if wav.channels == 5:
            state.set_channel(0, ChannelType.Left)
            state.set_channel(1, ChannelType.Right)
            state.set_channel(2, ChannelType.Center)
            state.set_channel(3, ChannelType.LeftSurround)
            state.set_channel(4, ChannelType.RightSuround)

        for sample in wav.read():
            state.add_frames(sample, 1)

    loudness = get_loudness_global(state)
    return state, loudness


def test_loudness_global_single(r128_test_data, r128_states):
    '''Test for the global loudness value of a single file.

    NOTE: the tests have a second unused value of the exact expected value. We
    are choosing to ignore this for now since it's overkill for most needs.
    HOWEVER--passing the tests does not mean that the library is 100% EBU R 128
    compliant either!
    '''

    expected = [
        ('seq-3341-1-16bit.wav', -23.0, -2.2953556442089987e+01),
        ('seq-3341-2-16bit.wav', -33.0, -3.2959860397340044e+01),
        ('seq-3341-3-16bit-v02.wav', -23.0, -2.2995899818255047e+01),
        ('seq-3341-4-16bit-v02.wav', -23.0, -2.3035918615414182e+01),
        ('seq-3341-5-16bit-v02.wav', -23.0, -2.2949997446096436e+01),
        ('seq-3341-6-5channels-16bit.wav', -23.0, -2.3017157781104373e+01),
        ('seq-3341-6-6channels-WAVEEX-16bit.wav', -23.0, -2.3017157781104373e+01), # noqa
        ('seq-3341-7_seq-3342-5-24bit.wav', -23.0, -2.2980242495081757e+01),
        ('seq-3341-2011-8_seq-3342-6-24bit-v02.wav', -23.0, -2.3009077718930545e+01), # noqa
    ]

    tolerance = 0.1
    status_msg = '==== \'{}\': want {} \u00b1 {} ---> '

    print('\n')
    for test in expected:
        print(status_msg.format(test[0], test[1], tolerance), end='')
        result = get_single_loudness(r128_test_data / test[0])
        r128_states[test[0]] = result[0]
        print('got {} '.format(round(result[1], 1)), end='')
        assert (round(result[1], 1) <= test[1] + tolerance and
                round(result[1], 1) >= test[1] - tolerance)
        print('---> PASSED!')


def test_loudness_global_multiple(r128_states):
    '''Test for the global loudness value across multiple files.'''
    states = list(r128_states.values())
    expected = -23.18758
    tolerance = 0.05

    print('\n==== want {} \u00b1 {} ---> '.format(expected, tolerance), end='')
    result = get_loudness_global_multiple(states)
    print('got {} '.format(round(result, 5)), end='')
    assert (round(result, 5) >= expected - tolerance and
            round(result, 5) <= expected + tolerance)
    print('---> PASSED!')

    r128_states = []
