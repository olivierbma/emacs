;; (use-package treesit-auto
;;   :ensure t
;;   :straight t
;;   :after emacs
;;   :custom
;;   (treesit-auto-install 'prompt)
;;   :config
;;   (treesit-auto-add-to-auto-mode-alist 'all)
;;   (add-to-list 'auto-mode-alist '("\\CMakeLists\\.txt\\'" . cmake-ts-mode))
;;   (add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
;;   (add-to-list 'auto-mode-alist '("\\.js\\'" . typescript-ts-mode))  ; Note: usually js-ts-mode
;;   (add-to-list 'auto-mode-alist '("\\.mjs\\'" . typescript-ts-mode))
;;   (add-to-list 'auto-mode-alist '("\\.mts\\'" . typescript-ts-mode))
;;   (add-to-list 'auto-mode-alist '("\\.cjs\\'" . typescript-ts-mode))
;;   (add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
;;   (add-to-list 'auto-mode-alist '("\\.jsx\\'" . tsx-ts-mode))
;;   ;; (global-treesit-auto-mode t)
;;   (global-treesit-auto-mode t)
;;   )
(use-package treesit-auto
  :ensure t
  :demand t
  :custom
  (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
  (global-treesit-auto-mode))



(use-package tuareg
  :ensure t
  ;; :hook (  (ocaml-ts-mode) . lsp-bridge-mode)
  )

(use-package ocaml-ts-mode
  :ensure t
  :defer t)



(use-package typst-ts-mode
  :ensure t
  :defer t)


(use-package sly
  :ensure t
  :defer t)


(use-package cuda-mode
  :ensure t
  :defer t)


(use-package flycheck
  :ensure t
  :disabled t
  :defer t
  :init
  (global-flycheck-mode t)
  :config
  (setq flycheck-display-errors-delay 0.3)
  (setq flycheck-highlighting-mode 'symbols) ;; lighter
  )


;; lsp-bridge needs markdown-mode (renders documentation popups)
(use-package markdown-mode
  :ensure t
  :defer t)

;; lsp-bridge's acm-backend-yas requires yasnippet to be loadable when
;; lsp-bridge loads, so make sure it is available (and globally enabled)
;; before the lsp-bridge use-package below.
(use-package yasnippet
  :ensure t
  :demand t
  :config
  (yas-global-mode 1))

;; lsp-bridge: async LSP client with its own completion frontend (acm).
;; Loaded from the vendored checkout in vendor/lsp-bridge.
(use-package lsp-bridge
  :load-path "~/.emacs.d/vendor/lsp-bridge"
  :demand t
  :init
  ;; The Python backend runs through the repo's `python-lsp-bridge' uv
  ;; wrapper, symlinked into ~/.local/bin. lsp-bridge auto-detects that
  ;; name on PATH, so no `lsp-bridge-python-command' override is needed --
  ;; `uv run' provisions the exact deps from the repo's uv.lock on demand.
  (setq lsp-bridge-enable-hover-diagnostic t)
  (setq lsp-bridge-enable-signature-help t)
  (setq lsp-bridge-enable-diagnostics t)
  :config
  (global-lsp-bridge-mode)

  ;; Completion menu (acm) keys: mirror the previous corfu behaviour.
  ;; corfu had TAB -> next candidate, S-TAB -> previous; RET inserts.
  ;; By default acm binds TAB to "complete", so we override it here.
  (define-key acm-mode-map (kbd "TAB")       #'acm-select-next)
  (define-key acm-mode-map (kbd "<tab>")     #'acm-select-next)
  (define-key acm-mode-map (kbd "S-TAB")     #'acm-select-prev)
  (define-key acm-mode-map (kbd "<backtab>") #'acm-select-prev)
  ;; RET still accepts the selected candidate (acm default).

  (general-define-key
    :states '(normal)
    :prefix "SPC"
    "g d" 'lsp-bridge-find-def
    "g i" 'lsp-bridge-find-impl
    "g r" 'lsp-bridge-find-references
    "c a" 'lsp-bridge-code-action
    "r n" 'lsp-bridge-rename
    "k" 'lsp-bridge-popup-documentation
    "s d" 'lsp-bridge-diagnostic-list
  )
  (general-define-key
    :states '(normal)
    :prefix ""
    "C-i" 'lsp-bridge-code-format
    "K"   'lsp-bridge-popup-documentation
    "[d"  'lsp-bridge-diagnostic-jump-prev
    "]d"  'lsp-bridge-diagnostic-jump-next
   )
  )

;; if you are helm user
;; (use-package helm-lsp :commands helm-lsp-workspace-symbol)


;; optionally if you want to use debugger
;; (use-package dap-mode)
;; (use-package dap-LANGUAGE) to load the dap adapter for your language




(defun my/hover ()
  "Show function doc using eldoc-box."
  (interactive)
  (eldoc-box-help-at-point))
(add-hook 'eglot-managed-mode-hook
          (lambda ()
            (eldoc-box-hover-mode -1))) ;; optional: avoid auto popups

(provide 'languages-config)
;;; languages-config.el ends here
