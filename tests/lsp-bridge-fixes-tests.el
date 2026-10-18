;;; lsp-bridge-fixes-tests.el --- Document sync regressions -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'yasnippet)
(require 'lsp-bridge-fixes)

(defun my/lsp-bridge-test--replace-newlines (use-fix)
  "Return emitted change requests when replacing newlines, using USE-FIX."
  (with-temp-buffer
    (insert "one\ntwo\n")
    (setq-local lsp-bridge--before-change-begin-point nil
                lsp-bridge--before-change-end-point nil
                lsp-bridge-revert-buffer-flag nil)
    (let (requests
          (after-hook (if use-fix
                          #'lsp-bridge-monitor-after-change
                        (advice--cdr (symbol-function 'lsp-bridge-monitor-after-change)))))
      (cl-letf (((symbol-function 'lsp-bridge-process-live-p) (lambda () t))
                ((symbol-function 'lsp-bridge-has-lsp-server-p) (lambda () t))
                ((symbol-function 'lsp-bridge-call-file-api-p) (lambda () t))
                ((symbol-function 'lsp-bridge-is-remote-file) (lambda () nil))
                ((symbol-function 'lsp-bridge-org-babel-send-src-block-to-lsp-server) #'ignore)
                ((symbol-function 'lsp-bridge-record-last-change-position) #'ignore)
                ((symbol-function 'lsp-bridge-org-babel-monitor-after-change) #'ignore)
                ((symbol-function 'lsp-bridge-inlay-hint-try-send-request) #'ignore)
                ((symbol-function 'lsp-bridge-complete-other-backends) #'ignore)
                ((symbol-function 'lsp-bridge-search-words-update) #'ignore)
                ((symbol-function 'acm-char-before) (lambda () " "))
                ((symbol-function 'acm-get-input-prefix) (lambda () ""))
                ((symbol-function 'lsp-bridge-call-file-api)
                 (lambda (&rest args) (push args requests))))
        (add-hook 'before-change-functions #'lsp-bridge-monitor-before-change nil t)
        (add-hook 'after-change-functions after-hook nil t)
        (subst-char-in-region (point-min) (point-max) ?\n ?\s)
        (list (buffer-string) (nreverse requests))))))

(ert-deftest my/lsp-bridge-original-drops-equal-length-replacement ()
  (pcase-let ((`(,text ,requests) (my/lsp-bridge-test--replace-newlines nil)))
    (should (equal text "one two "))
    (should-not requests)))

(ert-deftest my/lsp-bridge-fix-sends-equal-length-replacement ()
  (pcase-let ((`(,text ,requests) (my/lsp-bridge-test--replace-newlines t)))
    (should (equal text "one two "))
    (should (= (length requests) 1))
    (pcase-let ((`(,method ,start ,end ,old-length ,replacement . ,_) (car requests)))
      (should (equal method "change_file"))
      (should (equal start '(:line 0 :character 3)))
      (should (equal end '(:line 2 :character 0)))
      (should (= old-length 5))
      (should (equal replacement " two ")))))

(ert-deftest my/lsp-bridge-fix-preserves-insert-delete-and-no-op ()
  (dolist (edit '((2 3 0 2 2) (2 2 1 2 3) (2 2 0 2 2)))
    (pcase-let ((`(,begin ,end ,length ,old-begin ,old-end) edit))
      (let ((lsp-bridge--before-change-begin-point old-begin)
            (lsp-bridge--before-change-end-point old-end)
            result)
        (my/lsp-bridge--sync-equal-length-replacement
         (lambda (&rest args)
           (setq result (list args lsp-bridge--before-change-end-point)))
         begin end length)
        (should (equal result (list (list begin end length) old-end)))))))

;;; lsp-bridge-fixes-tests.el ends here
