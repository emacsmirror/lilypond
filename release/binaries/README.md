LilyPond Binaries
=================

This directory contains scripts to build and package binaries of LilyPond;
they are intended to be run within an Ansible playbook, see `ansible/README.md` for more information.
Linux binaries are created with AlmaLinux 8,
Windows binaries are created with the MinGW-w64 cross-compiler running on Ubuntu 22.04,
and macOS binaries under macOS.

There are intentionally no efforts to make the scripts more generic, mainly to keep them simple.


Usage
-----

1. Download and build all dependencies using `./build-dependencies`. 
2. Build and package LilyPond by running `./build-lilypond <lilypond-X.Y.Z.tar.gz>`.
   The tarball may either be an official one or created via `make dist` for local testing.

The dependencies built in the first step can be reused for multiple builds of LilyPond.
To actually rebuild from scratch, you should delete the entire `dependencies/` directory before running the script.
During development, it is faster to include only particular packages in the variable `all_dependencies` at the bottom of `dependencies.py`.
However, always restore these changes and test that a full build is successful before submitting changes.

Requirements
------------

The scripts assume all [Requirements for compiling Lilypond](https://lilypond.org/doc/development/Documentation/contributor/requirements-for-compiling-lilypond) to be installed.
Additionally, you need a few tools to build the dependencies:

 * [`gperf`](https://www.gnu.org/software/gperf/)
 * [`meson`](https://mesonbuild.com/) (at least version 1.2.0)
 * [`ninja`](https://ninja-build.org/)

They should be available for the distribution you use, but some may not be recent enough.
For `meson` in particular, try installing the latest version with `pip`.

Make sure that your operating system's default compiler is able to compile LilyPond
(for example, g++ version 8).
C source code files should then be compiled with the corresponding C compiler sibling that has the same version
(for example, gcc version 8).

Mingw peculiarities
-------------------

In order to do cross-compilation to mingw, a previous successful Linux build is necessary,
because Guile needs to bootstrap itself, which is not possible when host and target system differ.

You need MinGW-w64 version 8.0.0 or newer.

Only the 'win32' thread model is supported for the gcc and g++ mingw cross compilers;
this can be verified by checking the output of `x86_64-w64-mingw32-gcc -v`.

Goals and Non-Goals
-------------------

 * **Build natively, avoid cross-compilation**.
   This reduces a large amount of the complexity since many packages are not well-prepared for cross-compilation.
   Native compilation is also required for macOS due to Apple's licensing policies.
   (Cross-compilation to mingw may become an exception to the rule.)
 * **Use static builds of dependencies, no shared libraries**.
   This avoids problems related to finding dependencies while not interfering with their system-provided versions.
    * *Only link dynamically against fundamental libraries*, such as `libc` on Unix systems.
    * *Build on the oldest supported version of an OS* to obtain binaries that run across many systems.
 * **Be specific to LilyPond, no generic package manager**.
    * *Disable optional features* not needed for building and running LilyPond.
      This cuts down the number of dependencies to build and reduces the size of the distributed archives.
    * *Use a pre-determined build order*, avoid dynamic dependency resolution for transitive dependencies.
 * **Use tarballs for sources, no download from git**.
   No need to push changes to a server just to build them, just run `make dist` locally.
 * **Keep it simple, stupid**.
   If something is not needed to build binaries for LilyPond, do not implement it.

Code Format & Linting
---------------------

The code is formatted using [*Black*, the uncompromising code formatter](https://black.readthedocs.io/en/stable/).
Every change should be formatted to keep the code base maintainable.
[*Pylint*](https://pylint.org/) is used for code analysis, for example [Python's PEP8 style guide](https://www.python.org/dev/peps/pep-0008/).
