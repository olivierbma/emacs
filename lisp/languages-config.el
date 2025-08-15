(use-package treesit-auto
  :ensure t
  :straight t
  :after emacs
  :custom
  (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (add-to-list 'auto-mode-alist '("CMakeLists\\.txt\\'" . cmake-ts-mode))
  (global-treesit-auto-mode t))



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
  )

;; for lsp support
;; (use-package eglot
;;   :ensure t
;;   :hook (  (c-ts-mode
;;              c++-ts-mode
;;              typst-ts-mode
;;              java-ts-mode
;;              ocaml-ts-mode
;;              elixir-ts-mode
;;              cuda-mode
;;              python-ts-mode) . eglot-ensure)
;;   :config
;;   (setq eglot-autoshutdown t)
;;   (dolist (entry
;;            '((typst-ts-mode . ("tinymist" "lsp"))
;;            (ocaml-ts-mode . ("ocamllsp"))
;;            (c-ts-mode . ("clangd"))
;;            (java-ts-mode . ("jdtls"))
;;            (c++-ts-mode . ("clangd"))))
;;     (add-to-list 'eglot-server-programs entry))
;;   ;; define some keymappings
;;   (general-define-key
;;    :states '(normal)
;;    :prefix "SPC"
;;    "r n" 'eglot-rename
;;    "c a" 'eglot-code-actions
;;    "g d" 'xref-find-definitions 
;;    "g i" 'eglot-find-implmentation
;;    "k" 'my/eglot-hover
;;    )
;;   (general-define-key
;;    :states '(normal)
;;    :prefix ""
;;    "C-i" 'eglot-format
;;    )
;;   (setq completion-category-defaults nil))

(use-package lsp-mode
:init
  ;; set prefix for lsp-command-keymap (few alternatives - "C-l", "C-c l")
  :hook (;; replace XXX-mode with concrete major-mode(e. g. python-mode)
         (python-mode . lsp)
         (python-ts-mode . lsp)
         (c++-ts-mode . lsp)
         (c-ts-mode . lsp)
         ;; if you want which-key integration
         (lsp-mode . lsp-enable-which-key-integration))
  :commands lsp)

;; optionally
(use-package lsp-ui :commands lsp-ui-mode)
;; if you are helm user
(use-package helm-lsp :commands helm-lsp-workspace-symbol)
;; if you are ivy user
(use-package lsp-ivy :commands lsp-ivy-workspace-symbol)
(use-package lsp-treemacs :commands lsp-treemacs-errors-list)

;; optionally if you want to use debugger
(use-package dap-mode)
;; (use-package dap-LANGUAGE) to load the dap adapter for your language

;; optional if you want which-key integration



(defun my/hover ()
  "Show function doc using eldoc-box."
  (interactive)
  (eldoc-box-help-at-point))
(add-hook 'eglot-managed-mode-hook
          (lambda ()
            (eldoc-box-hover-mode -1))) ;; optional: avoid auto popups

(provide 'languages-config)
;;; languages-config.el ends here
