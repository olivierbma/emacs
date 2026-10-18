;;; lsp-bridge-fixes.el --- Local document synchronization fixes -*- lexical-binding: t; -*-

;;; Commentary:
;; The vendored lsp-bridge after-change hook treats equal before/after bounds
;; as an unchanged edit.  Replacements can keep those bounds while changing
;; text and line breaks, leaving the server's document out of sync.

;;; Code:

(require 'lsp-bridge)

(defun my/lsp-bridge--sync-equal-length-replacement (original begin end length)
  "Call ORIGINAL for an equal-length replacement at BEGIN..END.
LENGTH is the number of old characters replaced.  The before-change point
marker is used only by upstream's early no-change check; the actual LSP
positions remain in the separate before-change position variables."
  (if (and (> length 0)
           (equal begin lsp-bridge--before-change-begin-point)
           (equal end lsp-bridge--before-change-end-point))
      (let ((lsp-bridge--before-change-end-point nil))
        (funcall original begin end length))
    (funcall original begin end length)))

(advice-add 'lsp-bridge-monitor-after-change :around
            #'my/lsp-bridge--sync-equal-length-replacement)

(provide 'lsp-bridge-fixes)
;;; lsp-bridge-fixes.el ends here
