import enum

cimport cython
from libc.stdlib cimport malloc, free


class ChannelType(enum.IntEnum):
    '''Use these values when setting the channel map with
    R128State.set_channel(). See definitions in ITU R-REC-BS 1770-4.
    '''
    Unused = 0        # unused channel (for example LFE channel)
    Left = 1
    Mplus030 = 1      # itu M+030
    Right = 2
    Mminus030 = 2     # itu M-030
    Center = 3
    Mplus000 = 3      # itu M+000
    LeftSurround = 4
    Mplus110 = 4      # itu M+110
    RightSuround = 5
    Mminus110 = 5     # itu M-110
    DualMono = 6      # a channel that is counted twice
    MplusSC = 7       # itu M+SC
    MminusSC = 8      # itu M-SC
    Mplus060 = 9      # itu M+060
    Mminus060 = 10    # itu M-060
    Mplus090 = 11     # itu M+090
    Mminus090 = 12    # itu M-090
    Mplus135 = 13     # itu M+135
    Mminus135 = 14    # itu M-135
    Mplus180 = 15     # itu M+180
    Uplus000 = 16     # itu U+000
    Uplus030 = 17     # itu U+030
    Uminus030 = 18    # itu U-030
    Uplus045 = 19     # itu U+045
    Uminus045 = 20    # itu U-030
    Uplus090 = 21     # itu U+090
    Uminus090 = 22    # itu U-090
    Uplus110 = 23     # itu U+110
    Uminus110 = 24    # itu U-110
    Uplus135 = 25     # itu U+135
    Uminus135 = 26    # itu U-135
    Uplus180 = 27     # itu U+180
    Tplus000 = 28     # itu T+000
    Bplus000 = 29     # itu B+000
    Bplus045 = 30     # itu B+045
    Bminus045 = 31    # itu B-045


class ErrorCode(enum.IntEnum):
    '''Error codes returned by libebur128 functions.'''
    Success = 0
    OutOfMemory = 1
    InvalidMode = 2
    InvalidChannelIndex = 3
    ValueDidNotChange = 4


class MeasurementMode(enum.IntFlag):
    '''Use these values bitwise OR'd when instancing an R128State class.
    Try to use the lowest possible modes that suit your needs, as performance
    will be better.
    '''
    # can call get_loudness_momentary
    ModeM = (1 << 0)
    # can call get_loudness_shortterm
    ModeS = (1 << 1) | ModeM
    # can call get_loudness_global_* and get_relative_threshold
    ModeI = (1 << 2) | ModeM
    # can call get_loudness_range
    ModeLRA = (1 << 3) | ModeS
    # can call get_sample_peak
    ModeSamplePeak = (1 << 4) | ModeM
    # can call get_true_peak
    ModeTruePeak = (1 << 5) | ModeM | ModeSamplePeak
    # uses histogram algorithm to calculate loudness
    ModeHistogram = (1 << 6)


ctypedef fused const_frames_array:
    const short[::1]
    const int[::1]
    const float[::1]
    const double[::1]


cdef class R128State:
    '''This is a class representation of an EBU R128 Loudness Measurement State.

    :param channels: The number of audio channels used in the measurement.
    :type channels: int
    :param samplerate: The samplerate in samples per second (or Hz).
    :type samplerate: int
    :param mode: A bitwise OR'd value from the :class:`Mode` enum. Try to use
        the lowest possible modes that suit your needs, as performance will be
        better.
    :type mode: int
    '''

    # Contains information about the state of a loudness measurement.
    # You should not need to modify this struct directly.
    cdef ebur128_state *_state

    def __cinit__(self,
                  unsigned int channels,
                  unsigned long samplerate,
                  int mode):
        '''Initialize library state.

        :raises MemoryError: If the underlying C-struct cannot be allocated in
            memory.
        '''
        self._state = ebur128_init(channels, samplerate, mode)
        if self._state == NULL:
            raise MemoryError('Out of memory.')

    def __dealloc__(self):
        '''Destroy library state.'''
        if self._state != NULL:
            ebur128_destroy(&self._state)

    def __repr__(self):
        '''A nicer way of explaining the object.'''
        obj = '<{0}: channels={1}, samplerate={2}, mode={3} at 0x{4:0{5}X}>'
        return obj.format(
            self.__class__.__name__,
            self.channels,
            self.samplerate,
            self.mode.__repr__(),
            id(self),
            16
        )

    property channels:
        '''The number of audio channels used in the measurement.'''
        def __get__(self):
            '''channels' getter'''
            return self._state.channels if self._state is not NULL else None
        def __set__(self, unsigned int c):
            '''channels' setter'''
            if self._state is not NULL:
                self.change_parameters(c, self._state.samplerate)

    property samplerate:
        '''The samplerate in samples per second (or Hz).'''
        def __get__(self):
            '''samplerate's getter'''
            return self._state.samplerate if self._state is not NULL else None
        def __set__(self, unsigned long s):
            '''samplerate's setter'''
            if self._state is not NULL:
                self.change_parameters(self._state.channels, s)

    property mode:
        ''' A bitwise OR'd value from the :class:`Mode` enum. Try to use
        the lowest possible modes that suit your needs, as performance will be
        better.'''
        def __get__(self):
            '''mode's getter'''
            if self._state is not NULL:
                return MeasurementMode(self._state.mode)
            else:
                return None
        def __set__(self, int m):
            '''mode's setter'''
            if self._state is not NULL:
                self._state.mode = m

    def set_channel(self, unsigned int channel_number, int channel_type):
        '''Sets an audio channel to a specific channel type as defined in the
        :class:`ChannelType` enum.

        :param channel_number: The zero-based channel index.
        :type channel_number: int
        :param channel_type: The channel type from :class:`ChannelType`.
        :type channel_type: int

        :raises IndexError: If specified channel index is out of bounds.
        '''
        cdef int result
        result = ebur128_set_channel(self._state,
                                     channel_number,
                                     channel_type)
        if result == ErrorCode.InvalidChannelIndex:
            raise IndexError('Channel index is out of bounds.')

    def change_parameters(self,
                          unsigned int channels,
                          unsigned long samplerate):
        '''Changes number of audio channels and/or the samplerate of the
        loudness measurement. Returns an integer error code.

        Note that the channel map will be reset when setting a different number
        of channels. The current unfinished block will be lost.

        :param channels: New number of audio channels.
        :type channels: int
        :param samplerate: The new samplerate in samples per second (or Hz).
        :type samplerate: int

        :raises MemoryError: If not enough memory could be allocated for the
            new values.
        :raises ValueError: If both new values are the same as the currently
            stored values.
        '''
        cdef int result
        result = ebur128_change_parameters(self._state,
                                           channels,
                                           samplerate)
        if result == ErrorCode.OutOfMemory:
            raise MemoryError('Out of memory.')
        elif result == ErrorCode.ValueDidNotChange:
            raise ValueError('Channel numbers & sample rate have not changed.')

    def set_max_window(self, unsigned long window):
        '''Set the maximum duration that will be used for
        :func:`~pyebur128.get_loudness_window`.

        Note that this destroys the current content of the audio buffer.

        :param window: The duration of the window in milliseconds (ms).
        :type window: int

        :raises MemoryError: If not enough memory could be allocated for the
            new value.
        :raises ValueError: If the new window value is the same as the
            currently stored window value.
        '''
        cdef int result
        result = ebur128_set_max_window(self._state, window)
        if result == ErrorCode.OutOfMemory:
            raise MemoryError('Out of memory.')
        elif result == ErrorCode.ValueDidNotChange:
            raise ValueError('Maximum window duration has not changed.')

    def set_max_history(self, unsigned long history):
        '''Set the maximum history that will be stored for loudness integration.
        More history provides more accurate results, but requires more
        resources.

        Applies to :func:`~pyebur128.get_loudness_range` and
        :func:`~pyebur128.get_loudness_global` when ``ModeHistogram`` is
        not set from :class:`pyebur128.MeasurementMode`.

        Default is ULONG_MAX (at least ~50 days).
        Minimum is 3000ms for ``ModeLRA`` and 400ms for ``ModeM``.

        :param history: The duration of history in milliseconds (ms).
        :type history: int

        :raises MemoryError: If not enough memory could be allocated for the
            new value.
        :raises ValueError: If the new history value is the same as the
            currently stored history value.
        '''
        cdef int result
        result = ebur128_set_max_history(self._state, history)
        if result == ErrorCode.ValueDidNotChange:
            raise ValueError('Maximum history duration has not changed.')

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def add_frames(self, const_frames_array source, size_t frames):
        '''Add frames to be processed.

        :param source: An array of source frames. Channels must be interleaved.
        :type source: New buffer protocol (PEP-3118) array of short, int, float,
            or double.
        :param frames: The number of frames. (Not the number of samples!)
        :type frames: int

        :raises MemoryError: If not enough memory could be allocated for the
            new frames.
        '''
        cdef int result

        if const_frames_array is short[::1]:
            result = ebur128_add_frames_short(self._state,
                                              &source[0],
                                              frames)
        elif const_frames_array is int[::1]:
            result = ebur128_add_frames_int(self._state,
                                            &source[0],
                                            frames)
        elif const_frames_array is float[::1]:
            result = ebur128_add_frames_float(self._state,
                                              &source[0],
                                              frames)
        elif const_frames_array is double[::1]:
            result = ebur128_add_frames_double(self._state,
                                               &source[0],
                                               frames)

        if result == ErrorCode.OutOfMemory:
            raise MemoryError('Out of memory.')


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_global(R128State state):
    '''Get the global integrated loudness in LUFS.

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State

    :raises ValueError: If Mode ``ModeI`` has not been set.

    :return: The integrated loudness in LUFS.
    :rtype: float
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_global(state._state, &lufs)
    if result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeI" has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_global_multiple(list states):
    '''Get the global integrated loudness in LUFS across multiple instances.

    :param state: A list of :class:`R128State` instances.
    :type state: list of R128State

    :raises MemoryError: If not enough memory could be allocated for the
        conversion of a Python list to a C array.
    :raises ValueError: If Mode ``ModeI`` has not been set.

    :return: The integrated loudness in LUFS.
    :rtype: float
    '''
    cdef double lufs
    cdef int result
    cdef size_t i, num
    cdef ebur128_state **state_ptrs

    num = len(states)
    state_ptrs = <ebur128_state**>malloc(sizeof(ebur128_state*) * num)
    if state_ptrs == NULL:
        raise MemoryError('Unable to allocate array of R128 states.')

    for i in range(num):
        state_ptrs[i] = (<R128State?>states[i])._state

    result = ebur128_loudness_global_multiple(state_ptrs, num, &lufs)
    free(state_ptrs)
    if result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeI" has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_momentary(R128State state):
    '''Get the momentary loudness (last 400ms) in LUFS.

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State

    :return: The momentary loudness in LUFS.
    :rtype: float
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_momentary(state._state, &lufs)
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_shortterm(R128State state):
    '''Get the short-term loudness (last 3s) in LUFS.

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State

    :raises ValueError: If Mode ``ModeS`` has not been set.

    :return: The short-term loudness in LUFS.
    :rtype: float
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_shortterm(state._state, &lufs)
    if result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeS" has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_window(R128State state, unsigned long window):
    '''Get loudness of the specified window in LUFS.

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State
    :param window: The window size in milliseconds (ms) to calculate loudness.
    :type window: int

    :raises ValueError: If the new window size is larger than the current
        window size stored in state.

    :return: The loudness in LUFS.
    :rtype: float
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_window(state._state, window, &lufs)
    if result == ErrorCode.InvalidMode:
        msg = (
            'Requested window larger than the current '
            'window in the provided state.'
        )
        raise ValueError(msg)
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_range(R128State state):
    '''Get loudness range (LRA) of audio in LU.

    Calculates loudness range according to EBU 3342.

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State

    :raises MemoryError: If not enough memory could be allocated for the
        measurement.
    :raises ValueError: If Mode ``ModeLRA`` has not been set.

    :return: The loudness range (LRA) in LU.
    :rtype: float
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_range(state._state, &lufs)
    if result == ErrorCode.OutOfMemory:
        raise MemoryError('Memory allocation error.')
    elif result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeLRA" has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_range_multiple(list states):
    '''Get loudness range (LRA) of audio in LU across multiple instances.

    Calculates loudness range according to EBU 3342.

    :param state: A list of :class:`R128State` instances.
    :type state: list of R128State

    :raises MemoryError: If not enough memory could be allocated for the
        measurement or there was a problem with the Python list to C array
        conversion.
    :raises ValueError: If Mode ``ModeLRA`` has not been set.

    :return: The loudness range (LRA) in LU.
    :rtype: float
    '''
    cdef double lufs
    cdef int result
    cdef size_t i, num
    cdef ebur128_state **state_ptrs

    num = len(states)
    state_ptrs = <ebur128_state**>malloc(sizeof(ebur128_state*) * num)
    if state_ptrs == NULL:
        raise MemoryError('Unable to allocate array of R128 states.')

    for i in range(num):
        state_ptrs[i] = (<R128State?>states[i])._state

    result = ebur128_loudness_range_multiple(state_ptrs, num, &lufs)
    free(state_ptrs)
    if result == ErrorCode.OutOfMemory:
        raise MemoryError('Memory allocation error.')
    elif result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeLRA" has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_sample_peak(R128State state, unsigned int channel_number):
    '''Get maximum sample peak from all frames that have been processed.

    The equation to convert to dBFS is: 20 * log10(result).

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State
    :param channel_number: The index of the channel to analyze.
    :type channel_number: int

    :raises ValueError: If Mode ``ModeSamplePeak`` has not been set or the
        channel index is out of bounds.

    :return: The maximum sample peak (1.0 is 0 dBFS).
    :rtype: float
    '''
    cdef double max_peak
    cdef int result
    result = ebur128_sample_peak(state._state, channel_number, &max_peak)
    if result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeSamplePeak" has not been set.')
    elif result == ErrorCode.InvalidChannelIndex:
        raise ValueError('Invalid channel index provided.')
    return max_peak


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_previous_sample_peak(R128State state,
                                      unsigned int channel_number):
    '''Get maximum sample peak from the last call to add_frames().

    The equation to convert to dBFS is: 20 * log10(result).

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State
    :param channel_number: The index of the channel to analyze.
    :type channel_number: int

    :raises ValueError: If Mode ``ModeSamplePeak`` has not been set or the
        channel index is out of bounds.

    :return: The maximum sample peak (1.0 is 0 dBFS).
    :rtype: float
    '''
    cdef double max_peak
    cdef int result
    result = ebur128_prev_sample_peak(state._state, channel_number, &max_peak)
    if result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeSamplePeak" has not been set.')
    elif result == ErrorCode.InvalidChannelIndex:
        raise ValueError('Invalid channel index provided.')
    return max_peak


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_true_peak(R128State state, unsigned int channel_number):
    '''Get maximum true peak from all frames that have been processed.

    Uses an implementation defined algorithm to calculate the true peak. Do not
    try to compare resulting values across different versions of the library,
    as the algorithm may change.

    The current implementation uses a custom polyphase FIR interpolator to
    calculate true peak. Will oversample 4x for sample rates < 96000 Hz, 2x for
    sample rates < 192000 Hz and leave the signal unchanged for 192000 Hz.

    The equation to convert to dBTP is: 20 * log10(out)

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State
    :param channel_number: The index of the channel to analyze.
    :type channel_number: int

    :raises ValueError: If Mode ``ModeTruePeak`` has not been set or the
        channel index is out of bounds.

    :return: The maximum true peak (1.0 is 0 dBTP).
    :rtype: float
    '''
    cdef double max_peak
    cdef int result
    result = ebur128_true_peak(state._state, channel_number, &max_peak)
    if result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeTruePeak" has not been set.')
    elif result == ErrorCode.InvalidChannelIndex:
        raise ValueError('Invalid channel index provided.')
    return max_peak


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_previous_true_peak(R128State state,
                                    unsigned int channel_number):
    '''Get maximum true peak from the last call to add_frames().

    Uses an implementation defined algorithm to calculate the true peak. Do not
    try to compare resulting values across different versions of the library,
    as the algorithm may change.

    The current implementation uses a custom polyphase FIR interpolator to
    calculate true peak. Will oversample 4x for sample rates < 96000 Hz, 2x for
    sample rates < 192000 Hz and leave the signal unchanged for 192000 Hz.

    The equation to convert to dBTP is: 20 * log10(out)

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State
    :param channel_number: The index of the channel to analyze.
    :type channel_number: int

    :raises ValueError: If Mode ``ModeTruePeak`` has not been set or the
        channel index is out of bounds.

    :return: The maximum true peak (1.0 is 0 dBTP).
    :rtype: float
    '''
    cdef double max_peak
    cdef int result
    result = ebur128_prev_true_peak(state._state, channel_number, &max_peak)
    if result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeTruePeak" has not been set.')
    elif result == ErrorCode.InvalidChannelIndex:
        raise ValueError('Invalid channel index provided.')
    return max_peak


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_relative_threshold(R128State state):
    '''Get relative threshold in LUFS.

    :param state: An instance of the :class:`R128State` class.
    :type state: R128State

    :raises ValueError: If Mode ``ModeI`` has not been set.

    :return: The relative threshold in LUFS.
    :rtype: float
    '''
    cdef double threshold
    cdef int result
    result = ebur128_relative_threshold(state._state, &threshold)
    if result == ErrorCode.InvalidMode:
        raise ValueError('Mode "ModeI" has not been set.')
    return threshold


cpdef get_libebur128_version():
    '''Gets the version number of the compiled libebur128.

    :return: The major, minor, and patch numbers of the implemented libebur128
        version.
    :rtype: tuple of int
    '''
    cdef int major, minor, patch
    ebur128_get_version(&major, &minor, &patch)
    return major, minor, patch
