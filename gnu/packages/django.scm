;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 Hartmut Goebel <h.goebel@crazy-compilers.com>
;;; Copyright © 2016, 2019, 2020, 2021 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2017 Nikita <nikita@n0.is>
;;; Copyright © 2017, 2018, 2019 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2017, 2025 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2018 Vijayalakshmi Vedantham <vijimay12@gmail.com>
;;; Copyright © 2019 Sam <smbaines8@gmail.com>
;;; Copyright © 2020, 2021, 2022, 2023 Marius Bakke <marius@gnu.org>
;;; Copyright © 2021 Maxim Cournoyer <maxim.cournoyer@gmail.com>
;;; Copyright © 2021 Luis Felipe López Acevedo <luis.felipe.la@protonmail.com>
;;; Copyright © 2022 Pradana Aumars <paumars@courrier.dev>
;;; Copyright © 2025 Sharlatan Hellseher <sharlatanus@gmail.com>
;;; Copyright © 2025 Vinicius Monego <monego@posteo.net>
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

(define-module (gnu packages django)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix build-system pyproject)
  #:use-module (guix build-system python)
  #:use-module (guix deprecation)
  #:use-module (guix search-paths)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages check)
  #:use-module (gnu packages finance)
  #:use-module (gnu packages geo)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages mail)
  #:use-module (gnu packages openldap)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-check)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages security-token)
  #:use-module (gnu packages sphinx)
  #:use-module (gnu packages time)
  #:use-module (gnu packages xml))

(define-public python-django-4.2
  (package
    (name "python-django")
    (version "4.2.16")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "Django" version))
              (sha256
               (base32
                "1b8xgwg3gjr974j60x3vgcpp85cg5dwhzqdpdbl8qh3cg311c5kg"))))
    (build-system pyproject-build-system)
    (arguments
     '(#:test-flags
       (list
        ;; By default tests run in parallel, which may cause various race
        ;; conditions.  Run sequentially for consistent results.
        "--parallel=1"
        ;; The test suite fails as soon as a single test fails.
        "--failfast")
       #:phases
       (modify-phases %standard-phases
         (add-before 'check 'pre-check
           (lambda* (#:key inputs #:allow-other-keys)
             ;; The test-suite tests timezone-dependent functions, thus tzdata
             ;; needs to be available.
             (setenv "TZDIR"
                     (search-input-directory inputs "share/zoneinfo"))

             ;; Disable test for incorrect timezone: it only raises the
             ;; expected error when /usr/share/zoneinfo exists, even though
             ;; the machinery gracefully falls back to TZDIR.  According to
             ;; django/conf/__init__.py, lack of /usr/share/zoneinfo is
             ;; harmless, so just ignore this test.
             (substitute* "tests/settings_tests/tests.py"
               ((".*def test_incorrect_timezone.*" all)
                (string-append "    @unittest.skip('Disabled by Guix')\n"
                               all)))))
         (replace 'check
           (lambda* (#:key tests? test-flags #:allow-other-keys)
             (if tests?
                 (with-directory-excursion "tests"
                   ;; Tests expect PYTHONPATH to contain the root directory.
                   (setenv "PYTHONPATH" "..")
                   (apply invoke "python" "runtests.py" test-flags))
                 (format #t "test suite not run~%"))))
         ;; XXX: The 'wrap' phase adds native inputs as runtime dependencies,
         ;; see <https://bugs.gnu.org/25235>.  The django-admin script typically
         ;; runs in an environment that has Django and its dependencies on
         ;; PYTHONPATH, so just disable the wrapper to reduce the size from
         ;; ~710 MiB to ~203 MiB.
         (delete 'wrap))))
    ;; TODO: Install extras/django_bash_completion.
    (native-inputs
     (list tzdata-for-tests
           ;; Remaining packages are test requirements taken from
           ;; tests/requirements/py3.txt
           python-docutils
           ;; optional for tests: python-geoip2
           ;; optional for tests: python-memcached
           python-numpy
           python-pillow
           python-pyyaml
           python-setuptools
           ;; optional for tests: python-selenium
           python-tblib
           python-wheel))
    (propagated-inputs
     (list python-asgiref
           python-sqlparse
           ;; Optional dependencies.
           python-argon2-cffi
           python-bcrypt
           ;; This input is not strictly required, but in practice many Django
           ;; libraries need it for test suites and similar.
           python-jinja2))
    (native-search-paths
     ;; Set TZDIR when 'tzdata' is available so that timezone functionality
     ;; works (mostly) out of the box in containerized environments.
     ;; Note: This search path actually belongs to 'glibc'.
     (list $TZDIR))
    (home-page "https://www.djangoproject.com/")
    (synopsis "High-level Python Web framework")
    (description
     "Django is a high-level Python Web framework that encourages rapid
development and clean, pragmatic design.  It provides many tools for building
any Web site.  Django focuses on automating as much as possible and adhering
to the @dfn{don't repeat yourself} (DRY) principle.")
    (license license:bsd-3)
    (properties `((cpe-name . "django")
                  ;; This CVE seems fixed since 4.2.1.
                  (lint-hidden-cve . ("CVE-2023-31047"))))))

;; archivebox requires django>=3.1.3,<3.2
(define-public python-django-3.1.14
  (package
    (inherit python-django-4.2)
    (version "3.1.14")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "Django" version))
              (sha256
               (base32
                "0ix3v2wlnplv78zxjrlw8z3hiap2d5mxvk0ny2fc65526shsb93j"))))
    (propagated-inputs
     (modify-inputs (package-propagated-inputs python-django-4.2)
       ;; Django 4.0 deprecated pytz in favor of Pythons built-in zoneinfo.
       (append python-pytz)))))

(define-public python-django python-django-4.2)

(define-public python-django-cache-url
  (package
    (name "python-django-cache-url")
    (version "3.4.5")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-cache-url" version))
              (sha256
               (base32
                "05yr19gi5ln6za0y9nf184klaixnf1dr1nfajn63893mf6ab37zb"))))
    (build-system pyproject-build-system)
    (native-inputs
     (list python-django python-setuptools python-wheel))
    (home-page "https://github.com/epicserve/django-cache-url")
    (synopsis "Configure Django cache settings from URLs")
    (description
     "This package provides a facility for configuring Django cache settings
with a @var{CACHE_URL} environment variable.")
    (license license:expat)))

(define-public python-django-configurations
  (package
    (name "python-django-configurations")
    (version "2.4.1")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-configurations" version))
              (sha256
               (base32
                "11chll26iqqy5chyx62hya20cadk10nm2la7sch7pril70a5rhm6"))))
    (build-system pyproject-build-system)
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (replace 'check
                 (lambda* (#:key tests? #:allow-other-keys)
                   (when tests?
                     ;; Taken from tox.ini.
                     (setenv "DJANGO_SETTINGS_MODULE" "tests.settings.main")
                     (setenv "DJANGO_CONFIGURATION" "Test")
                     (setenv "PYTHONPATH"
                             (string-append ".:" (getenv "GUIX_PYTHONPATH")))
                     (invoke "django-cadmin" "test" "-v2")))))))
    (propagated-inputs
     (list python-django))
    (native-inputs
     (list python-dj-database-url
           python-dj-email-url
           python-dj-search-url
           python-django-cache-url
           python-setuptools
           python-setuptools-scm
           python-wheel))
    (home-page "https://django-configurations.readthedocs.io/")
    (synopsis "Helper module for organizing Django settings")
    (description
     "@code{django-configurations} helps you organize the configuration of
your Django project by providing glue code to bridge between Django'smodule
based settings system and programming patterns like mixins, facades, factories
and adapters that are useful for non-trivial configuration scenarios.")
    (license license:bsd-3)))

(define-public python-django-extensions
  (package
    (name "python-django-extensions")
    (version "4.1")
    (source
     (origin
       (method git-fetch)
       ;; Fetch from the git repository, so that the tests can be run.
       (uri (git-reference
             (url "https://github.com/django-extensions/django-extensions")
             (commit version)))
       (file-name (string-append name "-" version))
       (sha256
        (base32 "1qayan9za7ylvzkwp6p0l0735gavnzd1kdjsfc178smq6xnby0ss"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      ;; The 5 tests in test_dumbscript.py fail (OperationalError).
      #:test-flags
      #~(list "--ignore" "tests/test_dumpscript.py"
              "-k" (string-append
                    ;; These fail for unknown reasons.
                    "not test_do_export_emails_format_vcard_start"
                    " and not test_initialize_runserver_plus"
                    " and not test_should_highlight_python_syntax_with_name"))))
    (propagated-inputs
     (list python-django))
    (native-inputs
     (list python-aiosmtpd
           python-factory-boy
           python-pygments
           python-pytest
           python-pytest-cov ; runs by default
           python-pytest-django
           python-setuptools-next
           python-shortuuid
           python-wheel))
    (home-page "https://github.com/django-extensions/django-extensions")
    (synopsis "Custom management extensions for Django")
    (description
     "Django-extensions extends Django providing, for example, management
commands, additional database fields and admin extensions.")
    (license license:expat)))

(define-public python-django-localflavor
  (package
    (name "python-django-localflavor")
    (version "3.1")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django-localflavor" version))
       (sha256
        (base32 "0i1s0ijfd9rv2cp5x174jcyjpwn7fyg7s1wpbvlwm96bpdvs6bxc"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:test-flags '(list "--settings=tests.settings" "tests")
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? test-flags #:allow-other-keys)
              (if tests?
                  (apply invoke "python" "-m" "django" "test" test-flags)
                  (format #t "test suite not run~%")))))))
    (native-inputs
     (list python-setuptools python-wheel))
    (propagated-inputs
     (list python-django python-stdnum))
    (home-page "https://django-localflavor.readthedocs.io/en/latest/")
    (synopsis "Country-specific Django helpers")
    (description "Django-LocalFlavor is a collection of assorted pieces of code
that are useful for particular countries or cultures.")
    (license license:bsd-3)))

(define-public python-django-simple-math-captcha
  (package
    (name "python-django-simple-math-captcha")
    (version "2.0.0")
    (home-page "https://github.com/alsoicode/django-simple-math-captcha")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url home-page)
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "1pqriqvg1bfx36p8hxzh47zl5qk911vgf3xaxfvhkjyi611rbxzy"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      '(modify-phases %standard-phases
         (add-after 'unpack 'compatibility
           (lambda _
             (substitute* "test_simplemathcaptcha/form_tests.py"
               (("label for=\"id_captcha_0\"") "label"))
             (substitute* "simplemathcaptcha/widgets.py"
               (("ugettext_lazy") "gettext_lazy"))))
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (invoke "python" "runtests.py")))))))
    (native-inputs
     (list python-mock python-setuptools python-wheel))
    (propagated-inputs
     (list python-django python-six))
    (synopsis "Easy-to-use math field/widget captcha for Django forms")
    (description
     "A multi-value-field that presents a human answerable question,
with no settings.py configuration necessary, but instead can be configured
with arguments to the field constructor.")
    (license license:asl2.0)))

(define-public python-django-classy-tags
  (package
    (name "python-django-classy-tags")
    (version "4.1.0")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "django-classy-tags" version))
        (sha256
         (base32
          "0ngffhbicyx1j0j0nxdvbg9bhs9ss88xvx3dhr6irrx65ymd3nf8"))))
    (build-system pyproject-build-system)
    (native-inputs
     (list python-setuptools
           python-wheel))
    (propagated-inputs
     (list python-django))
    (home-page "https://github.com/divio/django-classy-tags")
    (synopsis "Class based template tags for Django")
    (description
     "@code{django-classy-tags} is an approach at making writing template tags
in Django easier, shorter and more fun.  It provides an extensible argument
parser which reduces most of the boiler plate code you usually have to write
when coding custom template tags.")
    (license license:bsd-3)))

(define-public python-django-taggit
  (package
    (name "python-django-taggit")
    (version "6.1.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/jazzband/django-taggit")
             (commit version)))
       (sha256
        (base32
         "1i8an3wcl7nygl5f565jcpyhyws9gabawazggxpf6m3vklxn3cj0"))))
    (build-system pyproject-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (replace 'check
           (lambda _
             (invoke "python3" "-m" "django" "test" "--settings=tests.settings"))))))
    (propagated-inputs
     (list python-django))
    (native-inputs
     (list python-django-rest-framework
           python-setuptools
           python-wheel
           tzdata-for-tests))
    (home-page "https://github.com/jazzband/django-taggit")
    (synopsis "Reusable Django application for simple tagging")
    (description
     "Django-taggit is a reusable Django application for simple tagging.")
    (license license:bsd-3)))

(define-public python-easy-thumbnails
  (package
    (name "python-easy-thumbnails")
    (version "2.10")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "easy_thumbnails" version))
       (sha256
        (base32
         "1xafj3lh4841y960wq6lnw31lbki8k84dvg5jqjdy7krrlplc2fh"))))
    (build-system pyproject-build-system)
    (arguments
     (list #:test-flags '(list "--pyargs" "easy_thumbnails")))
    (propagated-inputs
     (list python-django python-pillow))
    (native-inputs
     (list python-pytest
           python-pytest-django
           python-setuptools
           python-testfixtures
           python-wheel))
    (home-page "https://github.com/SmileyChris/easy-thumbnails")
    (synopsis "Easy thumbnails for Django")
    (description
     "Easy thumbnails is a Django plugin to dynamically create thumbnails
based on source images.  Multiple thumbnails can be created from a single
source image, using different options to control parameters like the image
size and quality.")
    (license license:bsd-3)))

(define-public python-pytest-django
  (package
    (name "python-pytest-django")
    (version "4.11.1")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "pytest_django" version))
              (sha256
               (base32
                "14br4bzx07yxrx6xsyyhlpjgb0sz6lflbw90g87cn0z13qd18jd9"))))
    (build-system pyproject-build-system)
    (native-inputs
     (list python-django python-setuptools python-setuptools-scm python-wheel))
    (propagated-inputs
     (list python-pytest))
    (home-page "https://pytest-django.readthedocs.io/")
    (synopsis "Django plugin for py.test")
    (description "Pytest-django is a plugin for py.test that provides a set of
useful tools for testing Django applications and projects.")
    (license license:bsd-3)))

(define-public python-django-haystack
  (package
    (name "python-django-haystack")
    (version "3.3.0")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "django-haystack" version))
        (sha256
         (base32
          "1arfl0y34nfvpzwiib6859g9154qqvdb97j09nhmsqh0h1myvkp3"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (invoke "python" "test_haystack/run_tests.py"))))
         ;; Importing this module requires setting up a Django project.
         (delete 'sanity-check))))
    (propagated-inputs
     (list python-django python-packaging))
    ;; (inputs (list gdal)) ; it's optional, tests fail when provided
    (native-inputs
     (list python-coverage
           python-dateutil
           python-geopy
           python-pysolr
           python-requests
           python-setuptools
           python-setuptools-scm
           python-wheel
           python-whoosh))
    (home-page "https://haystacksearch.org/")
    (synopsis "Pluggable search for Django")
    (description "Haystack provides modular search for Django.  It features a
unified, familiar API that allows you to plug in different search backends
(such as Solr, Elasticsearch, Whoosh, Xapian, etc.) without having to modify
your code.")
    (license license:bsd-3)))

(define-public python-django-filter
  (package
    (name "python-django-filter")
    (version "25.1")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django_filter" version))
              (sha256
               (base32
                "0lvi82f3dnj89ip8hry8fq8w7x632r5p84dlr451rnm8izsfxj8y"))))
    (build-system pyproject-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (invoke "python" "runtests.py")))))))
    (native-inputs
     (list python-django
           python-django-rest-framework
           python-flit-core
           tzdata-for-tests))
    (home-page "https://django-filter.readthedocs.io/en/latest/")
    (synopsis "Reusable Django application to filter querysets dynamically")
    (description
     "Django-filter is a generic, reusable application to alleviate writing
some of the more mundane bits of view code.  Specifically, it allows users to
filter down a queryset based on a model’s fields, displaying the form to let
them do this.")
    (license license:bsd-3)))

(define-public python-django-allauth
  (package
    (name "python-django-allauth")
    (version "65.3.1")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django_allauth" version))
       (sha256
        (base32
         "11q56p07g987hsz7v27nrvr2piy72jhyzwjrcis3lxd2f4drabp0"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:test-flags
      ;; XXX: KeyError: location
      '(list "--ignore=allauth/socialaccount/providers/openid/tests.py")
      #:phases
      #~(modify-phases %standard-phases
          ;; FIXME: This should be fixed in python-xmlsec
          (add-before 'check 'pre-check
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "LD_LIBRARY_PATH"
                      (dirname (search-input-file inputs "lib/libxmlsec1-openssl.so.1.2.37"))))))))
    (propagated-inputs
     (list python-asgiref
           python-django
           python-fido2
           python-openid
           python-pyjwt
           python-qrcode
           python-requests
           python-requests-oauthlib
           python-python3-saml))
    (native-inputs
     (list tzdata-for-tests
           python-pytest
           python-pytest-django
           python-setuptools
           python-wheel))
    (home-page "https://github.com/pennersr/django-allauth")
    (synopsis "Set of Django applications addressing authentication")
    (description
     "Integrated set of Django applications addressing authentication,
registration, account management as well as 3rd party (social)
account authentication.")
    (license license:expat)))

(define-public python-django-debug-toolbar
  (package
    (name "python-django-debug-toolbar")
    (version "3.2.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/jazzband/django-debug-toolbar")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1m1j2sx7q0blma0miswj3c8hrfi5q4y5cq2b816v8gagy89xgc57"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      '(modify-phases %standard-phases
         (add-after 'unpack 'disable-bad-tests
           (lambda _
             (substitute* "tests/test_integration.py"
               (("def test_cache_page")
                "def _test_cache_page"))))
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (invoke "make" "test")))))))
    (propagated-inputs
     (list python-sqlparse python-django))
    (native-inputs
     (list python-django-jinja
           python-html5lib
           python-setuptools
           python-wheel
           tzdata-for-tests))
    (home-page "https://github.com/jazzband/django-debug-toolbar")
    (synopsis "Toolbar to help with developing Django applications")
    (description
     "This package provides a configurable set of panels that display
information about the current request and response as a toolbar on the
rendered page.")
    (license license:bsd-3)))

(define-public python-django-debug-toolbar-alchemy
  (package
    (name "python-django-debug-toolbar-alchemy")
    (version "0.1.5")
    (home-page "https://github.com/miki725/django-debug-toolbar-alchemy")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-debug-toolbar-alchemy" version))
              (sha256
               (base32
                "1kmpzghnsc247bc1dl22s4y62k9ijgy1pjms227018h5a4frsa5b"))))
    (build-system python-build-system)
    (arguments '(#:tests? #f))          ;XXX: 'make check' does "echo TODO"
    (propagated-inputs
     (list python-django python-django-debug-toolbar python-jsonplus
           python-six python-sqlalchemy))
    (synopsis "Django Debug Toolbar panel for SQLAlchemy")
    (description
     "This package completely mimics the default Django Debug Toolbar SQL
panel (internally it is actually subclassed), but instead of displaying
queries done via the Django ORM, SQLAlchemy generated queries are displayed.")
    (license license:expat)))

(define-public python-django-gravatar2
  (package
    (name "python-django-gravatar2")
    (version "1.4.5")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django-gravatar2" version))
       (sha256
        (base32
         "0r03m1qkh56g92x136xdq8n92mj7gbi1fh0djarxhp9rbr35dfrd"))))
    (build-system python-build-system)
    (arguments
     '(;; TODO: The django project for the tests is missing from the release.
       #:tests? #f))
    (inputs
     (list python-django))
    (home-page "https://github.com/twaddington/django-gravatar")
    (synopsis "Gravatar support for Django, improved version")
    (description
     "Essential Gravatar support for Django.  Features helper methods,
templatetags and a full test suite.")
    (license license:expat)))

(define-public python-django-assets
  (package
    (name "python-django-assets")
    (version "2.0")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-assets" version))
              (sha256
               (base32
                "0fc6i77faxxv1gjlp06lv3kw64b5bhdiypaygfxh5djddgk83fwa"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      '(modify-phases %standard-phases
         (add-after 'unpack 'disable-bad-tests
           (lambda _
             (substitute* "tests/test_django.py"
               (("bundles = self.loader.load_bundles\\(\\)")
                "return")))))))
    (native-inputs
     (list python-nose python-setuptools python-wheel))
    (propagated-inputs
     (list python-django python-webassets))
    (home-page "https://github.com/miracle2k/django-assets")
    (synopsis "Asset management for Django")
    (description
      "Asset management for Django, to compress and merge CSS and Javascript
files.  Integrates the webassets library with Django, adding support for
merging, minifying and compiling CSS and Javascript files.")
    (license license:bsd-2)))

(define-public python-django-jinja
  (package
    (name "python-django-jinja")
    (version "2.11.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/niwinz/django-jinja")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "17irzcwxm49iqyn3q2rpfncj41r6gywh938q9myfq7m733vjy2fj"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      '(modify-phases %standard-phases
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (with-directory-excursion "testing"
                 (invoke "python" "runtests.py"))))))))
    (propagated-inputs
     (list python-django python-jinja2 python-pytz python-django-pipeline))
    (native-inputs
     (list python-setuptools python-wheel tzdata-for-tests))
    (home-page "https://niwinz.github.io/django-jinja/latest/")
    (synopsis "Simple jinja2 templating backend for Django")
    (description
     "This package provides a templating backend for Django, using Jinja2.  It
provides certain advantages over the builtin Jinja2 backend in Django, for
example, explicit calls to callables from templates and better performance.")
    (license license:bsd-3)))

(define-public python-dj-database-url
  (package
    (name "python-dj-database-url")
    (version "3.0.1")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "dj_database_url" version))
              (sha256
               (base32
                "1y7ghizjni3imbmqh63mra8pcvqzr5q0hma1ijzwd3w8zcg9d549"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-pytest python-setuptools python-wheel))
    (propagated-inputs
     (list python-django))
    (home-page "https://github.com/jazzband/dj-database-url")
    (synopsis "Use Database URLs in your Django Application")
    (description
      "This simple Django utility allows you to utilize the 12factor inspired
DATABASE_URL environment variable to configure your Django application.

The dj_database_url.config method returns a Django database connection
dictionary, populated with all the data specified in your URL.  There is also a
conn_max_age argument to easily enable Django’s connection pool.")
    (license license:bsd-3)))

(define-public python-dj-email-url
  (package
    (name "python-dj-email-url")
    (version "1.0.6")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "dj-email-url" version))
              (sha256
               (base32
                "16k91rvd9889xxrrf84a3zb0jpinizhfqdmafn54zxa8kqrf7zsm"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-setuptools python-wheel))
    (home-page "https://github.com/migonzalvar/dj-email-url")
    (synopsis "Configure email settings from URLs")
    (description
     "This package provides a facility for configuring Django email backend
settings from URLs.")
    (license (list license:bsd-2        ;source code
                   license:cc-by4.0     ;documentation
                   license:cc0))))      ;configuration and data

(define-public python-dj-search-url
  (package
    (name "python-dj-search-url")
    (version "0.1")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "dj-search-url" version))
              (sha256
               (base32
                "0h7vshhglym6af2pplkyivk6y0g0ncq0xpdzi88kq2sha9c1lka2"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-setuptools python-wheel))
    (home-page "https://github.com/dstufft/dj-search-url")
    (synopsis "Configure Haystack search from URLs")
    (description
     "This package provides a facility for configuring Django Haystack
applications with a @var{SEARCH_URL} variable.")
    (license license:bsd-2)))

(define-public python-django-picklefield
  (package
    (name "python-django-picklefield")
    (version "3.3.0")
    (source
      (origin
        (method git-fetch) ; no tests in PyPI
        (uri (git-reference
              (url "https://github.com/gintas/django-picklefield")
              (commit (string-append "v" version))))
        (file-name (git-file-name name version))
        (sha256
         (base32
          "19qiyb3i9s72qanxzrgy1a10707138zq8sclhdfn4zpnqykaqzpw"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases #~(modify-phases %standard-phases
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         (invoke "python" "-m" "django" "test" "-v2"
                                 "--settings=tests.settings")))))))
    (native-inputs (list python-setuptools python-wheel))
    (propagated-inputs (list python-django))
    (home-page "https://github.com/gintas/django-picklefield")
    (synopsis "Pickled object field for Django")
    (description "Pickled object field for Django")
    (license license:expat)))

(define-public python-django-bulk-update
  (package
    (name "python-django-bulk-update")
    (version "2.2.0")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-bulk-update" version))
              (sha256
               (base32
                "0dxkmrm3skyw82i0qa8vklxw1ma1y308kh9w2hcnvhpacn5cxdss"))))
    (build-system python-build-system)
    (arguments
     ;; XXX: Tests require a Postgres database.
     `(#:tests? #f))
    (propagated-inputs
     (list python-django))
    (home-page "https://github.com/aykut/django-bulk-update")
    (synopsis "Simple bulk update over Django ORM or with helper function")
    (description
      "Simple bulk update over Django ORM or with helper function.  This
project aims to bulk update given objects using one query over Django ORM.")
    (license license:expat)))

(define-public python-django-contact-form
  (package
    (name "python-django-contact-form")
    (version "5.2.0")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django_contact_form" version))
              (sha256
               (base32
                "091nji94c6d2n8zfpsfhwdv417ligi1hfwr4vvydbggf3s4q392n"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases #~(modify-phases %standard-phases
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         ;; This file contains a single test that requires
                         ;; python-akismet (not yet packaged).
                         (delete-file "tests/test_akismet_integration.py")
                         (setenv "DJANGO_SETTINGS_MODULE" "tests.test_settings")
                         (invoke "django-admin" "test" "--pythonpath=.")))))))
    (native-inputs
     (list python-pdm-backend python-tzdata))
    (propagated-inputs
     (list python-django))
    (home-page "https://github.com/ubernostrum/django-contact-form")
    (synopsis "Contact form for Django")
    (description
      "This application provides simple, extensible contact-form functionality
for Django sites.")
    (license license:bsd-3)))

(define-public python-django-contrib-comments
  (package
    (name "python-django-contrib-comments")
    (version "1.9.2")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-contrib-comments" version))
              (sha256
               (base32
                "0ccdiv784a5vnpfal36km4dyg12340rwhpr0riyy0k89wfnjn8yi"))))
    (build-system python-build-system)
    (propagated-inputs
     (list python-django python-six))
    (home-page "https://github.com/django/django-contrib-comments")
    (synopsis "Comments framework")
    (description
      "Django used to include a comments framework; since Django 1.6 it's been
separated to a separate project.  This is that project.  This framework can be
used to attach comments to any model, so you can use it for comments on blog
entries, photos, book chapters, or anything else.")
    (license license:bsd-3)))

(define-public python-django-ninja
  (package
    (name "python-django-ninja")
    (version "1.4.3")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django_ninja" version))
              (sha256
               (base32
                "0f5hgjkavvk1csb1yl34scqai3ljjhh93k5kbqm8s8hclry4fvg4"))))
    (build-system pyproject-build-system)
    (propagated-inputs
     (list python-django python-pydantic-2))
    (native-inputs
     (list python-flit-core
           python-psycopg2
           python-pytest
           python-pytest-asyncio
           python-pytest-django))
    (home-page "https://django-ninja.rest-framework.com")
    (synopsis "REST framework for Django")
    (description
     "Django Ninja is a web framework for building APIs with Django
and Python type hints.  It is designed to be fast and easy to use thanks
to asyncio and Pydantic.")
    (license license:expat)))

(define-public python-django-htmx
  (package
    (name "python-django-htmx")
    (version "1.23.2")
    (source (origin
              (method git-fetch) ; PyPI does not include settings.py for tests
              (uri (git-reference
                    (url "https://github.com/adamchainz/django-htmx")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0gr6zahrqvx8sjsy7wr1k7rgavz7bjx32kky4900gff70wrqbmvy"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "DJANGO_SETTINGS_MODULE" "tests.settings")
                (invoke "django-admin" "test" "tests"
                        "--pythonpath=.")))))))
    (propagated-inputs (list python-asgiref python-django))
    (native-inputs (list python-pytest python-setuptools-next python-wheel))
    (home-page "https://django-htmx.readthedocs.io/en/latest/")
    (synopsis "Extensions for using Django with htmx")
    (description "This package provides a Django extension to work with
@url{https://htmx.org/,htmx}.")
    (license license:expat)))

(define-public python-django-pipeline
  (package
    (name "python-django-pipeline")
    (version "4.0.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django_pipeline" version))
       (sha256
        (base32
         "125wkgi3hf1ly34ps7n63k6agb067h17ngxyf9xjykn6kl6ikc8a"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      '(modify-phases %standard-phases
         (add-after 'unpack 'patch-source
           (lambda _
             (substitute* "tests/tests/test_compiler.py"
               (("\\/usr\\/bin\\/env")
                (which "env")))))
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (setenv "DJANGO_SETTINGS_MODULE" "tests.settings")
               (invoke "django-admin" "test" "tests"
                       "--pythonpath=.")))))))
    (propagated-inputs
     (list python-jsmin
           python-css-html-js-minify))
    (native-inputs
     (list python-coveralls
           python-django
           python-setuptools
           python-setuptools-scm
           python-tox
           python-wheel))
    (home-page
     "https://github.com/jazzband/django-pipeline")
    (synopsis "Asset packaging library for Django")
    (description
     "Pipeline is an asset packaging library for Django, providing both CSS
and JavaScript concatenation and compression, built-in JavaScript template
support, and optional data-URI image and font embedding.")
    (license license:expat)))

(define-public python-django-cors-headers
  (package
    (name "python-django-cors-headers")
    (version "4.7.0")
    (source (origin
              (method git-fetch) ; PyPI does not include settings.py for tests
              (uri (git-reference
                    (url "https://github.com/adamchainz/django-cors-headers")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0j5h31wfndkva5a6m6zw67yq3sbndl0zq9w4w3v7xx15dd84g9y4"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "DJANGO_SETTINGS_MODULE" "tests.settings")
                (invoke "django-admin" "test" "tests"
                        "--pythonpath=.")))))))
    (propagated-inputs (list python-asgiref python-django))
    (native-inputs (list python-pytest python-setuptools python-wheel))
    (home-page "https://github.com/adamchainz/django-cors-headers")
    (synopsis "Django application for handling headers required for CORS")
    (description
     "@code{django-cors-headers} is a Django application for handling the
server headers required for Cross-Origin Resource Sharing (CORS).")
    (license license:expat)))

(define-public python-django-redis
  (package
    (name "python-django-redis")
    (version "5.4.0")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-redis" version))
              (sha256
               (base32
                "0hlch69b4v1fc29xpcjhk50cgbdn78v2qzbhkfzsizmh6jman0ka"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:test-flags
      ;; These fail with: No module named 'test_client'
      '(list "-k" "not test_custom_key_function and not delete")
      #:phases
      '(modify-phases %standard-phases
         (add-before 'check 'start-redis
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (invoke "redis-server" "--daemonize" "yes")
               (setenv "PYTHONPATH" ".")
               (setenv "DJANGO_SETTINGS_MODULE" "tests.settings.sqlite")))))))
    (native-inputs
     (list python-fakeredis
           python-hiredis
           python-mock
           python-msgpack
           python-pytest
           python-pytest-cov
           python-pytest-django
           python-pytest-mock
           python-setuptools
           python-wheel
           redis))
    (propagated-inputs
     (list python-django python-redis))
    (home-page "https://github.com/niwibe/django-redis")
    (synopsis "Full featured redis cache backend for Django")
    (description
     "This package provides a full featured Redis cache backend for Django.")
    (license license:bsd-3)))

(define-public python-django-rq
  (package
    (name "python-django-rq")
    (version "3.0.0")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-rq" version))
              (sha256
               (base32
                "1b371w4cdjlz83i2sg4gpx0z3svl3bfrn6zfy661374hv62xpnkv"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:test-flags
      #~(list "-k" "not test_scheduled_jobs and not test_started_jobs")
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'pre-check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "redis-server" "--daemonize" "yes")
                (setenv "DJANGO_SETTINGS_MODULE" "django_rq.tests.settings")
                (setenv "PYTHONPATH" (getcwd))))))))
    (native-inputs
     (list python-django-redis
           python-pytest
           python-pytest-django
           python-rq-scheduler
           python-setuptools
           python-wheel
           redis
           tzdata-for-tests))
    (propagated-inputs
     (list python-django python-redis python-rq python-pyaml))
    (home-page "https://github.com/ui/django-rq")
    (synopsis "Django integration with RQ")
    (description
     "Django integration with RQ, a Redis based Python queuing library.
Django-RQ is a simple app that allows you to configure your queues in django's
settings.py and easily use them in your project.")
    (license license:expat)))

(define-public python-django-q
  (package
    (name "python-django-q")
    (version "1.3.9")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django-q" version))
       (sha256
        (base32 "06x9l2j54km0nww71dv22ndgiax23kd7cwx5dafbzam3199lsssw"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      ;; FIXME: Tests require disque, Redis, MongoDB, Docker.
      #:tests? #f))
    (native-inputs
     (list python-setuptools
           python-wheel))
    (propagated-inputs
     (list python-arrow
           python-blessed
           python-django
           python-django-picklefield))
    (home-page "https://django-q.readthedocs.io/")
    (synopsis "Multiprocessing distributed task queue for Django")
    (description
     "Django Q is a native Django task queue, scheduler and worker application
using Python multiprocessing.")
    (license license:expat)))

(define-public python-django-q2
  (package
    (name "python-django-q2")
    (version "1.7.6")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django_q2" version))
       (sha256
        (base32 "0zd1zpi5d3ky26i9rv0aii6kkb6gwvpypnwmsjbmpxiwawhv242j"))))
    (build-system pyproject-build-system)
    ;; XXX: I just don't know how to correctly run the tests.
    (arguments (list #:tests? #false))
    (native-inputs (list python-poetry-core python-pytest))
    (propagated-inputs (list python-blessed
                             python-boto3
                             python-croniter
                             python-django
                             python-django-picklefield
                             python-django-q-rollbar
                             python-django-q-sentry
                             python-django-redis
                             python-hiredis
                             python-importlib-metadata
                             python-iron-mq
                             python-psutil
                             python-pymongo
                             python-redis
                             python-setproctitle))
    (home-page "https://django-q2.readthedocs.org")
    (synopsis "Multiprocessing distributed task queue for Django")
    (description
     "This package provides a multiprocessing distributed task queue for
Django.  Django Q2 is a fork of Django Q with the new updated version of
Django Q, dependencies updates, docs updates and several bug fixes.")
    (license license:expat)))

(define-public python-django-q-sentry
  (package
    (name "python-django-q-sentry")
    (version "0.1.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/danielwelch/django-q-sentry")
             ;; There are no tags.
             (commit "6ed0b372c502c18101c7b77dce162dcf2262c7bb")))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0c7rypsfax1l1j587p4cvcypa7if3vcyz2l806s6z27ajz0bz3v4"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'use-poetry-core
            (lambda _
              ;; Patch to use the core poetry API.
              (substitute* "pyproject.toml"
                (("poetry.masonry.api") "poetry.core.masonry.api")))))))
    (propagated-inputs (list python-sentry-sdk))
    (native-inputs (list python-poetry-core python-setuptools python-wheel))
    (home-page "https://django-q.readthedocs.org")
    (synopsis "Sentry support plugin for Django Q")
    (description "This package provides a Sentry support plugin for Django Q.")
    (license license:expat)))

(define-public python-django-q-rollbar
  (package
    (name "python-django-q-rollbar")
    (version "0.1.3")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django-q-rollbar" version))
       (sha256
        (base32 "0jzf84h4vr335ppp7x4d3pm04dlz8b75w0bswyynqzjhjji6vpm4"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'use-poetry-core
            (lambda _
              ;; Patch to use the core poetry API.
              (substitute* "pyproject.toml"
                (("poetry.masonry.api") "poetry.core.masonry.api"))))
          (add-after 'unpack 'relax-requirements
            (lambda _
              (substitute* "pyproject.toml"
                (("rollbar = .*") "rollbar = \"^1\"")))))))
    (propagated-inputs (list python-rollbar python-requests))
    (native-inputs (list python-poetry-core python-setuptools))
    (home-page "https://django-q.readthedocs.org")
    (synopsis "Rollbar support plugin for Django Q")
    (description
     "This package provides a Rollbar support plugin for Django Q.")
    (license license:expat)))

(define-public python-django-sortedm2m
  (package
    (name "python-django-sortedm2m")
    (version "4.0.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/jazzband/django-sortedm2m")
                    (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "13sm7axrmk60ai8jcd17x490yhg0svdmfj927vvfkq4lszmc5g96"))))
    (build-system pyproject-build-system)
    ;; Tests are disable because they need a live instance of PostgreSQL.
    (arguments (list #:tests? #false))
  (propagated-inputs
   (list python-django python-psycopg2))
  (native-inputs (list python-setuptools python-wheel))
  (home-page "https://github.com/jazzband/django-sortedm2m")
  (synopsis "Drop-in replacement for django's own ManyToManyField")
  (description
   "Sortedm2m is a drop-in replacement for django's own ManyToManyField.
The provided SortedManyToManyField behaves like the original one but remembers
the order of added relations.")
  (license license:bsd-3)))

(define-public python-django-appconf
  (package
    (name "python-django-appconf")
    (version "1.1.0")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-appconf" version))
              (sha256
               (base32
                "1r23cb8g680p4lc8q4gikarcn1y0x5x4whw9w4gg58425wvsvklz"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases #~(modify-phases %standard-phases
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         (setenv "DJANGO_SETTINGS_MODULE" "tests.test_settings")
                         (invoke "django-admin" "test" "--pythonpath=.")))))))
    (native-inputs (list python-setuptools python-wheel))
    (propagated-inputs
     (list python-django))
    (home-page "https://github.com/django-compressor/django-appconf")
    (synopsis "Handle configuration defaults of packaged Django apps")
    (description
      "This app precedes Django's own AppConfig classes that act as \"objects
[to] store metadata for an application\" inside Django's app loading mechanism.
In other words, they solve a related but different use case than
django-appconf and can't easily be used as a replacement.  The similarity in
name is purely coincidental.")
    (license license:bsd-3)))

(define-public python-django-statici18n
  (package
    (name "python-django-statici18n")
    (version "2.6.0")
    (home-page "https://github.com/zyegfryed/django-statici18n")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url home-page)
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "13caylidzlsb25gihc6xyqfzmdikj240kqvbdb1hn3h40ky4alhv"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      '(modify-phases %standard-phases
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (setenv "PYTHONPATH" "./tests/test_project")
               (setenv "DJANGO_SETTINGS_MODULE" "project.settings")
               (invoke "pytest" "-vv")))))))
    (native-inputs
     (list python-pytest python-pytest-django python-setuptools python-wheel))
    (propagated-inputs
     (list python-django python-django-appconf))
    (synopsis "Generate JavaScript catalog to static files")
    (description
      "A Django app that provides helper for generating JavaScript catalog to
static files.")
    (license license:bsd-3)))

;; This is a fork of the now unmaintained django-tagging package.
(define-public python-django-tagging
  (package
    (name "python-django-tagging")
    (version "0.5.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/jazzband/django-tagging")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1hyh0admdy7yvdnv0sr3lkmi7yw9qhk1y8403g7ijb8wf9psqc6s"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      ;; 6 of 75 tests fail with unclear an error.
      #:tests? #false
      #:phases
      '(modify-phases %standard-phases
         (replace 'check
           (lambda* (#:key tests? #:allow-other-keys)
             (when tests?
               (setenv "DJANGO_SETTINGS_MODULE" "tagging.tests.settings")
               (invoke "django-admin" "test" "--pythonpath=.")))))))
    (inputs
     (list python-django))
    (native-inputs (list python-setuptools python-wheel tzdata-for-tests))
    (home-page "https://github.com/jazzband/django-tagging")
    (synopsis "Generic tagging application for Django")
    (description "This package provides a generic tagging application for
Django projects, which allows association of a number of tags with any
@code{Model} instance and makes retrieval of tags simple.")
    (license license:bsd-3)))

(define-public python-django-rest-framework
  (package
    (name "python-django-rest-framework")
    (version "3.15.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/encode/django-rest-framework")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0ky559g2rpbz5sir33qq56c1bd4gc73hlrnkxsxpdm5mi69jrvcx"))))
    (build-system pyproject-build-system)
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (replace 'check
           (lambda* (#:key tests? inputs #:allow-other-keys)
             (if tests?
                 (invoke "python" "runtests.py")
                 (format #t "test suite not run~%")))))))
    (native-inputs
     (list python-pytest
           python-pytest-django
           python-setuptools
           python-wheel
           tzdata-for-tests))
    (propagated-inputs
     (list python-django python-pytz))
    (home-page "https://www.django-rest-framework.org")
    (synopsis "Toolkit for building Web APIs with Django")
    (description
     "The Django REST framework is for building Web APIs with Django.  It
provides features like a Web-browsable API and authentication policies.")
    (license license:bsd-2)))

(define-public python-djangorestframework
  (deprecated-package "python-djangorestframework" python-django-rest-framework))

(define-public python-django-sekizai
  (package
    (name "python-django-sekizai")
    (version "4.1.0")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "django-sekizai" version))
        (sha256
         (base32
          "1bfdag32yqjq3vqvyi9izdkmfcs2qip42rcmxpphqp0bmv5kdjia"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases #~(modify-phases %standard-phases
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         (setenv "DJANGO_SETTINGS_MODULE" "tests.settings")
                         (invoke "django-admin" "test" "--pythonpath=.")))))))
    (native-inputs (list python-setuptools python-wheel))
    (propagated-inputs
     (list python-django python-django-classy-tags))
    (home-page "https://github.com/django-cms/django-sekizai")
    (synopsis "Template blocks for Django projects")
    (description "Sekizai means blocks in Japanese, and that is what this app
provides.  A fresh look at blocks.  With @code{django-sekizai} you can define
placeholders where your blocks get rendered and at different places in your
templates append to those blocks.  This is especially useful for css and
javascript.  Your subtemplates can now define css and javascript files to be
included, and the css will be nicely put at the top and the javascript to the
bottom, just like you should.  Also sekizai will ignore any duplicate content in
a single block.")
    (license license:bsd-3)))

(define-public python-django-crispy-forms
  (package
    (name "python-django-crispy-forms")
    (version "1.9.2")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django-crispy-forms" version))
       (sha256
        (base32
         "0fxlf233f49hjax786p4r650rd0ilvhnpyvw8hv1d1aqnkxy1wgj"))))
    (build-system python-build-system)
    (arguments
     '(;; No included tests
       #:tests? #f))
    (propagated-inputs
     (list python-django))
    (home-page
     "http://github.com/maraujop/django-crispy-forms")
    (synopsis "Tool to control Django forms without custom templates")
    (description
     "@code{django-crispy-forms} lets you easily build, customize and reuse
forms using your favorite CSS framework, without writing template code.")
    (license license:expat)))

(define-public python-django-compressor
  (package
    (name "python-django-compressor")
    (version "4.5.1")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django_compressor" version))
       (sha256
        (base32 "08m8cs1mnpwd2zlck8cbl4cdp21dgv4vj7j17krbgn745s5a9n61"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      '(modify-phases %standard-phases
        (add-after 'unpack 'relax-requirements
          (lambda _
            (substitute* "setup.py"
              (("==") ">="))))
        ;; This needs calmjs.
        (add-after 'unpack 'skip-bad-test
          (lambda _
            (substitute* "compressor/tests/test_filters.py"
              (("test_calmjs_filter") "_test_calmjs_filter"))))
        ;; XXX: Reported upstream
        ;; <https://github.com/django-compressor/django-compressor/pull/1294>.
        (add-after 'unpack 'fix-setup.py
          (lambda _
            (substitute* "setup.py"
              (("package_data=.*,") "include_package_data=True,"))))
        (replace 'check
          (lambda* (#:key tests? inputs outputs #:allow-other-keys)
            (when tests?
              (with-directory-excursion (site-packages inputs outputs)
                (setenv "DJANGO_SETTINGS_MODULE" "compressor.test_settings")
                (invoke "django-admin" "test"
                        "--pythonpath=."))))))))
    (propagated-inputs
     (list python-django
           python-django-appconf
           python-django-sekizai
           python-rcssmin
           python-rjsmin))
    (native-inputs
     (list python-beautifulsoup4
           python-brotli
           python-csscompressor
           python-setuptools
           python-wheel))
    (home-page "https://django-compressor.readthedocs.io/en/latest/")
    (synopsis
     "Compress linked and inline JavaScript or CSS into single cached files")
    (description
     "Django Compressor combines and compresses linked and inline Javascript or
CSS in a Django templates into cacheable static files by using the compress
template tag.")
    (license license:expat)))

(define-public python-django-dbbackup
  (package
    (name "python-django-dbbackup")
    (version "4.3.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django_dbbackup" version))
       (sha256
        (base32 "1p66xs6c2sw1l2zlskpa64zslyawlpgv0vn2l86g4rxizp6chj9m"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'pre-check
            (lambda _
              ;; To write a .env file.
              (setenv "HOME" "/tmp")
              ;; 'env' command is not available in the build environment.
              (substitute* "dbbackup/tests/test_connectors/test_base.py"
                (("def test_run_command_with_parent_env")
                 "def _test_run_command_with_parent_env"))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "DJANGO_SETTINGS_MODULE" "dbbackup.tests.settings")
                (invoke "django-admin" "test" "dbbackup/tests"
                        "--pythonpath=.")))))))
    (native-inputs (list gnupg
                         python-dotenv
                         python-gnupg
                         python-pytest
                         python-pytz
                         python-setuptools
                         python-testfixtures
                         python-tzdata
                         python-wheel))
    (propagated-inputs (list python-django))
    (home-page "https://github.com/Archmonger/django-dbbackup")
    (synopsis "Backup and restore a Django project database and media")
    (description
     "This Django application provides management commands to help backup and
restore your project database and media files with various storages such as
Amazon S3, Dropbox, local file storage or any Django storage.")
    (license license:bsd-3)))

(define-public python-django-override-storage
  (package
    (name "python-django-override-storage")
    (version "0.3.0")
    (home-page "https://github.com/danifus/django-override-storage")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url home-page)
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "081kzfk7mmybhihvc92d3hsdg0r2k20ydq88fs1fgd348sq1ax51"))))
    (build-system python-build-system)
    (arguments
     '(#:phases (modify-phases %standard-phases
                  (replace 'check
                    (lambda _
                      (invoke "python" "runtests.py"))))))
    (native-inputs
     (list python-mock))
    (propagated-inputs
     (list python-django))
    (synopsis "Django test helpers to manage file storage side effects")
    (description
     "This project provides tools to help reduce the side effects of using
FileFields during tests.")
    (license license:expat)))

(define-public python-django-storages
  (package
    (name "python-django-storages")
    (version "1.14.6")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django_storages" version))
       (sha256
        (base32 "1ja1jgh7alypsb46ncbc6acsxxw771hf51yfqz4rmxhl8a7ww9bs"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:phases #~(modify-phases %standard-phases
                   (add-before 'check 'delete-some-tests
                     (lambda _
                        (delete-file
                         ;; python-google-cloud-storage broken in the CI
                         "tests/test_gcloud.py")
                        (delete-file
                         ;; python-moto can't find 'mock_s3'
                         "tests/test_s3.py")
                       (substitute* "tests/test_utils.py"
                         ;; This test depends on a file which is likely
                         ;; unavailble in PyPI (FileNotFoundError).
                         (("def test_with_string_file_detect_encoding")
                          "def _test_with_string_file_detect_encoding"))))
                   (replace 'check
                     (lambda* (#:key tests? #:allow-other-keys)
                       (when tests?
                         (setenv "DJANGO_SETTINGS_MODULE" "tests.settings")
                         (invoke "django-admin" "test" "tests"
                                 "--pythonpath=.")))))))
    (propagated-inputs (list python-django))
    (native-inputs (list python-azure-storage-blob ; azure backend
                         python-dropbox ; dropbox backend
                         python-paramiko ; sftp backend
                         python-pytest
                         python-setuptools python-wheel))
    (home-page "https://django-storages.readthedocs.io/en/latest/")
    (synopsis "Support for many storage backends in Django")
    (description
     "@code{django-storages} is a project to provide a variety of storage
backends in a single library.")
    (license license:bsd-3)))

(define-public python-django-auth-ldap
  (package
    (name "python-django-auth-ldap")
    (version "4.1.0")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-auth-ldap" version))
              (sha256
               (base32
                "0jd9jms9qpa92fk5n7gqcxjk3zs6ay79r73ann7cw1vqn79lkxvp"))))
    (build-system python-build-system)
    (arguments
     (list #:phases
           #~(modify-phases %standard-phases
               (replace 'build
                 (lambda _
                   ;; Set file modification times to the early 80's because
                   ;; the Zip format does not support earlier timestamps.
                   (setenv "SOURCE_DATE_EPOCH"
                           (number->string (* 10 366 24 60 60)))
                   (invoke "python" "-m" "build" "--wheel"
                           "--no-isolation" ".")))
               (replace 'check
                 (lambda* (#:key inputs #:allow-other-keys)
                   (setenv "SLAPD" (search-input-file inputs "/libexec/slapd"))
                   (setenv "SCHEMA"
                           (search-input-directory inputs "etc/openldap/schema"))
                   (invoke "python" "-m" "django" "test"
                           "--settings" "tests.settings")))
               (replace 'install
                 (lambda _
                   (let ((whl (car (find-files "dist" "\\.whl$"))))
                     (invoke "pip" "--no-cache-dir" "--no-input"
                             "install" "--no-deps" "--prefix" #$output whl)))))))
    (native-inputs
     (list openldap python-wheel python-setuptools-scm python-toml

           ;; These can be removed after <https://bugs.gnu.org/46848>.
           python-pypa-build python-pip))
    (propagated-inputs
     (list python-django python-ldap))
    (home-page "https://github.com/django-auth-ldap/django-auth-ldap")
    (synopsis "Django LDAP authentication backend")
    (description
     "This package provides an LDAP authentication backend for Django.")
    (license license:bsd-2)))

(define-public python-django-logging-json
  (package
    (name "python-django-logging-json")
    (version "1.15")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-logging-json" version))
              (sha256
               (base32
                "06041a8icazzp73kg93c7k1ska12wvkq7fpcad0l0sm1qnxx5yx7"))))
    (build-system python-build-system)
    (arguments
     '(#:tests? #f                      ;no tests
       #:phases (modify-phases %standard-phases
                  ;; Importing this module requires a Django project.
                  (delete 'sanity-check))))
    (propagated-inputs
     (list python-certifi python-django python-elasticsearch python-six))
    (home-page "https://github.com/cipriantarta/django-logging")
    (synopsis "Log requests/responses in various formats")
    (description
     "This package provides a Django library that logs request, response,
and exception details in a JSON document.  It can also send logs directly
to ElasticSearch.")
    (license license:bsd-2)))

(define-public python-django-netfields
  (package
    (name "python-django-netfields")
    (version "1.3.2")
    (source (origin
              (method url-fetch)
              (uri (pypi-uri "django-netfields" version))
              (sha256
               (base32
                "0q2s6b689hwql4qcw02m3zj2fwsx1w4ffhw81yvp71dq3dh46jg5"))))
    (build-system python-build-system)
    (arguments '(#:tests? #f))      ;XXX: Requires a running PostgreSQL server
    (propagated-inputs
     (list python-django python-netaddr python-psycopg2 python-six))
    (home-page "https://github.com/jimfunk/django-postgresql-netfields")
    (synopsis "PostgreSQL netfields implementation for Django")
    (description
     "This package provides mappings for the PostgreSQL @code{INET} and
@code{CIDR} fields for use in Django projects.")
    (license license:bsd-3)))

(define-public python-django-url-filter
  (package
    (name "python-django-url-filter")
    (version "0.3.15")
    (home-page "https://github.com/miki725/django-url-filter")
    (source (origin
              (method git-fetch)
              (uri (git-reference (url home-page) (commit version)))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "0r4zhqhs8y6cnplwyvcb0zpijizw1ifnszs38n4w8138657f9026"))
              (modules '((guix build utils)))
              (snippet
               ;; Patch for Django 4.0 compatibility, taken from upstream pull
               ;; request: https://github.com/miki725/django-url-filter/pull/103
               '(substitute* "url_filter/validators.py"
                  ((" ungettext_lazy")
                   " ngettext_lazy")))))
    (build-system python-build-system)
    (arguments
     '(#:tests? #f            ;FIXME: Django raises "Apps aren't loaded yet"!?
       #:phases (modify-phases %standard-phases
                  (add-after 'unpack 'loosen-requirements
                    (lambda _
                      ;; Do not depend on compatibility package for old
                      ;; Python versions.
                      (substitute* "requirements.txt"
                        (("enum-compat") ""))))
                  (replace 'check
                    (lambda* (#:key tests? #:allow-other-keys)
                      (if tests?
                          (begin
                            (setenv "DJANGO_SETTINGS_MODULE"
                                    "test_project.settings")
                            (invoke "pytest" "-vv" "--doctest-modules"
                                    "tests/" "url_filter/"))
                          (format #t "test suite not run~%")))))))
    (propagated-inputs
     (list python-cached-property python-django python-six))
    (synopsis "Filter data via human-friendly URLs")
    (description
     "The main goal of Django URL Filter is to provide an easy URL interface
for filtering data.  It allows the user to safely filter by model attributes
and also specify the lookup type for each filter (very much like
Django's filtering system in ORM).")
    (license license:expat)))

(define-public python-django-svg-image-form-field
  (package
    (name "python-django-svg-image-form-field")
    (version "1.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/artrey/django-svg-image-form-field")
             (commit (string-append version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "131m545khn8l20j4x2bvlvz36dlbnhj9pc98i2dw72s3bw8pgws0"))))
    (build-system python-build-system)
    (propagated-inputs
     (list python-defusedxml python-django python-pillow))
    (home-page "https://github.com/artrey/django-svg-image-form-field")
    (synopsis "Form field to validate SVG and other images")
    (description "This form field allows users to provide SVG images for
models that use Django's standard @code{ImageField}, in addition to the
image files already supported by it.")
    (license license:expat)))

(define-public python-django-environ
  (package
    (name "python-django-environ")
    (version "0.12.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "django_environ" version))
       (sha256
        (base32 "06h4g50qy1h77b4n28xbyzl2wvsblzs9qi63d7kvvm9x8n8whz92"))))
    (build-system pyproject-build-system)
    (native-inputs (list python-pytest
                         python-setuptools
                         python-wheel))
    (home-page "https://django-environ.readthedocs.io/")
    (synopsis "Configure Django project using environment variables")
    (description
     "This Django package allows you to utilize 12factor inspired environment
variables to configure your Django application.")
    (license license:expat)))

(define-public python-django-cleanup
  (package
    (name "python-django-cleanup")
    (version "9.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/un1t/django-cleanup")
             (commit (string-append version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "02ipa8d8ndnj8bs4dqhk03id4vmrvyr25vkpfqcfhmwipbhx8dc0"))))
    (build-system pyproject-build-system)
    (native-inputs
     (list python-pytest
           python-pytest-cov ; runs by default
           python-pytest-django
           python-setuptools
           python-wheel))
    (propagated-inputs
     (list python-django))
    (home-page "https://github.com/un1t/django-cleanup")
    (synopsis "Automatically deletes unused media files")
    (description "This application automatically deletes user-uploaded
files when a model is modified or deleted.  It works for FileField,
ImageField and their subclasses.  Files set as default values for any
FileField are not deleted.")
    (license license:expat)))
