;;; -*- lexical-binding: t; -*-

(use-package
 treesit-auto
 :ensure t
 :demand t
 :custom (treesit-auto-install 'prompt)
 :config
 (treesit-auto-add-to-auto-mode-alist 'all)
 (add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
 (global-treesit-auto-mode))


;;; ---------------------------------------------------------------------------
;;; Doxygen docstring generation for C/C++ using the built-in tree-sitter
;;; parse tree (no external packages; replaces the old ts-docstr which pulled
;;; in the legacy emacs-tree-sitter package).
;;; ---------------------------------------------------------------------------

(defun my/doxygen--param-identifier (node)
  "Return the parameter name held in declarator NODE, or nil."
  (when node
    (let ((id (treesit-search-subtree node "\\`identifier\\'")))
      (and id (treesit-node-text id t)))))

(defun my/doxygen--param-names (fdecl)
  "Return the list of parameter name strings from FDECL, a function_declarator."
  (let ((params (treesit-node-child-by-field-name fdecl "parameters"))
        names)
    (when params
      (dolist (child (treesit-node-children params t))
        (when (member
               (treesit-node-type child)
               '("parameter_declaration"
                 "optional_parameter_declaration"))
          (push (or (my/doxygen--param-identifier
                     (treesit-node-child-by-field-name
                      child "declarator"))
                    "")
                names))))
    (nreverse names)))

(defun my/doxygen-comment ()
  "Insert a Doxygen comment skeleton for the C/C++ function at point.
@param/@return lines are derived from the signature via the built-in
tree-sitter parse tree."
  (interactive)
  (unless (treesit-parser-list)
    (user-error "No tree-sitter parser in this buffer"))
  (let ((func
         (treesit-parent-until
          (treesit-node-at (point))
          (lambda (n)
            (member
             (treesit-node-type n)
             '("function_definition"
               "declaration"
               "field_declaration"
               "template_declaration")))
          t)))
    (unless func
      (user-error "No function at point"))
    ;; Anchor the comment above any enclosing template_declaration(s).
    (let ((anchor func))
      (while (and (treesit-node-parent anchor)
                  (equal
                   (treesit-node-type
                    (treesit-node-parent anchor))
                   "template_declaration"))
        (setq anchor (treesit-node-parent anchor)))
      (let*
          ((sig
            (if (equal
                 (treesit-node-type func) "template_declaration")
                (treesit-search-subtree
                 func
                 "\\`\\(function_definition\\|declaration\\|field_declaration\\)\\'")
              func))
           (fdecl
            (treesit-search-subtree
             (or sig func) "\\`function_declarator\\'"))
           (fname
            (and fdecl
                 (treesit-node-child-by-field-name
                  fdecl "declarator")))
           (rtype-node
            (and sig (treesit-node-child-by-field-name sig "type")))
           ;; Span type..name to keep pointer/reference tokens (e.g. "Foo*").
           (rtype
            (and rtype-node
                 fname
                 (string-trim
                  (buffer-substring-no-properties
                   (treesit-node-start rtype-node)
                   (treesit-node-start fname)))))
           (params (and fdecl (my/doxygen--param-names fdecl)))
           (start (treesit-node-start anchor))
           (col
            (save-excursion
              (goto-char start)
              (back-to-indentation)
              (current-column)))
           (pad (make-string col ?\s))
           (lines
            (list (concat pad "/**") (concat pad " * @brief "))))
        (unless fdecl
          (user-error "No function signature found"))
        (dolist (p params)
          (unless (string-empty-p p)
            (setq lines
                  (append
                   lines (list (concat pad " * @param " p " "))))))
        (when (and rtype (not (member rtype '("void" ""))))
          (setq lines
                (append
                 lines (list (concat pad " * @return " rtype)))))
        (setq lines (append lines (list (concat pad " */"))))
        (goto-char start)
        (beginning-of-line)
        (insert (mapconcat #'identity lines "\n") "\n")
        ;; leave point at the end of the @brief line
        (forward-line (- (1- (length lines))))
        (end-of-line)))))

(with-eval-after-load 'c-ts-mode
  (general-define-key
   :states '(normal)
   :keymaps 'c-ts-mode-map
   :prefix "SPC"
   "c d" 'my/doxygen-comment))


(use-package sly :ensure t :defer t)


(use-package
 flycheck
 :ensure t
 :disabled t
 :defer t
 :init (global-flycheck-mode t)
 :custom
 (flycheck-display-errors-delay 0.3)
 (flycheck-highlight-mode 'symbols))
;; lsp-bridge needs markdown-mode (renders documentation popups)
(use-package markdown-mode :ensure t :defer t)
;; lsp-bridge's acm-backend-yas requires yasnippet to be loadable when
;; lsp-bridge loads, so make sure it is available (and globally enabled)
;; before the lsp-bridge use-package below.
(use-package
 yasnippet
 :ensure t
 :demand t
 :config (yas-global-mode 1))

;; lsp-bridge: async LSP client with its own completion frontend (acm).
;; Loaded from the vendored checkout in vendor/lsp-bridge.
(use-package
 lsp-bridge
 :load-path "~/.emacs.d/vendor/lsp-bridge"
 :demand t
 :init
 ;; The Python backend runs through the repo's `python-lsp-bridge' uv
 ;; wrapper, symlinked into ~/.local/bin. lsp-bridge auto-detects that
 ;; name on PATH, so no `lsp-bridge-python-command' override is needed --
 ;; `uv run' provisions the exact deps from the repo's uv.lock on demand.
 ;; (setq lsp-bridge-enable-hover-diagnostic t)
 ;; (setq lsp-bridge-enable-signature-help t)
 ;; (setq lsp-bridge-enable-diagnostics t)
 :custom
 (lsp-bridge-enable-hover-diagnostic t)
 (lsp-bridge-enable-signature-help t)
 (lsp-bridge-enable-diagnostics t)
 (lsp-bridge-ref-delete-other-windows nil)
 :config (global-lsp-bridge-mode)
 ;; Completion menu (acm) keys: mirror the previous corfu behaviour.
 ;; corfu had TAB -> next candidate, S-TAB -> previous; RET inserts.
 ;; By default acm binds TAB to "complete", so we override it here.
 (define-key acm-mode-map (kbd "TAB") #'acm-select-next)
 (define-key acm-mode-map (kbd "<tab>") #'acm-select-next)
 (define-key acm-mode-map (kbd "S-TAB") #'acm-select-prev)
 (define-key acm-mode-map (kbd "<backtab>") #'acm-select-prev)
 ;; RET still accepts the selected candidate (acm default).

 :general
 (my/leader
  "g" '(:ignore t :which-key "goto")
  "g d" 'lsp-bridge-find-def
  "g i" 'lsp-bridge-find-impl
  "g r" 'lsp-bridge-find-references

  "c" '(:ignore t :which-key "code")
  "c a" 'lsp-bridge-code-action
  "c r" 'lsp-bridge-rename
  "c f" 'my/format-buffer

  "s d" 'lsp-bridge-diagnostic-list)
 (:states
  '(normal)
  :prefix ""

  "K" 'lsp-bridge-popup-documentation
  "[d" 'lsp-bridge-diagnostic-jump-prev
  "]d" 'lsp-bridge-diagnostic-jump-next))

(defun my/format-buffer ()
  "Format the current buffer with elisp-autofmt in Emacs Lisp, lsp-bridge otherwise."
  (interactive)
  (if (derived-mode-p 'emacs-lisp-mode)
      (elisp-autofmt-buffer)
    (lsp-bridge-code-format)))


;; if you are helm user
;; (use-package helm-lsp :commands helm-lsp-workspace-symbol)


;; optionally if you want to use debugger
;; (use-package dap-mode)
;; (use-package dap-LANGUAGE) to load the dap adapter for your language

(use-package
 elisp-autofmt
 :ensure t
 :defer t
 :custom (elisp-autofmt-style 'native))

(add-hook
 'c++-ts-mode-hook
 (lambda ()
   (setq
    comment-start "/*"
    comment-end "*/")))

(defun my/hover ()
  "Show function doc using eldoc-box."
  (interactive)
  (eldoc-box-help-at-point))
(add-hook
 'eglot-managed-mode-hook
 (lambda ()
   (eldoc-box-hover-mode -1))) ;; optional: avoid auto popups

(provide 'languages-config)
;;; languages-config.el ends here
