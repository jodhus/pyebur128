#!/usr/bin/python3

from setuptools import setup, Extension


extensions = [
    Extension(
        name='pyebur128.pyebur128',
        sources=[
            "src/pyebur128/pyebur128.pyx",
            "src/lib/ebur128/ebur128.c",
        ],
        include_dirs=[
            '.',
            'src/lib/ebur128',
            'src/lib/ebur128/queue',
        ],
        # Not happy about it, but I'll just use this macro on all compilers for
        # now. Setuptools doesn't have a reliable way to detect MSVC when they
        # started deprecating the older distutils functionality of MSVCCompiler
        # and new_compiler(). Besides, looking at the old distutils code, it
        # just assumed that MSVC was the compiler if it detected Windows. If you
        # wanted GCC/MinGW/LLVM on Windows, you had to manually pass it as an
        # argument to new_compiler().
        # See https://github.com/pypa/setuptools/issues/2806
        define_macros=[('_USE_MATH_DEFINES', None)],
    ),
]


if __name__ == '__main__':
    from Cython.Build import cythonize

    setup(
        ext_modules=cythonize(
            extensions,
            compiler_directives={'language_level': 3, 'embedsignature': True},
        ),
    )
