cdef extern from "../lib/ebur128/ebur128.h":

    ctypedef enum Channel "channel":
        EBUR128_UNUSED = 0
        EBUR128_LEFT = 1
        EBUR128_Mp030 = 1
        EBUR128_RIGHT = 2
        EBUR128_Mm030 = 2
        EBUR128_CENTER = 3
        EBUR128_Mp000 = 3
        EBUR128_LEFT_SURROUND = 4
        EBUR128_Mp110 = 4
        EBUR128_RIGHT_SURROUND = 5
        EBUR128_Mm110 = 5
        EBUR128_DUAL_MONO
        EBUR128_MpSC
        EBUR128_MmSC
        EBUR128_Mp060
        EBUR128_Mm060
        EBUR128_Mp090
        EBUR128_Mm090
        EBUR128_Mp135
        EBUR128_Mm135
        EBUR128_Mp180
        EBUR128_Up000
        EBUR128_Up030
        EBUR128_Um030
        EBUR128_Up045
        EBUR128_Um045
        EBUR128_Up090
        EBUR128_Um090
        EBUR128_Up110
        EBUR128_Um110
        EBUR128_Up135
        EBUR128_Um135
        EBUR128_Up180
        EBUR128_Tp000
        EBUR128_Bp000
        EBUR128_Bp045
        EBUR128_Bm045

    ctypedef enum Error "error":
        EBUR128_SUCCESS
        EBUR128_ERROR_NOMEM
        EBUR128_ERROR_INVALID_MODE
        EBUR128_ERROR_INVALID_CHANNEL_INDEX
        EBUR128_ERROR_NO_CHANGE

    ctypedef enum Mode "mode":
        EBUR128_MODE_M = (1 << 0)
        EBUR128_MODE_S = (1 << 1) | EBUR128_MODE_M
        EBUR128_MODE_I = (1 << 2) | EBUR128_MODE_M
        EBUR128_MODE_LRA = (1 << 3) | EBUR128_MODE_S
        EBUR128_MODE_SAMPLE_PEAK = (1 << 4) | EBUR128_MODE_M
        EBUR128_MODE_TRUE_PEAK = (
            (1 << 5) | EBUR128_MODE_M | EBUR128_MODE_SAMPLE_PEAK
        )
        EBUR128_MODE_HISTOGRAM = (1 << 6)

    # forward declaration of ebur128_state_internal
    struct ebur128_state_internal

    # Contains information about the state of a loudness measurement.
    # You should not need to modify this struct directly.
    ctypedef struct ebur128_state:
        int mode                   # The current mode.
        unsigned int channels      # The number of channels.
        unsigned long samplerate   # The sample rate.
        ebur128_state_internal* d  # Internal state.

    void ebur128_get_version(int *major, int *minor, int *patch)

    ebur128_state *ebur128_init(unsigned int channels,
                                unsigned long samplerate,
                                int mode)

    void ebur128_destroy(ebur128_state **state)

    int ebur128_set_channel(ebur128_state *state,
                            unsigned int channel_number,
                            int value)

    int ebur128_change_parameters(ebur128_state *state,
                                  unsigned int channels,
                                  unsigned long samplerate)

    int ebur128_set_max_window(ebur128_state *state, unsigned long window)

    int ebur128_set_max_history(ebur128_state *state, unsigned long history)

    int ebur128_add_frames_short(ebur128_state *state,
                                 const short *source,
                                 size_t frames)
    int ebur128_add_frames_int(ebur128_state *state,
                               const int *source,
                               size_t frames)
    int ebur128_add_frames_float(ebur128_state *state,
                                 const float *source,
                                 size_t frames)
    int ebur128_add_frames_double(ebur128_state *state,
                                  const double *source,
                                  size_t frames)

    int ebur128_loudness_global(ebur128_state *state, double *loudness)

    int ebur128_loudness_global_multiple(ebur128_state **states,
                                         size_t size,
                                         double *loudness)

    int ebur128_loudness_momentary(ebur128_state *state, double *loudness)

    int ebur128_loudness_shortterm(ebur128_state *state, double *loudness)

    int ebur128_loudness_window(ebur128_state *state,
                                unsigned long window,
                                double *loudness)

    int ebur128_loudness_range(ebur128_state *state, double *loudness)

    int ebur128_loudness_range_multiple(ebur128_state **states,
                                        size_t size,
                                        double *loudness)

    int ebur128_sample_peak(ebur128_state *state,
                            unsigned int channel_number,
                            double *max_peak)

    int ebur128_prev_sample_peak(ebur128_state *state,
                                 unsigned int channel_number,
                                 double *max_peak)

    int ebur128_true_peak(ebur128_state *state,
                          unsigned int channel_number,
                          double *max_peak)

    int ebur128_prev_true_peak(ebur128_state *state,
                               unsigned int channel_number,
                               double *max_peak)

    int ebur128_relative_threshold(ebur128_state *state, double *threshold)
