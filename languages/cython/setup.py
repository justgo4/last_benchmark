from setuptools import setup, Extension
from Cython.Build import cythonize
setup(ext_modules=cythonize([Extension("bench_ext",["bench_ext.pyx"],extra_compile_args=["-O3","-march=native","-flto","-ffp-contract=off"],extra_link_args=["-flto"])],compiler_directives={"language_level":3}))
