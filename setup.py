#!/usr/bin/python3

import platform

from setuptools import setup, find_packages, Extension
from distutils.ccompiler import new_compiler
from distutils.msvccompiler import MSVCCompiler


def is_msvc():
    '''Checks to see if the detected C compiler is MSVC.'''
    try:
        # This depends on _winreg, which is not available on not-Windows.
        from distutils.msvc9compiler import MSVCCompiler as MSVC9Compiler
    except ImportError:
        MSVC9Compiler = None
    try:
        from distutils._msvccompiler import MSVCCompiler as MSVC14Compiler
    except ImportError:
        MSVC14Compiler = None
    msvc_classes = tuple(filter(None, (MSVCCompiler,
                                       MSVC9Compiler,
                                       MSVC14Compiler)))
    cc = new_compiler()
    return isinstance(cc, msvc_classes)


macros = []

# MSVC won't use <math.h> unless this is defined.
if platform.system() == 'Windows' and is_msvc():
    macros.append(('_USE_MATH_DEFINES', None))

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
        define_macros=macros,
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
