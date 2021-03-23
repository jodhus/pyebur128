import enum

cimport cython
from libc.stdlib cimport malloc, free


class ChannelType(enum.IntEnum):
    '''Use these values when setting the channel map with
    R128State.set_channel(). See definitions in ITU R-REC-BS 1770-4.

    Note:
        The ITU-R BS.1770-4 does not include the LFE channel in any of its
        algorithms. For this channel, use the `UNUSED` attribute.
    '''
    UNUSED = 0
    LEFT = 1
    M_PLUS_030 = 1      # ITU M+030
    RIGHT = 2
    M_MINUS_030 = 2     # ITU M-030
    CENTER = 3
    M_PLUS_000 = 3      # ITU M+000
    LEFT_SURROUND = 4
    M_PLUS_110 = 4      # ITU M+110
    RIGHT_SUROUND = 5
    M_MINUS_110 = 5     # ITU M-110
    DUAL_MONO = 6       # A channel that's counted twice
    M_PLUS_SC = 7       # ITU M+SC
    M_MINUS_SC = 8      # ITU M-SC
    M_PLUS_060 = 9      # ITU M+060
    M_MINUS_060 = 10    # ITU M-060
    M_PLUS_090 = 11     # ITU M+090
    M_MINUS_090 = 12    # ITU M-090
    M_PLUS_135 = 13     # ITU M+135
    M_MINUS_135 = 14    # ITU M+135
    M_PLUS_180 = 15     # ITU M+180
    U_PLUS_000 = 16     # ITU U+000
    U_PLUS_030 = 17     # ITU U+030
    U_MINUS_030 = 18    # ITU U-030
    U_PLUS_045 = 19     # ITU U+045
    U_MINUS_045 = 20    # ITU U-045
    U_PLUS_090 = 21     # ITU U+090
    U_MINUS_090 = 22    # ITU U-090
    U_PLUS_110 = 23     # ITU U+110
    U_MINUS_110 = 24    # ITU U-110
    U_PLUS_135 = 25     # ITU U+135
    U_MINUS_135 = 26    # ITU U-135
    U_PLUS_180 = 27     # ITU U+180
    T_PLUS_000 = 28     # ITU T+000
    B_PLUS_000 = 29     # ITU B+000
    B_PLUS_045 = 30     # ITU B+045
    B_MINUS_045 = 31    # ITU B-045


class ErrorCode(enum.IntEnum):
    '''Error codes returned by libebur128's functions.'''
    SUCCESS = 0
    OUT_OF_MEMORY = 1
    INVALID_MODE = 2
    INVALID_CHANNEL_INDEX = 3
    VALUE_DID_NOT_CHANGE = 4


class MeasurementMode(enum.IntFlag):
    '''Various modes of measurement which can be used. These can be bitwise
    OR'd together to allow a combination of modes.
    '''
    # Can call get_loudness_momentary.
    MODE_M = (1 << 0)

    # Can call get_loudness_shortterm and get_loudness_momentary.
    MODE_S = (1 << 1) | MODE_M

    # Can call get_loudness_global, get_loudness_global_multiple,
    # get_relative_threshold, and get_loudness_momentary.
    MODE_I = (1 << 2) | MODE_M

    # Can call get_loudness_range, get_loudness_shortterm, and
    # get_loudness_momentary.
    MODE_LRA = (1 << 3) | MODE_S

    # Can call get_sample_peak and get_loudness_momentary.
    MODE_SAMPLE_PEAK = (1 << 4) | MODE_M

    # Can call get_true_peak, get_sample_peak, and get_loudness_momentary.
    MODE_TRUE_PEAK = (1 << 5) | MODE_SAMPLE_PEAK | MODE_M

    # Uses histogram algorithm to calculate loudness.
    MODE_HISTOGRAM = (1 << 6)


ctypedef fused const_frames_array:
    const short[::1]
    const int[::1]
    const float[::1]
    const double[::1]


cdef class R128State:
    '''This is a class representation of an EBU R128 Loudness Measurement
    State.
    '''

    # Contains information about the state of a loudness measurement.
    # You should not need to modify this struct directly.
    cdef ebur128_state *_state

    def __cinit__(self,
                  unsigned int channels,
                  unsigned long samplerate,
                  int mode):
        '''Constructor'''
        self._state = ebur128_init(channels, samplerate, mode)
        if self._state == NULL:
            raise MemoryError('Out of memory.')

    def __dealloc__(self):
        '''Deconstructor'''
        if self._state != NULL:
            ebur128_destroy(&self._state)

    # For autodoc purposes only.
    def __init__(self,
                 unsigned int channels,
                 unsigned long samplerate,
                 int mode):
        '''Initialize library state.

        Args:
            channels (int): The number of audio channels used in the
                measurement.
            samplerate (int): The samplerate in samples per second (or Hz).
            mode (:class:`MeasurementMode` or int): A value from the
                :class:`MeasurementMode` enum. Try to use the lowest possible
                modes that suit your needs as performance will be better.

        Raises:
            MemoryError: If the underlying C-struct cannot be allocated in
                memory.
        '''

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
        ''' A value from the :class:`MeasurementMode` enum. Try to use the
        lowest possible modes that suit your needs, as performance will be
        better.
        '''
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

        Args:
            channel_number (int): The zero-based channel index.
            channel_type (:class:`ChannelType` or int): The channel type.

        Raises:
            IndexError: If specified channel index is out of bounds.
        '''
        cdef int result
        result = ebur128_set_channel(self._state,
                                     channel_number,
                                     channel_type)
        if result == ErrorCode.INVALID_CHANNEL_INDEX:
            raise IndexError('Channel index is out of bounds.')

    def change_parameters(self,
                          unsigned int channels,
                          unsigned long samplerate):
        '''Changes the number of audio channels and/or the samplerate of the
        measurement state.

        Note:
            The channel map will be reset when setting a different number of
            channels. The current unfinished block will be lost.

        Args:
            channels (int): New number of audio channels.
            samplerate (int): The new samplerate in samples per second (or Hz).

        Raises:
            MemoryError: If not enough memory could be allocated for the new
                values.
            ValueError: If both new values are the same as the currently stored
                values.
        '''
        cdef int result
        result = ebur128_change_parameters(self._state,
                                           channels,
                                           samplerate)
        if result == ErrorCode.OUT_OF_MEMORY:
            raise MemoryError('Out of memory.')
        elif result == ErrorCode.VALUE_DID_NOT_CHANGE:
            raise ValueError('Channel numbers & sample rate have not changed.')

    def set_max_window(self, unsigned long window):
        '''Set the maximum duration that will be used for
        :func:`get_loudness_window`.

        Note:
            This will destroy the current content of the audio buffer in the
            measurement state.

        Args:
            window (int): The duration of the window in milliseconds (ms).

        Raises:
            MemoryError: If not enough memory could be allocated for the new
                value.
            ValueError: If the new window value is the same as the currently
                stored window value.
        '''
        cdef int result
        result = ebur128_set_max_window(self._state, window)
        if result == ErrorCode.OUT_OF_MEMORY:
            raise MemoryError('Out of memory.')
        elif result == ErrorCode.VALUE_DID_NOT_CHANGE:
            raise ValueError('Maximum window duration has not changed.')

    def set_max_history(self, unsigned long history):
        '''Set the maximum history that will be stored for loudness integration.
        More history provides more accurate results, but requires more
        resources.

        Applies to :func:`get_loudness_range` and :func:`get_loudness_global`
        when ``MODE_HISTOGRAM`` is not set from :class:`MeasurementMode`.

        Default is ULONG_MAX (approximately 50 days).
        Minimum is 3000ms for ``MODE_LRA`` and 400ms for ``MODE_M``.

        Args:
            history (int): The duration of history in milliseconds (ms).

        Raises:
            MemoryError: If not enough memory could be allocated for the new
                value.
            ValueError: If the new history value is the same as the currently
                stored history value.
        '''
        cdef int result
        result = ebur128_set_max_history(self._state, history)
        if result == ErrorCode.VALUE_DID_NOT_CHANGE:
            raise ValueError('Maximum history duration has not changed.')

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def add_frames(self, const_frames_array source, size_t frames):
        '''Add audio frames to be processed.

        Note:
            The ``source`` argument can be any one-dimensional array that is
            compliant with Python's new buffer protocol (PEP-3118). It must
            contain values of all `short`, `int`, `float`, or `double`.

        Args:
            source (see Note): An array of source frames. Channels must be
                interleaved.
            frames (int): The number of frames. (NOT the number of samples!)

        Raises:
            TypeError: If the source array: 1) is not one dimensional, 2) does
                not use Python's new buffer protocol, or 3) does not contain
                all short, int, float, or double values.
            MemoryError: If not enough memory could be allocated for the new
                frames.
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
        else:
            msg = (
                'Source array must be one-dimensional, use the new buffer '
                'protocol, and value type must be all short, int, float, or '
                'double.'
            )
            raise TypeError(msg)

        if result == ErrorCode.OUT_OF_MEMORY:
            raise MemoryError('Out of memory.')


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_global(R128State state):
    '''Get the global integrated loudness in LUFS.

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.

    Raises:
        ValueError: If ``MODE_I`` has not been set from
            :class:`MeasurementMode`.

    Returns:
        float: The integrated loudness in LUFS.
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_global(state._state, &lufs)
    if result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_I has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_global_multiple(list states):
    '''Get the global integrated loudness in LUFS across multiple instances.

    Args:
        states (list of :class:`R128State`): A list of :class:`R128State`
            instances.

    Raises:
        MemoryError: If not enough memory could be allocated for the conversion
            of a Python list to a C array.
        ValueError: If ``MODE_I`` has not been set from
            :class:`MeasurementMode`.

    Returns:
        float: The integrated loudness of all states in LUFS.
    '''
    cdef double lufs
    cdef int result
    cdef size_t i, num
    cdef ebur128_state **state_ptrs

    num = len(states)
    state_ptrs = <ebur128_state**>malloc(sizeof(ebur128_state*) * num)
    if state_ptrs == NULL:
        raise MemoryError('Unable to allocate array of states.')

    for i in range(num):
        state_ptrs[i] = (<R128State?>states[i])._state

    result = ebur128_loudness_global_multiple(state_ptrs, num, &lufs)
    free(state_ptrs)
    if result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_I has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_momentary(R128State state):
    '''Get the momentary loudness (last 400ms) in LUFS.

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.

    Returns:
        float: The momentary loudness in LUFS.
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_momentary(state._state, &lufs)
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_shortterm(R128State state):
    '''Get the short-term loudness (last 3s) in LUFS.

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.

    Raises:
        ValueError: If ``MODE_S`` has not been set from
            :class:`MeasurementMode`.

    Returns:
        float: The short-term loudness in LUFS.
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_shortterm(state._state, &lufs)
    if result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_S has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_window(R128State state, unsigned long window):
    '''Get the loudness of the specified window in LUFS.

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.
        window (int): The window size in milliseconds (ms).

    Raises:
        ValueError: If the new window size is larger than the current window
            size stored in state.

    Returns:
        float: The loudness in LUFS.
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_window(state._state, window, &lufs)
    if result == ErrorCode.INVALID_MODE:
        msg = (
            'Requested window is larger than the current '
            'window in the provided state.'
        )
        raise ValueError(msg)
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_range(R128State state):
    '''Get loudness range (LRA) of audio in LU.

    Calculates the loudness range according to EBU 3342.

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.

    Raises:
        MemoryError: If not enough memory could be allocated for the
            measurement.
        ValueError: If ``MODE_LRA`` has not been set.

    Returns:
        float: The loudness range (LRA) in LU.
    '''
    cdef double lufs
    cdef int result
    result = ebur128_loudness_range(state._state, &lufs)
    if result == ErrorCode.OUT_OF_MEMORY:
        raise MemoryError('Memory allocation error.')
    elif result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_LRA has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_loudness_range_multiple(list states):
    '''Get loudness range (LRA) of audio in LU across multiple instances.

    Calculates loudness range according to EBU 3342.

    Args:
        states (list of :class:`R128State`): A list of :class:`R128State`
            instances.

    Raises:
        MemoryError: If not enough memory could be allocated for the
            measurement or there was a problem with the Python list to C array
            conversion.
        ValueError: If ``MODE_LRA`` has not been set from
            :class:`MeasurementMode`.

    Returns:
        float: The loudness range (LRA) in LU.
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
    if result == ErrorCode.OUT_OF_MEMORY:
        raise MemoryError('Memory allocation error.')
    elif result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_LRA has not been set.')
    return lufs


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_sample_peak(R128State state, unsigned int channel_number):
    '''Get maximum sample peak from all frames that have been processed.

    The equation to convert to dBFS is: 20 * log10(result).

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.
        channel_number (int): The index of the channel to analyze.

    Raise:
        ValueError: If ``MODE_SAMPLE_PEAK`` has not been set or the channel
            index is out of bounds.

    Returns:
        float: The maximum sample peak (1.0 is 0 dBFS).
    '''
    cdef double max_peak
    cdef int result
    result = ebur128_sample_peak(state._state, channel_number, &max_peak)
    if result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_SAMPLE_PEAK has not been set.')
    elif result == ErrorCode.INVALID_CHANNEL_INDEX:
        raise ValueError('Invalid channel index provided.')
    return max_peak


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_previous_sample_peak(R128State state,
                                      unsigned int channel_number):
    '''Get maximum sample peak from the last call to
    :func:`R128State.add_frames`.

    The equation to convert to dBFS is: 20 * log10(result).

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.
        channel_number (int): The index of the channel to analyze.

    Raise:
        ValueError: If ``MODE_SAMPLE_PEAK`` has not been set or the channel
            index is out of bounds.

    Returns:
        float: The maximum sample peak (1.0 is 0 dBFS).
    '''
    cdef double max_peak
    cdef int result
    result = ebur128_prev_sample_peak(state._state, channel_number, &max_peak)
    if result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_SAMPLE_PEAK has not been set.')
    elif result == ErrorCode.INVALID_CHANNEL_INDEX:
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

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.
        channel_number (int): The index of the channel to analyze.

    Raise:
        ValueError: If ``MODE_TRUE_PEAK`` has not been set or the channel index
            is out of bounds.

    Returns:
        float: The maximum true peak (1.0 is 0 dBTP).
    '''
    cdef double max_peak
    cdef int result
    result = ebur128_true_peak(state._state, channel_number, &max_peak)
    if result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_TRUE_PEAK has not been set.')
    elif result == ErrorCode.INVALID_CHANNEL_INDEX:
        raise ValueError('Invalid channel index provided.')
    return max_peak


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_previous_true_peak(R128State state,
                                    unsigned int channel_number):
    '''Get maximum true peak from the last call to
    :func:`R128State.add_frames`.

    Uses an implementation defined algorithm to calculate the true peak. Do not
    try to compare resulting values across different versions of the library,
    as the algorithm may change.

    The current implementation uses a custom polyphase FIR interpolator to
    calculate true peak. Will oversample 4x for sample rates < 96000 Hz, 2x for
    sample rates < 192000 Hz and leave the signal unchanged for 192000 Hz.

    The equation to convert to dBTP is: 20 * log10(out)

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.
        channel_number (int): The index of the channel to analyze.

    Raise:
        ValueError: If ``MODE_TRUE_PEAK`` has not been set or the channel index
            is out of bounds.

    Returns:
        float: The maximum true peak (1.0 is 0 dBTP).
    '''
    cdef double max_peak
    cdef int result
    result = ebur128_prev_true_peak(state._state, channel_number, &max_peak)
    if result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_TRUE_PEAK has not been set.')
    elif result == ErrorCode.INVALID_CHANNEL_INDEX:
        raise ValueError('Invalid channel index provided.')
    return max_peak


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef double get_relative_threshold(R128State state):
    '''Get relative threshold in LUFS.

    Args:
        state (:class:`R128State`): An instance of the :class:`R128State`
            class.

    Raises:
        ValueError: If ``MODE_I`` has not been set.

    Returns:
        float: The relative threshold in LUFS.
    '''
    cdef double threshold
    cdef int result
    result = ebur128_relative_threshold(state._state, &threshold)
    if result == ErrorCode.INVALID_MODE:
        raise ValueError('MODE_I has not been set.')
    return threshold


cpdef get_libebur128_version():
    '''Gets the version number of the compiled libebur128.

    Returns:
        str: The major, minor, and patch numbers of the implemented libebur128
            version.
    '''
    cdef int major, minor, patch
    ebur128_get_version(&major, &minor, &patch)
    return '.'.join(map(str, (major, minor, patch)))
