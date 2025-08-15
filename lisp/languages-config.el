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
  :defer t
  :init
  (global-flycheck-mode t)
  :config
  (setq flycheck-display-errors-delay 0.3)
  (setq flycheck-highlighting-mode 'symbols) ;; lighter
  )


(use-package lsp-mode
  :init
  ;; set prefix for lsp-command-keymap (few alternatives - "C-l", "C-c l")
  :hook (;; replace XXX-mode with concrete major-mode(e. g. python-mode)
         (python-mode . lsp)
         (python-ts-mode . lsp)
         (c++-ts-mode . lsp)
         (typst-ts-mode . lsp)
         (typescript-ts-mode . lsp)
         (tsx-ts-mode . lsp)
         )
  :commands lsp
  :config
  (add-to-list 'lsp-language-id-configuration '(typst-ts-mode . "typst"))
  (setq lsp-signature-auto-activate t)
  (setq lsp-eldoc-enable-hover t)
  (setq lsp-auto-execute-action nil)
  (setq lsp-log-io nil)
  (setq lsp-completion-provider :capf)
  (setq lsp-idle-delay 0.3)
  (setq lsp-lens-enable nil)
  (setq lsp-enable-symbol-highlighting nil)
  (setq lsp-headerline-breadcrumb-enable nil)
  (general-define-key
    :states '(normal)
    :prefix "SPC"
    "g d" 'lsp-ui-peek-find-definitions 
    "g i" 'lsp-ui-peek-find-implementation
    "g r" 'lsp-ui-peek-find-references
    "c a" 'lsp-execute-code-action
    "r n" 'lsp-rename
    "k" 'lsp-describe-thing-at-point
    "s d" 'lsp-ui-flycheck-list
  )
  (general-define-key
    :states '(normal)
    :prefix ""
    "C-i" 'lsp-format-buffer
   )
  )


;; (lsp-register-client
;;  (make-lsp-client
;;   :new-connection (lsp-stdio-connection '("tinymist" "lsp"))
;;   :major-modes '(typst-ts-mode)
;;   :server-id 'typst))

;; optionally
(use-package lsp-ui
  :commands lsp-ui-mode
  :config
  ;; (setq lsp-ui-sideline-show-hover t)
  (setq lsp-ui-sideline-show-hover nil)
  (setq lsp-ui-sideline-delay 0.5)
  (setq lsp-ui-sideline-show-code-actions t)
  (setq lsp-ui-sideline-show-diagnostics t)
  (setq lsp-ui-sideline-diagnostic-max-lines 5)
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
