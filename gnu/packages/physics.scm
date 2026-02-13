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
  #:use-module (guix build-system pyproject)
  #:use-module ((guix build-system python) #:select (pypi-uri))
  #:use-module (guix build-system qt)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages maths)
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
