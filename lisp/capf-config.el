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
 :ensure t
 :init (vertico-mode)
 :hook (after-init . vertico-mode)
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

;; Orderless: Flexible, order-independent matching style
(use-package
 orderless
 :ensure t
 :defer t
 :custom
 ;;  orderless-flex
 (orderless-matching-styles '(orderless-literal orderless-regexp))
 (completion-styles '(orderless basic))
 (completion-category-overrides
  '((file (styles partial-completion)))))

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
