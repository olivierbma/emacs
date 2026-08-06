;;; -*- lexical-binding: t; -*-

;;; capf-config --- SOmething

(require 'nerd-icons)

(use-package yasnippet :ensure t :config (yas-global-mode 1))

(use-package eldoc :ensure t :init (global-eldoc-mode 1))

(use-package eldoc-box :ensure t :config)

;; Stack *Completions* vertically instead of laying it out as a grid.  This is
;; what `completion-at-point' prompts use -- notably evil's `:' ex line, which
;; reads via `read-from-minibuffer' and so never gets the vertico UI.
(setq completions-format 'one-column)

;; Vertico: A simple and efficient minibuffer completion
(use-package
 vertico
 :demand t
 :ensure t
 :init (vertico-mode +1)
 :general
 (:keymaps
  '(vertico-map) "C-j" 'vertico-next "C-k" 'vertico-previous))

;; Marginalia: Add helpful annotations to completion candidates
(use-package
 marginalia
 :ensure t
 :straight t
 :init (marginalia-mode)
 :hook (after-init . marginalia-mode))

;; Orderless: Flexible, order-independent matching style.
(use-package
 orderless
 :ensure t
 :defer t
 :custom
 ;; Keep `orderless-flex' OUT of the default styles: matching styles are a
 ;; disjunction, so flex matches everything (`rcl.h' matches `--r--c--l--.h')
 ;; and orderless does no ranking, so literal hits get buried.  Instead flex is
 ;; opt-in per component via `orderless-affix-dispatch': prefix or suffix a
 ;; component with ~ for flex, = literal, ^ literal-prefix, , initialism,
 ;; ! without, % char-fold.
 (orderless-matching-styles '(orderless-literal orderless-regexp))
 (orderless-style-dispatchers '(orderless-affix-dispatch))
 (completion-styles '(orderless basic))
 ;; (completion-category-overrides
 ;;  '((file (styles partial-completion))))
 )

(use-package
 vertico-prescient
 :ensure t
 :demand t
 :after vertico
 :custom
 (vertico-prescient-enable-filtering t)
 (prescient-sort-full-matches-first t)
 (prescient-filter-method '(literal regexp initialism fuzzy))
 :custom-face
 ;; Follow the theme rather than hardcoding a colour.  The major-mode segment
 ;; resolves `doom-modeline-buffer-major-mode' -> `doom-modeline-emphasis' ->
 ;; `mode-line-emphasis', which doom-challenger-deep sets to its `highlight'
 ;; colour.  Face inheritance is resolved at redisplay, so `load-theme' repaints
 ;; this automatically.  `mode-line-emphasis' carries no background of its own,
 ;; so only the foreground is borrowed.
 (prescient-primary-highlight ((t :inherit mode-line-emphasis :weight bold)))
 :config
 (prescient-persist-mode +1)
 (vertico-prescient-mode +1))

;; `prescient--highlight-candidate' highlights the WHOLE regexp match (group 0)
;; with `prescient-primary-highlight' and merely underlines the capture groups.
;; That is unreadable with `fuzzy' in `prescient-filter-method': the per-subquery
;; regexp is `literal\|regexp\|initialism\|fuzzy' and matching is leftmost-first,
;; so the fuzzy branch nearly always wins and group 0 stretches from the first
;; query character to the last -- e.g. "car" on "a-cat-parser" matches "cat-pars"
;; and the entire candidate lights up.  Highlight the capture groups instead when
;; the winning branch produced any (fuzzy, initialism), and only fall back to
;; group 0 for the group-less branches (literal, regexp), where it is exact.
(defun ob/prescient--highlight-candidate (regexps case-fold candidate)
  "Highlight text matching REGEXPS and considering CASE-FOLD in CANDIDATE."
  (setq candidate (copy-sequence candidate))
  (prog1 candidate
    (let ((case-fold-search case-fold))
      (save-match-data
        (dolist (regexp regexps)
          (when (string-match regexp candidate)
            (let ((matched-group nil))
              (cl-loop for (start end) on (cddr (match-data)) by #'cddr
                       do (when (and start end)
                            (setq matched-group t)
                            (font-lock-prepend-text-property
                             start end
                             'face 'prescient-primary-highlight
                             candidate)))
              (unless matched-group
                (font-lock-prepend-text-property
                 (match-beginning 0) (match-end 0)
                 'face 'prescient-primary-highlight
                 candidate)))))))))

(advice-add
 'prescient--highlight-candidate
 :override #'ob/prescient--highlight-candidate)

(use-package affe :ensure t :defer t)

;; NOTE: completion is now handled by lsp-bridge's own frontend (acm),
;; see lisp/languages-config.el. corfu is left configured but no longer
;; activated globally so the two don't fight over the same buffers.
;; (use-package corfu
;;   :defer t
;;   :disabled t
;;   :ensure t
;;   :straight t
;;   ;; :hook (after-init . global-corfu-mode)
;;   :config
;;   (setq corfu-cycle t                    ; Enable cycling for `corfu-next/previous'
;;         corfu-auto t                     ; Enable auto completion
;;         corfu-auto-prefix 2              ; Minimum prefix length for auto completion
;;         corfu-auto-delay 0.2             ; Auto completion delay
;;         corfu-min-width 80
;;         corfu-count 10
;;         corfu-quit-at-boundary nil       ; Never quit at completion boundary
;;         corfu-quit-no-match nil          ; Never quit, even if there is no match
;;         corfu-quit-at-boundary nil
;;         ;; corfu-preview-current nil    ; Preview current candidate
;;         corfu-preselect 'prompt          ; Preselect the prompt
;;         corfu-on-exact-match nil)        ; Configure handling of exact matches
;;   (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)

;;   :bind
;;   (:map corfu-map
;;         ("TAB" . corfu-next)
;;         ([tab] . corfu-next)
;;         ("S-TAB" . corfu-previous)
;;         ([backtab] . corfu-previous))

;;   :init
;;   (global-corfu-mode)
;;   (corfu-history-mode)
;;   (corfu-popupinfo-mode)
;;   )


;; (use-package nerd-icons-corfu
;;   :ensure t
;;   :defer t
;;   )


(use-package
 cape
 :ensure t
 :defer t
 :init (add-to-list 'completion-at-point-functions #'cape-file)
 ;; (add-to-list 'completion-at-point-functions #'cape-dabbrev)
 )


(provide 'capf-config)
;;; capf-config.el ends here
