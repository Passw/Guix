text-mode :when (bound-and-true-p git-commit-mode)

(add\ "gnu: Add "
      (p (with-temp-buffer
           (magit-git-wash #'magit-diff-wash-diffs
             "diff" "--staged")
           (goto-char (point-min))
           (when (re-search-forward "\\+(define-public \\(\\S-+\\)"
                                    nil 'noerror)
             (match-string-no-properties 1)))
         var)
      "." n n
      "* " (p (or (car (magit-staged-files)) ""))
      " (" (s var ) "): New variable.")

(remove\ "gnu: Remove "
         (p (with-temp-buffer
              (magit-git-wash #'magit-diff-wash-diffs
                "diff" "--staged")
              (goto-char (point-min))
              (when (re-search-forward "\\-(define-public \\(\\S-+\\)"
                                       nil 'noerror)
                (match-string-no-properties 1)))
            var)
         "." n n
         "* " (p (or (car (magit-staged-files)) ""))
         " (" (s var) "): Delete variable.")

(rename\ "gnu: "
         (p (with-temp-buffer
              (magit-git-wash #'magit-diff-wash-diffs
                "diff" "--staged")
              (beginning-of-buffer)
              (when (search-forward "-(define-public " nil 'noerror)
                (thing-at-point 'sexp 'no-properties)))
            prev-var)
         ": Rename package to "
         (p (with-temp-buffer
              (magit-git-wash #'magit-diff-wash-diffs
                "diff" "--staged")
              (beginning-of-buffer)
              (when (search-forward "+(define-public " nil 'noerror)
                (thing-at-point 'sexp 'no-properties)))
            new-var)
         "." n n
         "* " (p (or (car (magit-staged-files)) "")) " (" (s prev-var) "): "
         "Define in terms of" n
         "'deprecated-package'." n
         "(" (s new-var) "): New variable, formerly known as \""
         (s prev-var) "\".")

(update\ "gnu: "
         (p (with-temp-buffer
              (magit-git-wash #'magit-diff-wash-diffs
                "diff" "--staged")
              (goto-char (point-min))
              (when (re-search-forward "^[ ]*(define-public \\(\\S-+\\)"
                                       nil 'noerror)
                (match-string-no-properties 1)))
            var)
         ": Update to "
         (p (with-temp-buffer
              (magit-git-wash #'magit-diff-wash-diffs
                "diff" "--staged")
              (goto-char (point-min))
              (search-forward "name" nil 'noerror)
              (search-forward "+" nil 'noerror)   ; first change
              (when (and (search-forward "version " nil 'noerror)
                         (looking-at-p "\""))
                (let ((end (save-excursion (search-forward "\")"
                                                           nil 'noerror))))
                  (when end
                    (forward-char)
                    (buffer-substring-no-properties (point) (- end 2))))))
            version)
         "." n n
         "* " (p (or (car (magit-staged-files)) "")) " (" (s var) "): "
         "Update to " (s version) "." n
         (mapconcat (lambda (file) (concat "* " file))
                    (cdr (magit-staged-files))
                    "\n"))

(addcl\ "gnu: Add cl-"
        (p (replace-regexp-in-string
            "^cl-" "" (with-temp-buffer
                        (magit-git-wash #'magit-diff-wash-diffs
                          "diff" "--staged")
                        (beginning-of-buffer)
                        (when (search-forward "+(define-public " nil 'noerror)
                          (replace-regexp-in-string
                           "^sbcl-" ""
                           (thing-at-point 'sexp 'no-properties)))))
           var)
        "." n n
        "* " (p (or (car (magit-staged-files)) ""))
        " (cl-" (s var)
        ", ecl-" (s var)
        ", clasp-" (s var)
        ", sbcl-" (s var) "): New variables.")

(https\ "gnu: "
        (p (with-temp-buffer
             (magit-git-wash #'magit-diff-wash-diffs
               "diff" "--staged")
             (goto-char (point-min))
             (when (re-search-forward "^[ ]*(define-public \\(\\S-+\\)"
                                      nil 'noerror)
               (match-string-no-properties 1)))
           var)
        ": Use HTTPS home page." n n
        "* " (p (or (car (magit-staged-files)) ""))
        " (" (s var) ")[home-page]: Use HTTPS."
        n
        (mapconcat (lambda (file) (concat "* " file))
                   (cdr (magit-staged-files))
                   "\n"))

(move\ "gnu: "
       (p (with-temp-buffer
            (magit-git-wash #'magit-diff-wash-diffs
              "diff" "--staged")
            (goto-char (point-min))
            (when (re-search-forward "\\-(define-public \\(\\S-+\\)"
                                     nil 'noerror)
              (match-string-no-properties 1)))
          var)
       ": Move to ("
       (p (with-temp-buffer
            (magit-git-wash #'magit-diff-wash-diffs
              "diff" "--staged")
            (goto-char (point-min))
            (when (and
                   (re-search-forward "\\+(define-public \\(\\S-+\\)"
                                      nil 'noerror)
                   (re-search-backward "modified[ ]*\\(\\S-+\\)"
                                       nil 'noerror))
              (string-replace
               "\.scm" ""
               (string-replace "/" " "
                               (match-string-no-properties 1)))))
          new-module)
       ")." n
       n
       "* " (p (with-temp-buffer
                  (magit-git-wash #'magit-diff-wash-diffs
                    "diff" "--staged")
                  (goto-char (point-min))
                  (when (and
                         (re-search-forward "\\-(define-public \\(\\S-+\\)"
                                            nil 'noerror)
                         (re-search-backward "modified[ ]*\\(\\S-+\\)"
                                             nil 'noerror))
                    (match-string-no-properties 1)))
                source)
       " (" (s var) "): Move from here…" n
       "* " (concat (string-replace " " "/" new-module) ".scm")
       " (" (s var) "): …to here.")
