;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2017, 2019, 2021, 2024 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2022, 2024 Maxim Cournoyer <maxim.cournoyer@gmail.com>
;;; Copyright © 2022 Hartmut Goebel <h.goebel@crazy-compilers.com>
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

(define-module (guix import gnome)
  #:use-module ((guix import utils) #:select (find-version))
  #:use-module (guix upstream)
  #:use-module (guix packages)
  #:use-module (guix http-client)
  #:use-module (guix diagnostics)
  #:use-module (guix i18n)
  #:use-module (json)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-34)
  #:use-module (web uri)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:export (%gnome-updater))

;;; Commentary:
;;;
;;; This package provides not an actual importer but simply an updater for
;;; GNOME packages.  It grabs package meta-data from 'cache.json' files
;;; available on ftp.gnome.org.
;;;
;;; Code:

(define (jsonish->upstream-source name jsonish)
  "Return an <upstream-source> object for package NAME, using JSONISH as the
source for metadata."
  (match jsonish
    ((version . dictionary)
     (upstream-source
      (package name)
      (version version)
      (urls (filter-map (lambda (extension)
                          (match (assoc-ref dictionary extension)
                            (#f
                             #f)
                            ((? string? relative-url)
                             (string-append "mirror://gnome/sources/"
                                            name "/" relative-url))))
                        '("tar.lz" "tar.xz" "tar.bz2" "tar.gz")))))))

(define* (import-gnome-release package #:key version partial-version?)
  "Return the latest release of PACKAGE, a GNOME package, or #f if it could
not be determined. Optionally include a VERSION string to fetch a specific
version, which may be partial if PARTIAL-VERSION? is #t."
  (define %not-dot
    (char-set-complement (char-set #\.)))

  (define (pre-release-text? text)
    (string-match "^(alpha|beta|rc)" text))

  (define (release-version? version)
    "Predicate to check if VERSION matches the format of a GNOME release
version.  A release version can have more than one form, depending on the
GNOME component, but typically it takes the form of a major-minor tuple, where
minor can also be prefixed with \"alpha\", \"beta\" or \"rc\".  For more
information about the GNOME versioning scheme, see:
https://discourse.gnome.org/t/new-gnome-versioning-scheme/4235"
    (define components (string-tokenize version %not-dot))
    (if (any pre-release-text? components)
        #f                              ;ignore pre-releases
        (match components
          (((= string->number major) (= string->number minor) . _)
           ;; Any other 3+ components versions such as "2.72.2".
           (and major minor))
          (((= string->number major) . _)
           ;; A GNOME version strings like "42.1".
           major))))

  (define upstream-name
    ;; Some packages like "NetworkManager" have camel-case names.
    (package-upstream-name package))

  (guard (c ((http-get-error? c)
             (unless (= 404 (http-get-error-code c))
               (warning (G_ "failed to download from '~a': ~a (~s)~%")
                        (uri->string (http-get-error-uri c))
                        (http-get-error-code c)
                        (http-get-error-reason c)))
             #f))
    (let* ((port (http-fetch/cached
                  (string->uri (string-append
                                "https://ftp.gnome.org/pub/gnome/sources/"
                                upstream-name "/cache.json"))

                  ;; ftp.gnome.org supports 'if-Modified-Since', so the local
                  ;; cache can expire early.
                  #:ttl (* 60 10)

                  ;; Hide messages about URL redirects.
                  #:log-port (%make-void-port "w")))
           (json (json->scm port)))
      (close-port port)
      (match json
        (#(4 releases _ ...)
         (let* ((releases (assoc-ref releases upstream-name))
                (all-versions (map car releases))
                (release-versions (filter release-version? all-versions))
                (version (or (find-version release-versions
                                           version partial-version?)
                             (and version
                                  ;; If the user-provided VERSION could not be
                                  ;; found, fallback to look through all
                                  ;; versions.
                                  (find-version all-versions
                                                version partial-version?)))))
           (and version
                (jsonish->upstream-source
                 upstream-name
                 (find (compose (cut string=? version <>) car) releases)))))))))

(define %gnome-updater
  (upstream-updater
   (name 'gnome)
   (description "Updater for GNOME packages")
   (pred (url-prefix-predicate "mirror://gnome/"))
   (import import-gnome-release)))
