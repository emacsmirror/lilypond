# This file is part of LilyPond, the GNU music typesetter.
#
# Copyright (C) 2021--2023 Jonas Hahnfeld <hahnjo@hahnjo.de>
#
# LilyPond is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# LilyPond is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with LilyPond.  If not, see <http://www.gnu.org/licenses/>.

"""This module defines all run-time dependencies of LilyPond."""

# Each class in this file represents a package, ignore missing docstrings.
# pylint: disable=missing-class-docstring

import logging
import os
import re
import shutil
import subprocess
from typing import Dict, List

from .build import Package, ConfigurePackage, MesonPackage
from .config import Config


def copy_slice(src: str, dst: str, lines: slice):
    """Copy a slice of lines from src to dst."""
    with open(src, "r", encoding="utf-8") as src_file:
        content = src_file.readlines()
    content = content[lines]
    with open(dst, "w", encoding="utf-8") as dst_file:
        dst_file.writelines(content)


class Expat(ConfigurePackage):
    @property
    def version(self) -> str:
        return "2.6.2"

    @property
    def directory(self) -> str:
        return f"expat-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        version = self.version.replace(".", "_")
        return f"https://github.com/libexpat/libexpat/releases/download/R_{version}/{self.archive}"

    def configure_args(self, c: Config) -> List[str]:
        return [
            # Disable unneeded components.
            "--without-xmlwf",
            "--without-examples",
            "--without-tests",
            "--without-docbook",
        ]

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"Expat {self.version}"


expat = Expat()


class Zlib(ConfigurePackage):
    @property
    def version(self) -> str:
        return "1.3.1"

    @property
    def directory(self) -> str:
        return f"zlib-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://github.com/madler/zlib/releases/download/v{self.version}/{self.archive}"

    def apply_patches(self, c: Config):
        def patch_configure(content: str) -> str:
            return content.replace("leave 1", "")

        self.patch_file(c, "configure", patch_configure)

    def build_env_extra(self, c: Config) -> Dict[str, str]:
        env = super().build_env_extra(c)
        if c.is_mingw():
            env["CHOST"] = c.triple
        return env

    def configure_args_triples(self, c: Config) -> List[str]:
        # Cross-compilation is enabled via the CHOST environment variable.
        return []

    def configure_args_static(self, c: Config) -> List[str]:
        return ["--static"]

    def get_env_variables(self, c: Config) -> Dict[str, str]:
        """Return environment variables to make zlib available."""
        zlib_install = self.install_directory(c)
        return {
            "CPATH": os.path.join(zlib_install, "include"),
            # Cannot use LIBRARY_PATH because it is only used if GCC is built
            # as a native compiler, so it doesn't work for mingw.
            "LDFLAGS": "-L" + os.path.join(zlib_install, "lib"),
        }

    def copy_license_files(self, destination: str, c: Config):
        readme_src = os.path.join(self.src_directory(c), "README")
        readme_dst = os.path.join(destination, f"{self.directory}.README")
        copy_slice(readme_src, readme_dst, slice(-38, None))

    def __str__(self) -> str:
        return f"zlib {self.version}"


zlib = Zlib()


class FreeType(ConfigurePackage):
    @property
    def version(self) -> str:
        return "2.13.2"

    @property
    def directory(self) -> str:
        return f"freetype-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://download.savannah.gnu.org/releases/freetype/{self.archive}"

    def dependencies(self, c: Config) -> List[Package]:
        return [zlib]

    def configure_args(self, c: Config) -> List[str]:
        return [
            "--with-zlib=yes",
            "--with-bzip2=no",
            "--with-png=no",
            "--with-brotli=no",
            # Disable unused harfbuzz.
            "--with-harfbuzz=no",
        ]

    @property
    def license_files(self) -> List[str]:
        return ["LICENSE.TXT", os.path.join("docs", "GPLv2.TXT")]

    def __str__(self) -> str:
        return f"FreeType {self.version}"


freetype = FreeType()


class Fontconfig(ConfigurePackage):
    @property
    def version(self) -> str:
        return "2.14.2"

    @property
    def directory(self) -> str:
        return f"fontconfig-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://www.freedesktop.org/software/fontconfig/release/{self.archive}"

    def dependencies(self, c: Config) -> List[Package]:
        return [expat, freetype]

    def configure_args(self, c: Config) -> List[str]:
        return ["--disable-docs"]

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"Fontconfig {self.version}"


fontconfig = Fontconfig()


class Ghostscript(ConfigurePackage):
    @property
    def version(self) -> str:
        return "10.03.0"

    @property
    def directory(self) -> str:
        return f"ghostscript-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.gz"

    @property
    def download_url(self) -> str:
        # pylint: disable=line-too-long
        url_version = self.version.replace(".", "")
        return f"https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs{url_version}/{self.archive}"

    def apply_patches(self, c: Config):
        # Remove unused bundled sources to disable their build.
        dirs = ["tesseract", "leptonica"]

        for unused in dirs:
            shutil.rmtree(os.path.join(self.src_directory(c), unused))

    def dependencies(self, c: Config) -> List[Package]:
        return [freetype]

    def configure_args_static(self, c: Config) -> List[str]:
        # Ghostscript doesn't have --disable-shared nor --enable-static.
        return []

    def configure_args(self, c: Config) -> List[str]:
        mingw_args = []
        if c.is_mingw():
            mingw_args = [
                # Some platforms have sys/times.h for native compilation;
                # however, mingw doesn't have it. Ghostscript's doesn't
                # handle this situation correctly.
                "GCFLAGS=-DHAVE_SYS_TIMES_H=0",
            ]
        return mingw_args + [
            # Only enable drivers needed for LilyPond.
            "--disable-contrib",
            "--disable-dynamic",
            "--with-drivers=PNG,PS",
            # Disable unused dependencies and features.
            "--disable-cups",
            "--disable-dbus",
            "--disable-fontconfig",
            "--disable-gtk",
            "--without-cal",
            "--without-ijs",
            "--without-libidn",
            "--without-libpaper",
            "--without-libtiff",
            "--without-pdftoraster",
            "--without-urf",
            "--without-x",
        ]

    def exe_path(self, c: Config) -> str:
        """Return path to gs executable."""
        gs_exe = f"gs{c.program_suffix}"
        return os.path.join(self.install_directory(c), "bin", gs_exe)

    @property
    def license_files(self) -> List[str]:
        return ["LICENSE", os.path.join("doc", "COPYING")]

    def __str__(self) -> str:
        return f"Ghostscript {self.version}"


ghostscript = Ghostscript()


class Gettext(ConfigurePackage):
    def enabled(self, c: Config) -> bool:
        return c.is_freebsd() or c.is_macos() or c.is_mingw()

    @property
    def version(self) -> str:
        return "0.22.5"

    @property
    def directory(self) -> str:
        return f"gettext-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://ftpmirror.gnu.org/gnu/gettext/{self.archive}"

    def apply_patches(self, c: Config):
        # localcharset.c defines locale_charset, which is also provided by
        # Guile. However, Guile has a modification to this file so we really
        # need to build that version.
        def patch_makefile(content: str) -> str:
            return content.replace("libgnu_la-localcharset.lo", "")

        makefile = os.path.join("gettext-runtime", "intl", "gnulib-lib", "Makefile.in")
        self.patch_file(c, makefile, patch_makefile)

        def patch_dcigettext(content: str) -> str:
            return content.replace("locale_charset ()", "NULL")

        dcigettext = os.path.join("gettext-runtime", "intl", "dcigettext.c")
        self.patch_file(c, dcigettext, patch_dcigettext)

    @property
    def configure_script(self) -> str:
        return os.path.join("gettext-runtime", "configure")

    def configure_args_static(self, c: Config) -> List[str]:
        if c.is_mingw():
            # On mingw, we need to build glib as shared libraries for DllMain to
            # work. This also requires a shared libintl.dll to ensure there is
            # exactly one copy of the variables and code.
            return ["--enable-shared", "--disable-static"]
        return super().configure_args_static(c)

    def configure_args(self, c: Config) -> List[str]:
        return [
            # Disable building with libiconv in case the library is installed
            # on the system (as is the case for FreeBSD and macOS).
            "am_cv_func_iconv=no",
            # Disable unused features.
            "--disable-java",
            "--disable-threads",
        ]

    @property
    def macos_ldflags(self):
        """Return additional linker flags for macOS."""
        return "-Wl,-framework -Wl,CoreFoundation"

    def get_env_variables(self, c: Config) -> Dict[str, str]:
        """Return environment variables to make libintl available."""
        gettext_install = self.install_directory(c)

        # Cannot use LIBRARY_PATH because it is only used if GCC is built
        # as a native compiler, so it doesn't work for mingw.
        ldflags = "-L" + os.path.join(gettext_install, "lib")
        if c.is_macos():
            ldflags += " " + self.macos_ldflags

        return {
            "CPATH": os.path.join(gettext_install, "include"),
            "LDFLAGS": ldflags,
        }

    @property
    def license_files(self) -> List[str]:
        return [
            os.path.join("gettext-runtime", "COPYING"),
            os.path.join("gettext-runtime", "intl", "COPYING.LIB"),
        ]

    def __str__(self) -> str:
        return f"gettext {self.version}"


gettext = Gettext()


class Libffi(ConfigurePackage):
    @property
    def version(self) -> str:
        return "3.4.6"

    @property
    def directory(self) -> str:
        return f"libffi-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.gz"

    @property
    def download_url(self) -> str:
        return f"https://github.com/libffi/libffi/releases/download/v{self.version}/{self.archive}"

    def configure_args(self, c: Config) -> List[str]:
        return [
            # Avoid use of `lib64/` on some platforms.
            "--disable-multi-os-directory",
        ]

    @property
    def license_files(self) -> List[str]:
        return ["LICENSE"]

    def __str__(self) -> str:
        return f"libffi {self.version}"


libffi = Libffi()


class PCRE2(ConfigurePackage):
    @property
    def version(self) -> str:
        return "10.43"

    @property
    def directory(self) -> str:
        return f"pcre2-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.bz2"

    @property
    def download_url(self) -> str:
        return f"https://github.com/PCRE2Project/pcre2/releases/download/{self.directory}/{self.archive}"

    def apply_patches(self, c: Config):
        def patch_makefile(content: str) -> str:
            return "\n".join(
                [
                    line
                    for line in content.split("\n")
                    if "= pcre2posix_test" not in line
                ]
            )

        self.patch_file(c, "Makefile.in", patch_makefile)

    @property
    def license_files(self) -> List[str]:
        return ["LICENCE"]

    def __str__(self) -> str:
        return f"PCRE2 {self.version}"


pcre2 = PCRE2()


class GLib(MesonPackage):
    @property
    def version(self) -> str:
        return "2.80.0"

    @property
    def directory(self) -> str:
        return f"glib-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        major_version = ".".join(self.version.split(".")[0:2])
        return f"https://download.gnome.org/sources/glib/{major_version}/{self.archive}"

    def dependencies(self, c: Config) -> List[Package]:
        gettext_dep: List[Package] = []
        if c.is_freebsd() or c.is_macos() or c.is_mingw():
            gettext_dep = [gettext]
        return gettext_dep + [libffi, pcre2, zlib]

    def build_env_extra(self, c: Config) -> Dict[str, str]:
        env = super().build_env_extra(c)
        if c.is_freebsd() or c.is_macos() or c.is_mingw():
            # Make meson find libintl.
            env.update(gettext.get_env_variables(c))
        return env

    def meson_args_static(self, c: Config) -> List[str]:
        if c.is_mingw():
            # The libraries rely on DllMain which doesn't work with static.
            return ["--default-library=shared"]
        return super().meson_args_static(c)

    def meson_args(self, c: Config) -> List[str]:
        mingw_args = []
        if c.is_mingw():
            mingw_args = [
                # Prevent using format specifiers that trigger GCC warnings.
                "-Dc_args=-D__USE_MINGW_ANSI_STDIO",
            ]
        return mingw_args + [
            # Disable unused features and tests.
            "-Dlibmount=disabled",
            "-Dtests=false",
            "-Dxattr=false",
        ]

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"GLib {self.version}"


glib = GLib()


class Bdwgc(ConfigurePackage):
    @property
    def version(self) -> str:
        return "8.2.6"

    @property
    def directory(self) -> str:
        return f"gc-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.gz"

    @property
    def download_url(self) -> str:
        return f"https://github.com/ivmai/bdwgc/releases/download/v{self.version}/{self.archive}"

    def configure_args(self, c: Config) -> List[str]:
        return [
            "--disable-docs",
            # Enable large config, optimizing for heap sizes larger than a few
            # 100 MB and allowing more heap sections needed on Windows for huge
            # scores.
            "--enable-large-config",
            # Fix cross-compilation for mingw.
            "--with-libatomic-ops=none",
        ]

    def copy_license_files(self, destination: str, c: Config):
        readme_src = os.path.join(self.src_directory(c), "README.md")
        readme_dst = os.path.join(destination, f"{self.directory}.README")
        copy_slice(readme_src, readme_dst, slice(-48, None))

    def __str__(self) -> str:
        return f"bdwgc {self.version}"


bdwgc = Bdwgc()


class Libiconv(ConfigurePackage):
    def enabled(self, c: Config) -> bool:
        return c.is_mingw()

    @property
    def version(self) -> str:
        return "1.17"

    @property
    def directory(self) -> str:
        return f"libiconv-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.gz"

    @property
    def download_url(self) -> str:
        return f"https://ftpmirror.gnu.org/gnu/libiconv/{self.archive}"

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"libiconv {self.version}"


libiconv = Libiconv()


class Libunistring(ConfigurePackage):
    @property
    def version(self) -> str:
        return "1.2"

    @property
    def directory(self) -> str:
        return f"libunistring-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://ftpmirror.gnu.org/gnu/libunistring/{self.archive}"

    def dependencies(self, c: Config) -> List[Package]:
        libiconv_dep: List[Package] = []
        if c.is_mingw():
            libiconv_dep = [libiconv]
        return libiconv_dep

    def configure_args(self, c: Config) -> List[str]:
        mingw_args = []
        if c.is_mingw():
            libiconv_install_dir = libiconv.install_directory(c)
            mingw_args = [
                f"--with-libiconv-prefix={libiconv_install_dir}",
            ]

        return ["--disable-threads"] + mingw_args

    @property
    def license_files(self) -> List[str]:
        return ["COPYING.LIB"]

    def copy_license_files(self, destination: str, c: Config):
        super().copy_license_files(destination, c)

        readme_src = os.path.join(self.src_directory(c), "README")
        readme_dst = os.path.join(destination, f"{self.directory}.README")
        copy_slice(readme_src, readme_dst, slice(47, 63))

    def __str__(self) -> str:
        return f"libunistring {self.version}"


libunistring = Libunistring()


class Guile(ConfigurePackage):
    @property
    def version(self) -> str:
        return "3.0.10"

    @property
    def major_version(self) -> str:
        """Return Guile's major version, used in the directory structure."""
        return ".".join(self.version.split(".")[0:2])

    @property
    def directory(self) -> str:
        return f"guile-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://ftpmirror.gnu.org/gnu/guile/{self.archive}"

    def _apply_patches_mingw(self, c: Config):
        # Patch lightening to fix JIT calling conventions on Windows.
        def patch_x86(content: str) -> str:
            replace = "if (defined(__CYGWIN__) || defined(_WIN64))"
            content = content.replace("ifdef __CYGWIN__", replace)
            content = content.replace("if __CYGWIN__", replace)
            return content

        for ext in ["c", "h"]:
            x86 = os.path.join("libguile", "lightening", "lightening", f"x86.{ext}")
            self.patch_file(c, x86, patch_x86)

        # Fix headers so compilation of LilyPond works.
        def patch_numbers(content: str) -> str:
            return "\n".join(
                [line for line in content.split("\n") if "copysign" not in line]
            )

        numbers_h = os.path.join("libguile", "numbers.h")
        self.patch_file(c, numbers_h, patch_numbers)

        # Strictly speaking, this is not necessary for Guile 3.0.9 but it
        # makes testing of current main easier.
        def patch_scm(content: str) -> str:
            return content.replace(
                "# define SCM_API __declspec(dllimport) extern",
                "# define SCM_API extern",
            )

        scm_h = os.path.join("libguile", "scm.h")
        self.patch_file(c, scm_h, patch_scm)

        # Patch mini-gmp to use "long long" datatype.
        def patch_mini_gmp(content: str) -> str:
            return content.replace(
                "#define MINI_GMP_LIMB_TYPE long",
                "#define MINI_GMP_LIMB_TYPE long long",
            )

        mini_gmp_h = os.path.join("libguile", "mini-gmp.h")
        self.patch_file(c, mini_gmp_h, patch_mini_gmp)

        # Apply backported patches to make Guile 3.0.10 work on Windows, see also
        # https://lists.gnu.org/archive/html/guile-devel/2023-10/msg00051.html
        root_path = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
        for patch in [
            "0001-scm_i_divide2double-Refactor-to-use-scm_to_mpz.patch",
            "0002-scm_integer_modulo_expt_nnn-Refactor-to-use-scm_to_m.patch",
            "0003-Rename-functions-that-should-accept-scm_t_inum.patch",
            "0004-Decouple-scm_t_inum-from-long-datatype.patch",
            "0005-Store-hashes-as-uintptr_t.patch",
            "0006-Use-inum_magnitude-for-inums.patch",
            "0007-Fix-inum-negation.patch",
            "0008-Avoid-using-long-integers-literals.patch",
            "0009-mpz-integer-do-not-convert-to-bignum-if-inum-is-suff.patch",
            "0010-Fix-setjmp-longjmp-related-crashes-on-Windows.patch",
        ]:
            patch_path = os.path.join(root_path, "patches", patch)
            with open(patch_path) as patch_file:
                subprocess.run(
                    ["patch", "-p1"],
                    stdin=patch_file,
                    stdout=subprocess.DEVNULL,
                    cwd=self.src_directory(c),
                    check=True,
                )

        # Patch '0010-...' changes `libguile/Makefile.am`. We thus modify
        # `libguile/Makefile.in` manually to avoid a dependency on
        # `auto(re)conf`.
        def patch_makefile_in(content: str) -> str:
            return content.replace("script.h", "script.h setjump-win.h")

        makefile_in = os.path.join("libguile", "Makefile.in")
        self.patch_file(c, makefile_in, patch_makefile_in)


    def apply_patches(self, c: Config):
        if c.is_mingw():
            self._apply_patches_mingw(c)

    def dependencies(self, c: Config) -> List[Package]:
        gettext_dep: List[Package] = []
        if c.is_freebsd() or c.is_macos() or c.is_mingw():
            gettext_dep = [gettext]
        libiconv_dep: List[Package] = []
        if c.is_mingw():
            libiconv_dep = [libiconv]
        return gettext_dep + libiconv_dep + [bdwgc, libffi, libunistring]

    def build_env_extra(self, c: Config) -> Dict[str, str]:
        env = super().build_env_extra(c)
        if c.is_macos():
            # We don't need the full get_env_variables because we can pass
            # --with-libintl-prefix= via the arguments to configure.
            env["LDFLAGS"] = gettext.macos_ldflags
        return env

    def configure_args(self, c: Config) -> List[str]:
        libunistring_install_dir = libunistring.install_directory(c)

        libintl_args = []
        if c.is_freebsd() or c.is_macos() or c.is_mingw():
            gettext_install_dir = gettext.install_directory(c)
            libintl_args = [
                f"--with-libintl-prefix={gettext_install_dir}",
            ]

        mingw_args = []
        if c.is_mingw():
            guile_for_build = self.exe_path(c.native_config)
            libiconv_install_dir = libiconv.install_directory(c)
            mingw_args = [
                f"GUILE_FOR_BUILD={guile_for_build}",
                f"--with-libiconv-prefix={libiconv_install_dir}",
                # Disable threads, not needed on Windows.
                "--without-threads",
            ]

        return (
            [
                # Disable unused parts of Guile.
                "--disable-networking",
                # Disable -Werror to enable builds with newer compilers.
                "--disable-error-on-warning",
                # Disable LTO.
                "--disable-lto",
                # Enable builtin mini-gmp to avoid building GMP ourselves.
                "--enable-mini-gmp",
                # Make configure find the statically built dependencies.
                f"--with-libunistring-prefix={libunistring_install_dir}",
                # Prevent that configure searches for libcrypt.
                "ac_cv_search_crypt=no",
            ]
            + libintl_args
            + mingw_args
        )

    def exe_path(self, c: Config) -> str:
        """Return path to the guile interpreter."""
        guile_exe = f"guile{c.program_suffix}"
        return os.path.join(self.install_directory(c), "bin", guile_exe)

    @property
    def license_files(self) -> List[str]:
        return ["LICENSE", "COPYING.LESSER"]

    def __str__(self) -> str:
        return f"Guile {self.version}"


guile = Guile()


class HarfBuzz(MesonPackage):
    @property
    def version(self) -> str:
        return "8.4.0"

    @property
    def directory(self) -> str:
        return f"harfbuzz-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        # pylint: disable=line-too-long
        return f"https://github.com/harfbuzz/harfbuzz/releases/download/{self.version}/{self.archive}"

    def dependencies(self, c: Config) -> List[Package]:
        return [freetype]

    def meson_args(self, c: Config) -> List[str]:
        return [
            # Enable FreeType, but disable tests.
            "-Dfreetype=enabled",
            "-Dtests=disabled",
        ]

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"HarfBuzz {self.version}"


harfbuzz = HarfBuzz()


class FriBidi(ConfigurePackage):
    @property
    def version(self) -> str:
        return "1.0.13"

    @property
    def directory(self) -> str:
        return f"fribidi-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        # pylint: disable=line-too-long
        return f"https://github.com/fribidi/fribidi/releases/download/v{self.version}/{self.archive}"

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"FriBiDi {self.version}"


fribidi = FriBidi()


class Pango(MesonPackage):
    @property
    def version(self) -> str:
        return "1.52.2"

    @property
    def directory(self) -> str:
        return f"pango-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        major_version = ".".join(self.version.split(".")[0:2])
        # fmt: off
        return f"https://download.gnome.org/sources/pango/{major_version}/{self.archive}"
        # fmt: on

    def apply_patches(self, c: Config):
        # Disable tests, fail to build on FreeBSD.
        def patch_meson_build(content: str) -> str:
            # Disable unused parts (tests fail to build on FreeBSD, utils and tools on macOS)
            for subdir in ["tests", "tools", "utils"]:
                content = content.replace(f"subdir('{subdir}')", "")
            return content

        self.patch_file(c, "meson.build", patch_meson_build)

    def dependencies(self, c: Config) -> List[Package]:
        return [fontconfig, freetype, fribidi, glib, harfbuzz]

    def build_env_extra(self, c: Config) -> Dict[str, str]:
        env = super().build_env_extra(c)
        glib_bin = os.path.join(glib.install_directory(c), "bin")
        env["PATH"] = f"{glib_bin}{os.pathsep}{os.environ['PATH']}"
        return env

    def meson_args(self, c: Config) -> List[str]:
        return [
            # Disable Cairo, which is enabled by default since 1.50.3.
            "-Dcairo=disabled",
            # Enable Fontconfig and FreeType.
            "-Dfontconfig=enabled",
            "-Dfreetype=enabled",
        ]

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"Pango {self.version}"


pango = Pango()


class Libpng(ConfigurePackage):
    @property
    def version(self) -> str:
        return "1.6.43"

    @property
    def directory(self) -> str:
        return f"libpng-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://downloads.sourceforge.net/libpng/{self.archive}"

    def dependencies(self, c: Config) -> List[Package]:
        return [zlib]

    def build_env_extra(self, c: Config) -> Dict[str, str]:
        env = super().build_env_extra(c)
        env.update(zlib.get_env_variables(c))
        return env

    @property
    def license_files(self) -> List[str]:
        return ["LICENSE"]

    def __str__(self) -> str:
        return f"libpng {self.version}"


libpng = Libpng()


class Pixman(MesonPackage):
    @property
    def version(self) -> str:
        return "0.43.4"

    @property
    def directory(self) -> str:
        return f"pixman-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.gz"

    @property
    def download_url(self) -> str:
        return f"https://www.cairographics.org/releases/{self.archive}"

    def apply_patches(self, c: Config):
        # Disable tests, they fail to build on macOS.
        def patch_meson_build(content: str) -> str:
            return content.replace("subdir('test')", "")

        self.patch_file(c, "meson.build", patch_meson_build)

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"pixman {self.version}"


pixman = Pixman()


class Cairo(MesonPackage):
    @property
    def version(self) -> str:
        return "1.18.0"

    @property
    def directory(self) -> str:
        return f"cairo-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://www.cairographics.org/releases/{self.archive}"

    def dependencies(self, c: Config) -> List[Package]:
        return [zlib, freetype, fontconfig, libpng, pixman]

    def build_env_extra(self, c: Config) -> Dict[str, str]:
        env = super().build_env_extra(c)
        env.update(zlib.get_env_variables(c))
        # Cairo sets this by default, but doesn't work on Mingw.
        env["CFLAGS"] = "-Wp,-U_FORTIFY_SOURCE"
        return env

    def meson_args(self, c: Config) -> List[str]:
        return [
            "-Dfontconfig=enabled",
            "-Dfreetype=enabled",
            "-Dpng=enabled",
            "-Dzlib=enabled",
        ]

    @property
    def license_files(self) -> List[str]:
        return ["COPYING"]

    def __str__(self) -> str:
        return f"cairo {self.version}"


cairo = Cairo()


PYTHON_VERSION = "3.12.2"


class Python(ConfigurePackage):
    def enabled(self, c: Config) -> bool:
        # For Windows, we are using the embeddable package because it's
        # impossible to cross-compile Python without tons of patches...
        return not c.is_mingw()

    @property
    def version(self) -> str:
        return PYTHON_VERSION

    @property
    def major_version(self) -> str:
        """Return Python's major version, used in the executable name."""
        return ".".join(self.version.split(".")[0:2])

    @property
    def python_with_major_version(self) -> str:
        """Return the string 'python' with the major version."""
        return f"python{self.major_version}"

    @property
    def directory(self) -> str:
        return f"Python-{self.version}"

    @property
    def archive(self) -> str:
        return f"{self.directory}.tar.xz"

    @property
    def download_url(self) -> str:
        return f"https://www.python.org/ftp/python/{self.version}/{self.archive}"

    def apply_patches(self, c: Config):
        # By default, configure and Modules/Setup.stdlib build extensions based
        # on installed software, and while it is possible to selectively disable
        # them, it is just easier to enable what we need in Modules/Setup below.
        # It has the additional advantage that the modules are built statically
        # into libpython and not dynamically loaded from lib-dynload/.
        Setup_stdlib_in = os.path.join(
            self.src_directory(c), "Modules", "Setup.stdlib.in"
        )
        with open(Setup_stdlib_in, "w", encoding="utf-8"):
            pass

        def patch_setup(content: str) -> str:
            for module in [
                "array",
                "fcntl",
                "math",
                # Needed for fractions
                "_contextvars",
                # Needed for hashlib
                "_blake2",
                "_md5",
                "_sha1",
                "_sha2",
                "_sha3",
                # Needed for subprocess
                "_posixsubprocess",
                "select",
                # Needed for tempfile
                "_random",
                # Needed for xml
                "pyexpat",
                # Needed for zipfile
                "binascii",
                "_struct",
                "zlib",
            ]:
                content = content.replace("#" + module, module)
            return content

        self.patch_file(c, os.path.join("Modules", "Setup"), patch_setup)

    def dependencies(self, c: Config) -> List[Package]:
        return [zlib]

    def build_env_extra(self, c: Config) -> Dict[str, str]:
        env = super().build_env_extra(c)
        env.update(zlib.get_env_variables(c))
        return env

    def configure_args(self, c: Config) -> List[str]:
        return [
            "--with-ensurepip=no",
            # Prevent that configure searches for libcrypt.
            "ac_cv_search_crypt=no",
            "ac_cv_search_crypt_r=no",
        ]

    def exe_path(self, c: Config) -> str:
        """Return path to the python3 interpreter."""
        exe = self.python_with_major_version
        return os.path.join(self.install_directory(c), "bin", exe)

    @property
    def license_files(self) -> List[str]:
        return ["LICENSE"]

    def __str__(self) -> str:
        return f"Python {self.version}"


python = Python()


class EmbeddablePython(Package):
    def enabled(self, c: Config) -> bool:
        return c.is_mingw()

    @property
    def version(self) -> str:
        return PYTHON_VERSION

    @property
    def directory(self) -> str:
        return f"python-{self.version}-embed-amd64"

    @property
    def archive(self) -> str:
        return f"{self.directory}.zip"

    @property
    def download_url(self) -> str:
        return f"https://www.python.org/ftp/python/{self.version}/{self.archive}"

    def prepare_sources(self, c: Config) -> bool:
        src_directory = self.src_directory(c)
        if os.path.exists(src_directory):
            logging.debug("'%s' already extracted", self.archive)
            return True

        archive = self.archive_path(c)
        if not os.path.exists(archive):
            logging.error("'%s' does not exist!", self.archive)
            return False

        # The archive has no directory, directly extract into src_directory.
        shutil.unpack_archive(archive, self.src_directory(c))

        return True

    def build(self, c: Config):
        src_directory = self.src_directory(c)
        install_directory = self.install_directory(c)

        os.makedirs(install_directory, exist_ok=True)

        # NB: Without a dot between the two numbers!
        major_version = "".join(self.version.split(".")[0:2])
        python_with_major_version = f"python{major_version}"

        # Copy over the needed files from the downloaded archive.
        for filename in [
            "python.exe",
            f"{python_with_major_version}.dll",
            f"{python_with_major_version}.zip",
            # For parsing (Music)XML
            "pyexpat.pyd",
        ]:
            shutil.copy(os.path.join(src_directory, filename), install_directory)

        return True

    @property
    def license_files(self) -> List[str]:
        return ["LICENSE.txt"]

    def __str__(self) -> str:
        return f"Python {self.version} (embeddable package)"


embeddable_python = EmbeddablePython()

all_dependencies: List[Package] = [
    expat,
    zlib,
    freetype,
    fontconfig,
    ghostscript,
    gettext,
    libffi,
    pcre2,
    glib,
    bdwgc,
    libiconv,
    libunistring,
    guile,
    harfbuzz,
    fribidi,
    pango,
    libpng,
    pixman,
    cairo,
    python,
    embeddable_python,
]
