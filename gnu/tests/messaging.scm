;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2017, 2018 Clément Lassieur <clement@lassieur.org>
;;; Copyright © 2017-2018, 2021-2022 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2018 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2025 Maxim Cournoyer <maxim.cournoyer@gmail.com>
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

(define-module (gnu tests messaging)
  #:use-module (gnu tests)
  #:use-module (gnu system)
  #:use-module (gnu system vm)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services messaging)
  #:use-module (gnu services networking)
  #:use-module (gnu services ssh)
  #:use-module (gnu packages irc)
  #:use-module (gnu packages messaging)
  #:use-module (gnu packages screen)
  #:use-module (guix gexp)
  #:use-module (guix store)
  #:use-module (guix modules)
  #:export (%test-prosody
            %test-bitlbee
            %test-ngircd
            %test-quassel))

(define (run-xmpp-test name xmpp-service pid-file create-account)
  "Run a test of an OS running XMPP-SERVICE, which writes its PID to PID-FILE."
  (define os
    (marionette-operating-system
     (simple-operating-system (service dhcp-client-service-type)
                              xmpp-service)
     #:imported-modules '((gnu services herd))))

  (define port 15222)

  (define vm
    (virtual-machine
     (operating-system os)
     (port-forwardings `((,port . 5222)))))

  (define username "alice")
  (define server "localhost")
  (define jid (string-append username "@" server))
  (define password "correct horse battery staple")
  (define message "hello world")
  (define witness "/tmp/freetalk-witness")

  (define script.ft
    (scheme-file
     "script.ft"
     #~(begin
         (define (handle-received-message time from nickname message)
           (define (touch file-name)
             (call-with-output-file file-name (const #t)))
           (when (equal? message #$message)
             (touch #$witness)))
         (add-hook! ft-message-receive-hook handle-received-message)

         (ft-set-jid! #$jid)
         (ft-set-password! #$password)
         (ft-set-server! #$server)
         (ft-set-port! #$port)
         (ft-set-sslconn! #f)
         (ft-connect-blocking)
         (ft-send-message #$jid #$message)

         (ft-set-daemon)
         (ft-main-loop))))

  (define test
    (with-imported-modules '((gnu build marionette))
      #~(begin
          (use-modules (gnu build marionette)
                       (srfi srfi-64))

          (define marionette
            (make-marionette (list #$vm)))

          (define (host-wait-for-file file)
            ;; Wait until FILE exists in the host.
            (let loop ((i 60))
              (cond ((file-exists? file)
                     #t)
                    ((> i 0)
                     (begin
                       (sleep 1))
                     (loop (- i 1)))
                    (else
                     (error "file didn't show up" file)))))

          (test-runner-current (system-test-runner #$output))
          (test-begin "xmpp")

          ;; Wait for XMPP service to be up and running.
          (test-assert "service running"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'xmpp-daemon))
             marionette))

          ;; Check XMPP service's PID.
          (test-assert "service process id"
            (let ((pid (number->string (wait-for-file #$pid-file
                                                      marionette))))
              (marionette-eval `(file-exists? (string-append "/proc/" ,pid))
                               marionette)))

          ;; Alice sends an XMPP message to herself, with Freetalk.
          (test-assert "client-to-server communication"
            (let ((freetalk-bin (string-append #$freetalk "/bin/freetalk")))
              (marionette-eval '(system* #$create-account #$jid #$password)
                               marionette)
              ;; Freetalk requires write access to $HOME.
              (setenv "HOME" "/tmp")
              (system* freetalk-bin "-s" #$script.ft)
              (host-wait-for-file #$witness)))

          (test-end))))

  (gexp->derivation name test))

(define %create-prosody-account
  (program-file
   "create-account"
   #~(begin
       (use-modules (ice-9 match))
       (match (command-line)
         ((command jid password)
          (let ((password-input (format #f "\"~a~%~a\"" password password))
                (prosodyctl #$(file-append prosody "/bin/prosodyctl")))
            (system (string-join
                     `("echo" ,password-input "|" ,prosodyctl "adduser" ,jid)
                     " "))))))))

(define %test-prosody
  (let* ((config (prosody-configuration
                  (insecure-sasl-mechanisms '())
                  (virtualhosts
                   (list
                    (virtualhost-configuration
                     (domain "localhost")))))))
    (system-test
     (name "prosody")
     (description "Connect to a running Prosody daemon.")
     (value (run-xmpp-test name
                           (service prosody-service-type config)
                           (prosody-configuration-pidfile config)
                           %create-prosody-account)))))


;;;
;;; BitlBee.
;;;

(define (run-bitlbee-test)
  (define os
    (marionette-operating-system
     (simple-operating-system (service dhcp-client-service-type)
                              (service bitlbee-service-type
                                       (bitlbee-configuration
                                        (interface "0.0.0.0"))))
     #:imported-modules (source-module-closure
                         '((gnu services herd)))))

  (define vm
    (virtual-machine
     (operating-system os)
     (port-forwardings `((6667 . 6667)))))

  (define test
    (with-imported-modules '((gnu build marionette))
      #~(begin
          (use-modules (ice-9 rdelim)
                       (srfi srfi-64)
                       (gnu build marionette))

          (define marionette
            (make-marionette (list #$vm)))

          (test-runner-current (system-test-runner #$output))
          (test-begin "bitlbee")

          (test-assert "service started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (start-service 'bitlbee))
             marionette))

          (test-assert "connect"
            (let* ((address (make-socket-address AF_INET INADDR_LOOPBACK
                                                 6667))
                   (sock    (socket AF_INET SOCK_STREAM 0)))
              (connect sock address)
              ;; See <https://tools.ietf.org/html/rfc1459>.
              (->bool (string-contains (pk 'message (read-line sock))
                                       "BitlBee"))))

          (test-end))))

  (gexp->derivation "bitlbee-test" test))

(define %test-bitlbee
  (system-test
   (name "bitlbee")
   (description "Connect to a BitlBee IRC server.")
   (value (run-bitlbee-test))))


;;;
;;; ngIRCd.
;;;

(define %ngircd-os
  (operating-system
    (inherit %simple-os)
    (packages (cons* ii screen %base-packages))
    (services
     (cons*
      (service dhcp-client-service-type)
      ;; For ease of debugging.  Run the vm with:
      ;; '-nic user,model=virtio-net-pci,hostfwd=tcp::10022-:22'
      (service openssh-service-type
               (openssh-configuration
                (permit-root-login #t)
                (allow-empty-passwords? #t)))
      (service ngircd-service-type
               (ngircd-configuration
                (debug? #t)
                (global
                 (ngircd-global
                  (server-uid 990)
                  (server-gid 990)))
                ;; There is no need to serialize the following sections, which
                ;; are all optional, but include them anyway to test the
                ;; serializers.
                (limits (ngircd-limits))
                (options (ngircd-options))
                (ssl (ngircd-ssl))
                (operators (list (ngircd-operator
                                  (name "apteryx")
                                  (password "1234"))))
                (channels
                 (list (ngircd-channel
                        (name "#guix")
                        (topic "GNU Guix | https://guix.gnu.org"))))))
      %base-services))))

(define (run-ngircd-test)
  (define vm
    (virtual-machine
     (operating-system
       (marionette-operating-system
        %ngircd-os
        #:imported-modules (source-module-closure
                            '((gnu build dbus-service)
                              (guix build utils)
                              (gnu services herd)))))))

  (define test
    (with-imported-modules '((gnu build marionette))
      #~(begin
          (use-modules (srfi srfi-64)
                       (gnu build marionette))

          (define marionette
            (make-marionette (list #$vm)))

          (test-runner-current (system-test-runner #$output))
          (test-begin "ngircd")

          (test-assert "ngircd service runs"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (wait-for-service 'ngircd))
             marionette))

          (test-assert "ngircd listens on TCP port 6667"
            (wait-for-tcp-port 6667 marionette))

          (test-assert "basic irc operations function as expected"
            (marionette-eval
             '(begin
                (use-modules ((gnu build dbus-service) #:select (with-retries))
                             (ice-9 textual-ports))

                (define (write-command command)
                  (call-with-output-file "in"
                    (lambda (port)
                      (display (string-append command "\n") port))))

                (define (grep-output text)
                  (with-retries 5 1     ;retry for 5 seconds
                    (string-contains (call-with-input-file "out" get-string-all)
                                     text)))

                (unless (zero? (system "ii -s localhost -i /tmp &"))
                  (error "error connecting to irc server"))

                (with-retries 5 1
                  (chdir "/tmp/localhost")) ;move to FIFO directory

                (write-command "/join #guix")
                (grep-output "GNU Guix | https://guix.gnu.org")

                (write-command "/oper apteryx 1234")
                (grep-output "+o"))
             marionette))

          (test-end))))

  (gexp->derivation "ngircd-test" test))

(define %test-ngircd
  (system-test
   (name "ngircd")
   (description "Connect to a ngircd IRC server.")
   (value (run-ngircd-test))))


;;;
;;; Quassel.
;;;

(define (run-quassel-test)
  (define os
    (marionette-operating-system
      (simple-operating-system (service dhcp-client-service-type)
                               (service quassel-service-type))
     #:imported-modules (source-module-closure
                         '((gnu services herd)))))

  (define vm
    (virtual-machine
      (operating-system os)
      (port-forwardings `((4242 . 4242)))))

  (define test
    (with-imported-modules '((gnu build marionette))
      #~(begin
          (use-modules (srfi srfi-64)
                       (gnu build marionette))

          (define marionette
            (make-marionette (list #$vm)))

          (test-runner-current (system-test-runner #$output))
          (test-begin "quassel")

          (test-assert "service started"
            (marionette-eval
             '(begin
                (use-modules (gnu services herd))
                (wait-for-service 'quassel))
             marionette))

          (test-assert "certificate file"
            (marionette-eval
              '(file-exists? "/var/lib/quassel/quasselCert.pem")
              marionette))

          (test-end))))

  (gexp->derivation "quassel-test" test))

(define %test-quassel
  (system-test
   (name "quassel")
   (description "Connect to a quassel IRC server.")
   (value (run-quassel-test))))
