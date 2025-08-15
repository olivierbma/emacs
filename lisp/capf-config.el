;;; capf-config --- SOmething

(require 'nerd-icons)

(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode 1))

(use-package eldoc
  :ensure t
  :init
  (global-eldoc-mode 1))

(use-package eldoc-box
  :ensure t
  :config
  )

;; Vertico: A simple and efficient minibuffer completion
(use-package vertico
  :ensure t
  :init
  (vertico-mode)
  :hook
  (after-init . vertico-mode)
  )

;; Marginalia: Add helpful annotations to completion candidates
(use-package marginalia
  :ensure t
  :straight t
  :init
  (marginalia-mode)
  :hook
  (after-init . marginalia-mode))

;; Orderless: Flexible, order-independent matching style
(use-package orderless
  :ensure t
  :defer t
  :init
  ;; Configure Emacs to use Orderless
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion))
                                        (lsp-capf (styles orderless basic))))
  )

(use-package corfu
  :defer t
  :ensure t
  :straight t
  ;; :hook (after-init . global-corfu-mode)
  :config
  (setq corfu-cycle t                    ; Enable cycling for `corfu-next/previous'
        corfu-auto t                     ; Enable auto completion
        corfu-auto-prefix 2              ; Minimum prefix length for auto completion
        corfu-auto-delay 0.2             ; Auto completion delay
        corfu-min-width 80
        corfu-count 10
        corfu-quit-at-boundary nil       ; Never quit at completion boundary
        corfu-quit-no-match nil          ; Never quit, even if there is no match
        corfu-quit-at-boundary nil
        ;; corfu-preview-current nil    ; Preview current candidate
        corfu-preselect 'prompt          ; Preselect the prompt
        corfu-on-exact-match nil)        ; Configure handling of exact matches
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)

  :bind
  (:map corfu-map
        ("TAB" . corfu-next)
        ([tab] . corfu-next)
        ("S-TAB" . corfu-previous)
        ([backtab] . corfu-previous))

  :init
  (global-corfu-mode)
  (corfu-history-mode)
  (corfu-popupinfo-mode)
  )



(use-package nerd-icons-corfu
  :ensure t
  :defer t
  )


(use-package cape
  :ensure t
  :defer t
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)
  ;; (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  )


(provide 'capf-config)
;;; capf-config.el ends here
