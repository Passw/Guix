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
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages machine-learning)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages ninja)
  #:use-module (gnu packages noweb)
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

(define-public python-mslice
  (package
    (name "python-mslice")
    (version "2.14")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/mantidproject/mslice.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1bbg9hyl6jxyk79hshvqvcbwbx48x6va5nyhavj5kjg6ybd0n8fd"))
       (patches
        (search-patches "python-mslice-matplotlib-3.6-compatibility.patch"))))
    (build-system pyproject-build-system)
    (arguments
     (list #:tests? #f                    ;require mantid
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'fix-compatibility
                 (lambda _
                   ;; dedent_interpd was an alias for interpd; the alias was
                   ;; removed in
                   ;; <https://github.com/matplotlib/matplotlib/pull/28826>.
                   (substitute* "src/mslice/plotting/pyplot.py"
                     (("@_docstring\\.dedent_interpd")
                      "@_docstring.interpd"))
                   ;; self.execute("cls") fails; use widget's clear() method.
                   ;; <https://github.com/mantidproject/mslice/issues/1152>
                   (substitute* "src/mslice/widgets/ipythonconsole/ipython_widget.py"
                     (("self\\.execute\\(\"cls\"\\)")
                      "self.clear()"))))
               (delete 'sanity-check))))  ;would require mantid
    (propagated-inputs (list python-matplotlib python-pyqt python-qtpy
                             python-qtawesome))
    (native-inputs (list python-pytest python-setuptools))
    (home-page "https://github.com/mantidproject/mslice")
    (synopsis "Performs slices and cuts of multi-dimensional data produced by Mantid")
    (description "This package provides a tool for performing slices and cuts
of multi-dimensional data produced by Mantid.")
    (license license:gpl3+)))

(define-public python-mvesuvio
  (package
    (name "python-mvesuvio")
    (version "0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/mantidproject/vesuvio")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1drpz41dfqlfbx9jpsgig6hv52ylxs79ghzk2a7m6109vbawksvw"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:tests? #f  ; tests require mantid
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-version
            (lambda _
              ;; versioningit needs git tags; set version via environment
              ;; variable and create _version.py directly.
              (mkdir-p "src/mvesuvio")
              (call-with-output-file "src/mvesuvio/_version.py"
                (lambda (port)
                  (format port "__version__ = \"~a\"~%" #$version))))))))
    (native-inputs
     (list python-setuptools))
    (propagated-inputs
     (list python-dill
           python-iminuit
           python-jacobi))
    (home-page "https://github.com/mantidproject/vesuvio")
    (synopsis "Analysis library for VESUVIO neutron spectrometer data")
    (description
     "MVesuvio provides optimized analysis procedures for neutron scattering
data from the VESUVIO spectrometer.  It is a script library meant to be
imported in Mantid Workbench's script editor (@code{import mvesuvio as mv}),
not a GUI application.")
    (license license:gpl3)))

(define-public python-pycifrw
  (package
    (name "python-pycifrw")
    (version "4.4.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/jamesrhester/pycifrw.git")
             (commit version)))
       (sha256
        (base32 "0xda4vgm6dz6fhhrfv8y6igsc5kznlnv0j3yrwkbcd3qqv16ic6r"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'build 'generate-sources
            (lambda _
              (invoke "make" "-C" "src" "PYTHON=python3" "package")
              (invoke "make" "-C" "src/drel" "PYTHON=python3" "package")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "python3" "TestPyCIFRW.py")))))))
    (propagated-inputs
     (list python-numpy python-ply))
    (native-inputs
     (list latex2html noweb python-setuptools))
    (home-page "https://github.com/jamesrhester/pycifrw")
    (synopsis "CIF file reader and writer")
    (description
     "PyCifRW provides support for reading and writing CIF (Crystallographic
Information File) format files.  CIF is the standard format for
crystallographic data exchange endorsed by the International Union of
Crystallography.")
    (license license:psfl)))

(define-public python-pyoncat
  (package
    (name "python-pyoncat")
    (version "2.4")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "pyoncat" version))
       (sha256
        (base32 "16lkpbkn7wyx8ag42sjmqm0c5acfs5dbglf3ahnfwpvcgcxj6jql"))))
    (build-system pyproject-build-system)
    (arguments
     (list #:tests? #f  ; no tests in sdist
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'fix-build-system
                 (lambda _
                   ;; Upstream uses the deprecated poetry.masonry.api build
                   ;; backend which requires the full poetry package.  Guix
                   ;; only has poetry-core, so switch to poetry.core.masonry.api.
                   (substitute* "pyproject.toml"
                     (("requires = \\[\"poetry\"\\]")
                      "requires = [\"poetry-core\"]")
                     (("build-backend = \"poetry\\.masonry\\.api\"")
                      "build-backend = \"poetry.core.masonry.api\"")))))))
    (native-inputs
     (list python-poetry-core))
    (propagated-inputs
     (list python-oauthlib
           python-requests
           python-requests-oauthlib))
    (home-page "https://oncat.ornl.gov")
    (synopsis "Python client for ONCat (ORNL Neutron Catalog)")
    (description
     "This package provides a Python client for ONCat, the Oak Ridge National
Laboratory Neutron Catalog.  ONCat is a data catalog service for neutron
scattering facilities.")
    (license license:expat)))

(define-public python-pyoncatqt
  (package
    (name "python-pyoncatqt")
    (version "1.2.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/neutrons/pyoncatqt")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1wdzff1jn2jv742qm7g728yzp7axgf7nrizm5hms2w796a1zdqwv"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:tests? #f  ; tests require mantid
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
              (mkdir-p "src/pyoncatqt")
              (call-with-output-file "src/pyoncatqt/_version.py"
                (lambda (port)
                  (format port "__version__ = \"~a\"~%" #$version))))))))
    (native-inputs
     (list python-hatchling))
    (propagated-inputs
     (list python-oauthlib
           python-pyoncat
           python-qtpy))
    (home-page "https://github.com/neutrons/pyoncatqt")
    (synopsis "Qt GUI elements for ONCat authentication")
    (description
     "This package provides common Qt GUI elements for authenticating with
ONCat (ORNL Neutron Catalog), including login dialogs and session management
widgets.")
    (license license:gpl3)))

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

(define-public python-quickbayes
  (package
    (name "python-quickbayes")
    (version "1.0.2")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "quickbayes" version))
       (sha256
        (base32 "1w3w612cz92bkxjk2wyfcjf502vgp45ajpz92llk1d0z8q1pdn49"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:test-flags
      ;; Upstream runs two test configurations (see .github/workflows/run_tests.yml):
      ;; - without gofit: test/default and test/shared
      ;; - with gofit: test/gofit and test/shared
      ;; Since we have gofit, run the gofit configuration.
      #~(list "test/gofit" "test/shared")))
    (propagated-inputs
     (list python-joblib python-numpy python-scipy))
    (native-inputs
     (list python-hatchling python-pytest python-gofit))
    (home-page "https://quickbayes.readthedocs.io/")
    (synopsis "Bayesian analysis tools for neutron scattering")
    (description
     "QuickBayes provides Bayesian analysis tools for analyzing neutron
scattering data.  It is designed for use with the Mantid framework for
neutron and muon data analysis.")
    (license license:bsd-3)))

(define-public python-shiver
  (package
    (name "python-shiver")
    (version "1.8.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/neutrons/Shiver")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "05bxn1wqqylixzkk4is9nqkcsxfiix46s8m18db4c1zj7kkjawwv"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:tests? #f  ; tests require mantid
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
              (mkdir-p "src/shiver")
              (call-with-output-file "src/shiver/_version.py"
                (lambda (port)
                  (format port "__version__ = \"~a\"~%" #$version))))))))
    (native-inputs
     (list python-hatchling))
    (propagated-inputs
     (list python-configupdater
           python-pyoncatqt
           python-qtpy))
    (home-page "https://github.com/neutrons/Shiver")
    (synopsis "Spectroscopy histogram visualizer for neutron event reduction")
    (description
     "Shiver (Spectroscopy Histogram Visualizer for Event Reduction) is a
desktop application for examining Time of Flight inelastic neutron data from
single crystal, direct geometry experiments.  It integrates with Mantid
Workbench and appears in the Interfaces menu when both packages are
installed.")
    (license license:gpl3)))

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
    (version "1.5.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/pace-neutrons/Euphonic.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "18l5chzk6qhggxsgkqqidxx2nr4piziabvirw05v43kqm9awjfww"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'build 'fix-numpy-include
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((numpy (assoc-ref inputs "python-numpy"))
                     (site (site-packages inputs `(("out" . ,numpy)))))
                (substitute* "meson.build"
                  (("np_inc = include_directories\\(py\\.get_path\\('platlib'\\) / 'numpy/core/include'\\)")
                   (string-append "np_inc = include_directories('"
                                  numpy site "/numpy/core/include')"))))))
          (add-before 'check 'delete-source
            (lambda _
              (delete-file-recursively "euphonic"))))))
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
