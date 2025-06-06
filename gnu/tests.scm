;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016-2020, 2022-2025 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2017 Mathieu Othacehe <m.othacehe@gmail.com>
;;; Copyright © 2017 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2021 Maxime Devos <maximedevos@telenet.be>
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

(define-module (gnu tests)
  #:use-module (guix gexp)
  #:use-module (guix diagnostics)
  #:use-module (guix records)
  #:use-module ((guix ui) #:select (warn-about-load-error))
  #:use-module (gnu bootloader)
  #:use-module (gnu bootloader grub)
  #:use-module (gnu system)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system shadow)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services shepherd)
  #:use-module (guix discovery)
  #:use-module (guix monads)
  #:use-module ((guix store) #:select (%store-monad store-parameterize))
  #:use-module ((guix utils)
                #:select (%current-system %current-target-system))
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9 gnu)
  #:use-module (ice-9 match)
  #:export (marionette-configuration
            marionette-configuration?
            marionette-configuration-device
            marionette-configuration-imported-modules
            marionette-configuration-requirements

            marionette-service-type
            marionette-operating-system
            marionette-program
            define-os-with-source

            %simple-os
            simple-operating-system
            operating-system-with-console-syslog

            system-test
            system-test?
            system-test-name
            system-test-value
            system-test-description
            system-test-location

            fold-system-tests
            all-system-tests))

;;; Commentary:
;;;
;;; This module provides the infrastructure to run operating system tests.
;;; The most important part of that is tools to instrument the OS under test,
;;; essentially allowing it to run in a virtual machine controlled by the host
;;; system--hence the name "marionette".
;;;
;;; Code:

(define %default-marionette-device
  ;; Default marionette device in the guest.
  "/dev/virtio-ports/org.gnu.guix.port.0")

(define-record-type* <marionette-configuration>
  marionette-configuration make-marionette-configuration
  marionette-configuration?
  (device           marionette-configuration-device ;string
                    (default %default-marionette-device))
  (imported-modules marionette-configuration-imported-modules
                    (default '()))
  (extensions       marionette-configuration-extensions
                    (default '())) ; list of packages
  (requirements     marionette-configuration-requirements ;list of symbols
                    (default '())))

;; Hack: avoid indenting code beyond column 80 in marionette-shepherd-service.
(define-syntax-rule (with-imported-modules-and-extensions imported-modules
                                                          extensions
                                                          gexp)
  (with-imported-modules imported-modules
    (with-extensions extensions
      gexp)))

(define* (marionette-program #:optional
                             (device %default-marionette-device)
                             (imported-modules '())
                             (extensions '()))
  "Return the program that runs the marionette REPL on DEVICE.  Ensure
IMPORTED-MODULES and EXTENSIONS are accessible from the REPL."
  (define code
    (with-imported-modules-and-extensions
        `((guix build utils)
          (guix build syscalls)
          ,@imported-modules)
        extensions
      #~(begin
          (use-modules (ice-9 match)
                       (ice-9 binary-ports))

          (define (self-quoting? x)
            (letrec-syntax ((one-of (syntax-rules ()
                                      ((_) #f)
                                      ((_ pred rest ...)
                                       (or (pred x)
                                           (one-of rest ...))))))
              (one-of symbol? string? keyword? pair? null? array?
                      number? boolean? char?)))

          (let ((repl    (open-file #$device "r+0"))
                (console (open-file "/dev/console" "r+0")))
            ;; Redirect output to the console.
            (close-fdes 1)
            (close-fdes 2)
            (dup2 (fileno console) 1)
            (dup2 (fileno console) 2)
            (close-port console)

            (display 'ready repl)
            (let loop ()
              (newline repl)

              (match (read repl)
                ((? eof-object?)
                 (primitive-exit 0))
                (expr
                 (catch #t
                   (lambda ()
                     (let ((result (primitive-eval expr)))
                       (write (if (self-quoting? result)
                                  result
                                  (object->string result))
                              repl)))
                   (lambda (key . args)
                     (print-exception (current-error-port)
                                      (stack-ref (make-stack #t) 1)
                                      key args)
                     (write #f repl)))))
              (loop))))))

  (program-file "marionette-repl.scm" code))

(define (marionette-shepherd-service config)
  "Return the Shepherd service for the marionette REPL"
  (match config
    (($ <marionette-configuration> device imported-modules extensions
                                   requirement)
     (list (shepherd-service
            (provision '(marionette))

            ;; Always depend on UDEV so that DEVICE is available.
            (requirement `(udev ,@requirement))

            (modules '((ice-9 match)
                       (srfi srfi-9 gnu)))
            (start #~(make-forkexec-constructor
                      (list #$(marionette-program device
                                                  imported-modules
                                                  extensions))))
            (stop #~(make-kill-destructor)))))))

(define marionette-service-type
  ;; This is the type of the "marionette" service, allowing a guest system to
  ;; be manipulated from the host.  This marionette REPL is essentially a
  ;; universal backdoor.
  (service-type (name 'marionette-repl)
                (extensions
                 (list (service-extension shepherd-root-service-type
                                          marionette-shepherd-service)))
                (description "The @dfn{marionette} service allows a guest
system (virtual machine) to be manipulated by the host.  It is used for system
tests.")))

(define* (marionette-operating-system os
                                      #:key
                                      (imported-modules '())
                                      (extensions '())
                                      (requirements '()))
  "Return a marionetteed variant of OS such that OS can be used as a
marionette in a virtual machine--i.e., controlled from the host system.  The
marionette service in the guest is started after the Shepherd services listed
in REQUIREMENTS.  The packages in the list EXTENSIONS are made available from
the backdoor REPL."
  (operating-system
    (inherit os)
    ;; Make sure the guest dies on error.
    (kernel-arguments (cons "panic=1"
                            (operating-system-user-kernel-arguments os)))
    ;; Make sure the guest doesn't hang in the REPL on error.
    (initrd (lambda (fs . rest)
              (apply (operating-system-initrd os) fs
                     #:on-error 'backtrace
                     rest)))
    (services (cons (service marionette-service-type
                             (marionette-configuration
                              (requirements requirements)
                              (extensions extensions)
                              (imported-modules imported-modules)))
                    (operating-system-user-services os)))))

(define-syntax define-os-with-source
  (syntax-rules (use-modules operating-system)
    "Define two variables: OS containing the given operating system, and
SOURCE containing the source to define OS as an sexp.

This is convenient when we need both the <operating-system> object so we can
instantiate it, and the source to create it so we can store in in a file in
the system under test."
    ((_ (os source)
        (use-modules modules ...)
        (operating-system fields ...))
     (begin
       (define os
         (operating-system fields ...))
       (define source
         '(begin
            (use-modules modules ...)
            (operating-system fields ...)))))))


;;;
;;; Simple operating systems.
;;;

(define %simple-os
  (operating-system
    (host-name "komputilo")
    (timezone "Europe/Berlin")
    (locale "en_US.UTF-8")

    (bootloader (bootloader-configuration
                 (bootloader grub-bootloader)
                 (targets '("/dev/sdX"))))
    (file-systems (cons (file-system
                          (device (file-system-label "my-root"))
                          (mount-point "/")
                          (type "ext4"))
                        %base-file-systems))
    (kernel-arguments (delete "quiet" %default-kernel-arguments))
    (firmware '())

    (users (cons (user-account
                  (name "alice")
                  (comment "Bob's sister")
                  (group "users")
                  (supplementary-groups '("wheel" "audio" "video")))
                 %base-user-accounts))))

(define-syntax-rule (simple-operating-system user-services ...)
  "Return an operating system that includes USER-SERVICES in addition to
%BASE-SERVICES."
  (operating-system (inherit %simple-os)
                    (services (cons* user-services ... %base-services))))


(define (operating-system-with-console-syslog os)
  "Return OS with a system log service that writes to /dev/console."
  (operating-system
    (inherit os)
    (services
     (modify-services (operating-system-user-services os)
       (shepherd-system-log-service-type
        config
        =>
        (system-log-configuration
         (inherit config)
         (message-destination
          #~(lambda (message)
              (let ((destinations ((default-message-destination-procedure)
                                   message)))
                (if (<= (system-log-message-priority message)
                        (system-log-priority info))
                    (cons "/dev/console" destinations)
                    destinations))))))))))


;;;
;;; Tests.
;;;

(define-record-type* <system-test> system-test make-system-test
  system-test?
  (name        system-test-name)                  ;string
  (value       system-test-value)                 ;%STORE-MONAD value
  (description system-test-description)           ;string
  (location    system-test-location (innate)      ;<location>
               (default (and=> (current-source-location)
                               source-properties->location))))

(define (write-system-test test port)
  (match test
    (($ <system-test> name _ _ ($ <location> file line))
     (format port "#<system-test ~a ~a:~a ~a>"
             name file line
             (number->string (object-address test) 16)))
    (($ <system-test> name)
     (format port "#<system-test ~a ~a>" name
             (number->string (object-address test) 16)))))

(set-record-type-printer! <system-test> write-system-test)

(define-gexp-compiler (compile-system-test (test <system-test>)
                                           system target)
  "Compile TEST to a derivation."
  (store-parameterize ((%current-system system)
                       (%current-target-system target))
      (system-test-value test)))

(define (test-modules)
  "Return the list of modules that define system tests."
  (scheme-modules (dirname (search-path %load-path "guix.scm"))
                  "gnu/tests"
                  #:warn warn-about-load-error))

(define (fold-system-tests proc seed)
  "Invoke PROC on each system test, passing it the test and the previous
result."
  (fold-module-public-variables (lambda (obj result)
                                  (if (system-test? obj)
                                      (cons obj result)
                                      result))
                                '()
                                (test-modules)))

(define (all-system-tests)
  "Return the list of system tests."
  (reverse (fold-system-tests cons '())))


;; Local Variables:
;; eval: (put 'with-imported-modules-and-extensions 'scheme-indent-function 2)
;; End:

;;; tests.scm ends here
