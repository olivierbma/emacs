(use-package treesit-auto
  :ensure t
  :demand t
  :straight t
  :after emacs
  :custom
  (treesit-auto-install 'prompt)
  :config
  (add-to-list 'auto-mode-alist '("CMakeLists\\.txt\\'" . cmake-ts-mode))
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode t))


(use-package typst-ts-mode
  :ensure t
  :defer t)

(use-package ocaml-ts-mode
  :ensure t
  :defer t)

(use-package cuda-mode
  :ensure t
  :defer t)


;; for lsp support
(use-package eglot
  :ensure t
  :hook (  (c-ts-mode
             c++-ts-mode
             typst-ts-mode
             java-ts-mode
             ocaml-ts-mode
             cuda-mode
             python-ts-mode) . eglot-ensure)
  :config
  (setq eglot-autoshutdown t)
  (dolist (entry
           '((typst-ts-mode . ("tinymist" "lsp"))
           (ocaml-ts-mode . ("ocamllsp"))
           (c-ts-mode . ("clangd"))
           (java-ts-mode . ("jdtls"))
           (c++-ts-mode . ("clangd"))))
    (add-to-list 'eglot-server-programs entry))
  ;; define some keymappings
  (general-define-key
   :states '(normal)
   :prefix "SPC"
   "r n" 'eglot-rename
   "c a" 'eglot-code-actions
   "g d" 'xref-find-definitions 
   "g i" 'eglot-find-implmentation
   "k" 'my/eglot-hover
   )
  (general-define-key
   :states '(normal)
   :prefix ""
   "C-i" 'eglot-format
   )
  (setq completion-category-defaults nil))

;; (use-package lsp-mode
;;   :hook ((c-ts-mode . lsp)
;;          (c++-ts-mode . lsp)
;;          (typst-ts-mode . lsp)
;;          (ocaml-ts-mode . lsp)
;;          (python-ts-mode . lsp)
;;          (cuda-mode . lsp)
;;          (lsp-mode . lsp-enable-which-key-integration))
;;   :commands lsp
;;   )

(defun my/eglot-hover ()
  "Show function doc using eldoc-box."
  (interactive)
  (eldoc-box-help-at-point))
(add-hook 'eglot-managed-mode-hook
          (lambda ()
            (eldoc-box-hover-mode -1))) ;; optional: avoid auto popups

(provide 'languages-config)
