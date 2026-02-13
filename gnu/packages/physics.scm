;;; Copyright © 2026 Danny Milosavljevic <dannym@friendly-machines.com>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages physics)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system meson)
  #:use-module (guix build-system pyproject)
  #:use-module ((guix build-system python) #:select (pypi-uri))
  #:use-module (guix build-system qt)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages algebra)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages machine-learning)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages ninja)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-check)
  #:use-module (gnu packages python-compression)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-graphics)
  #:use-module (gnu packages python-science)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages qt))

(define-public python-brille
  (package
    (name "python-brille")
    (version "0.8.3")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/brille/brille")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1vyxa7k6yrpxizbmljrv7bnsf7dzxsfbs4id36x09jjxwh7dysjj"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list
              ;; Boost.System is header-only since 1.69, but FindBoost looks for
              ;; libboost_system.so which doesn't exist.
              "-DHIGHFIVE_USE_BOOST=OFF"
              ;; Pretend we're doing a scikit-build build to skip Conan.
              "-DSKBUILD=ON"
              (string-append "-DSKBUILD_PROJECT_NAME=brille")
              (string-append "-DSKBUILD_PROJECT_VERSION=" #$version))
      #:imported-modules `(,@%cmake-build-system-modules
                           ,@%pyproject-build-system-modules)
      #:modules '((guix build cmake-build-system)
                  ((guix build python-build-system) #:select (site-packages))
                  (guix build utils))
      #:phases
      (with-extensions (list (pyproject-guile-json))
        #~(modify-phases %standard-phases
            (add-after 'unpack 'create-pkg-info
              (lambda _
                ;; Create PKG-INFO so DynamicVersion.cmake finds version without git.
                (call-with-output-file "PKG-INFO"
                  (lambda (port)
                    (format port "Metadata-Version: 2.1
Name: brille
Version: ~a
" #$version)))))
            (add-before 'configure 'set-version
              (lambda _
                (setenv "SETUPTOOLS_SCM_PRETEND_VERSION" #$version)))
            (add-after 'install 'install-python
              (lambda* (#:key inputs outputs #:allow-other-keys)
                (let ((site-packages (site-packages inputs outputs)))
                  (mkdir-p (string-append site-packages "/brille"))
                  ;; Install Python source files and compiled extension module.
                  (for-each (lambda (file)
                              (install-file file
                                            (string-append site-packages "/brille")))
                            (append
                             (find-files "../source/brille" "\\.py$")
                             (find-files "." "^_brille\\..*\\.so$"))))))))))
    (native-inputs
     (list catch2-3
           cmake-minimal
           highfive
           pybind11
           python-wrapper
           python-setuptools
           python-setuptools-scm))
    (inputs
     (list hdf5))
    (propagated-inputs
     (list python-numpy))
    (home-page "https://github.com/brille/brille")
    (synopsis "Symmetry operations and interpolation in Brillouin zones")
    (description
     "Brille is a C++ library for symmetry operations and linear interpolation
within an irreducible part of the first Brillouin zone.  It provides Python
bindings via pybind11 for use in phonon calculations and inelastic neutron
scattering simulations.")
    (license license:agpl3+)))

(define-public python-gofit
  (package
    (name "python-gofit")
    (version "1.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ralna/gofit")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0x7kk97k4v1mzgs29z9i2yidjx4hmdwhng77178l564hn29k1c2b"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-requirements
            (lambda _
              ;; pybind11[global] is a build-time dependency, not runtime.
              ;; <https://github.com/pybind/python_example/issues/45>
              (substitute* "setup.py"
                (("install_requires=")
                 "setup_requires="))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                ;; test_multistart_ls.py needs cubic.txt in cwd
                (copy-file "tests/cubic.txt" "cubic.txt")
                (for-each (lambda (test)
                            (invoke "python" test))
                          (find-files "tests" "^test_.*\\.py$"))))))))
    (native-inputs (list pybind11 python-setuptools cmake python-pytest
                         python-numpy))
    (inputs (list eigen))
    (home-page "https://github.com/ralna/gofit")
    (synopsis "GOFit: Global Optimization for Fitting problems")
    (description "GOFit: Global Optimization for Fitting problems.")
    (license license:bsd-3)))

(define-public python-pycifrw
  (package
    (name "python-pycifrw")
    (version "4.4.6")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "PyCifRW" version))
       (sha256
        (base32 "05ggj4l9cir02m593azhl03wfjimx3rvwbznpx01bdqawxsmkgq2"))))
    (build-system pyproject-build-system)
    (arguments
     ;; Tests are not included in the PyPI tarball.
     (list #:tests? #f))
    (propagated-inputs
     (list python-numpy python-ply))
    (native-inputs
     (list python-setuptools))  ; build-backend = setuptools.build_meta
    (home-page "https://github.com/jamesrhester/pycifrw")
    (synopsis "CIF file reader and writer")
    (description
     "PyCifRW provides support for reading and writing CIF (Crystallographic
Information File) format files.  CIF is the standard format for
crystallographic data exchange endorsed by the International Union of
Crystallography.")
    (license license:psfl)))

(define-public python-pystog
  (package
    (name "python-pystog")
    (version "0.6.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/neutrons/pystog")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1dwljmyp083v5a189xzdxxsdkazh5bmbm2f2k79jp7lds0y8h9lg"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-version
            (lambda _
              ;; versioningit needs git tags; patch pyproject.toml to use
              ;; static version and create _version.py directly.
              (substitute* "pyproject.toml"
                (("dynamic = \\[\"version\"\\]")
                 (string-append "version = \"" #$version "\""))
                (("source = \"versioningit\"") "")
                (("\\[tool\\.hatch\\.build\\.hooks\\.versioningit-onbuild\\]")
                 "[tool.hatch.build.hooks.versioningit-onbuild]
enable-by-default = false"))
              (mkdir-p "src/pystog")
              (call-with-output-file "src/pystog/_version.py"
                (lambda (port)
                  (format port "__version__ = \"~a\"~%" #$version))))))))
    (propagated-inputs
     (list python-h5py
           python-numpy))
    (native-inputs
     (list python-hatchling
           python-pytest))
    (home-page "https://github.com/neutrons/pystog")
    (synopsis "Total scattering function manipulator")
    (description
     "PyStoG is a Python package for converting between different total
scattering functions used in crystalline and amorphous materials research.
It handles reciprocal-space structure factors and real-space pair distribution
functions, performing Fourier transforms between them and applying filters to
remove spurious artifacts in the data.")
    (license license:gpl3+)))

(define-public python-quasielasticbayes
  (package
    (name "python-quasielasticbayes")
    (version "0.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/mantidproject/quasielasticbayes")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "05va9qygw4a9app61spw6hqmbn9cq09w0dik9g6xvzpwcmfb7yx4"))))
    (build-system meson-build-system)
    (arguments
     (list
      #:imported-modules `((guix build python-build-system)
                           ,@%meson-build-system-modules)
      #:modules '((guix build meson-build-system)
                  ((guix build python-build-system) #:prefix py:)
                  (guix build utils))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'check
            (lambda* (#:key tests? inputs outputs #:allow-other-keys)
              (when tests?
                (py:add-installed-pythonpath inputs outputs)
                (invoke "pytest" "../source/src/quasielasticbayes/test")))))))
    (native-inputs
     (list gfortran
           python
           python-numpy
           python-pytest))
    (propagated-inputs
     (list python-numpy))
    (home-page "https://github.com/mantidproject/quasielasticbayes")
    (synopsis "Bayesian analysis for quasi-elastic neutron scattering")
    (description
     "This package provides Python wrappers for Fortran routines used to
perform Bayesian analysis on quasi-elastic neutron-scattering data.  The
original Fortran code was written by Dr. Devinder Sivia in the 1980s.")
    (license license:bsd-3)))

(define-public python-spglib
  (package
    (name "python-spglib")
    (version "2.6.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "spglib" version))
       (sha256
        (base32 "1sq8niay87n7hmby6hs628zzpc4apx6kp77cjvyi87hal0mxlvnn"))))
    (build-system pyproject-build-system)
    (propagated-inputs
     (list python-numpy
           python-typing-extensions))
    (native-inputs
     (list cmake-minimal
           python-pytest
           python-pyyaml
           python-scikit-build-core
           python-setuptools-scm))
    (home-page "https://spglib.readthedocs.io/")
    (synopsis "Python bindings for spglib crystal symmetry library")
    (description
     "Spglib is a library for finding and handling crystal symmetries written
in C.  This package provides Python bindings for spglib, allowing Python
programs to find symmetry operations, identify space groups, and perform
other symmetry-related operations on crystal structures.")
    (license license:bsd-3)))

(define-public python-seekpath
  (package
    (name "python-seekpath")
    (version "2.1.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "seekpath" version))
       (sha256
        (base32 "1i2jhjc4ikd31v8wkxzfrvhwlv0dlzpkysf3lkafcql2c9wwbkii"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "pytest" "-vv" "tests")))))))
    (propagated-inputs
     (list python-numpy
           python-scipy
           python-spglib))
    (native-inputs
     (list python-pytest
           python-setuptools))
    (home-page "https://github.com/giovannipizzi/seekpath")
    (synopsis "K-path finder for band structure calculations")
    (description
     "SeeK-path is a Python module to obtain band paths in the Brillouin zone
of crystal structures.  It automatically detects Bravais lattice types and
generates k-point labels and band paths following crystallographic
conventions.")
    (license license:expat)))

(define-public python-euphonic
  (package
    (name "python-euphonic")
    (version "1.4.5")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/pace-neutrons/Euphonic.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1n3w2acwi9x1v4wavigrd0qwd559rx6aaz0xknhd4gnbqwzn05qp"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'build 'fix-numpy-include
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((numpy (assoc-ref inputs "python-numpy")))
                ;; Patch meson.build to use the correct numpy include path
                (substitute* "meson.build"
                  (("np_inc = include_directories\\(py\\.get_path\\('platlib'\\) / 'numpy/core/include'\\)")
                   (string-append "np_inc = include_directories('"
                                  numpy "/lib/python3.11/site-packages/numpy/core/include')"))))))
          (add-before 'build 'fix-lazy-fixture
            (lambda _
              ;; Migrate from pytest-lazy-fixture to pytest-lazy-fixtures.
              ;; Add import and replace pytest.lazy_fixture with lf.
              (for-each
               (lambda (file)
                 (substitute* file
                   (("^import pytest" all)
                    (string-append "from pytest_lazy_fixtures import lf\n" all))
                   (("pytest\\.lazy_fixture")
                    "lf")))
               (find-files "tests_and_analysis" "\\.py$"))))
          ;; Run tests after install so the C extension is available.
          (delete 'check)
          (add-after 'install 'check
            (lambda* (#:key tests? inputs outputs #:allow-other-keys)
              (when tests?
                (add-installed-pythonpath inputs outputs)
                ;; Remove source euphonic dir so tests use installed package.
                (delete-file-recursively "euphonic")
                (invoke "pytest" "-vv" "tests_and_analysis")))))))
    (propagated-inputs
     (list python-brille ; optional
           python-h5py ; optional, for phonopy-reader
           python-matplotlib ; optional
           python-pyyaml ; optional, for phonopy-reader
           python-numpy
           python-scipy
           python-pint
           python-seekpath
           python-spglib
           python-threadpoolctl
           python-toolz))
    (native-inputs
     ;; Note: build-backend is mesonpy.
     (list meson-python ninja python-numpy python-packaging python-pytest
           python-pytest-lazy-fixtures python-pytest-mock
           pkg-config))
    (home-page "https://github.com/pace-neutrons/Euphonic")
    (synopsis "Phonon calculations for inelastic neutron scattering")
    (description
     "Euphonic is a Python package for calculating phonon bandstructures and
simulating inelastic neutron scattering (INS) from force constants.  It can
read output from CASTEP and Phonopy and calculate phonon frequencies,
eigenvectors, and structure factors.")
    (license license:gpl3+)))
