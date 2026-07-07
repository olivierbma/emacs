;;; -*- lexical-binding: t; -*-
;; basic variables definitions here

;; todo
;; - Popper +
;; - Perspective
;; - Purpose
;; - Expreg


(tool-bar-mode -1) ; hide the icons
(scroll-bar-mode -1) ; hide scrollbar
(setq inhibit-splash-screen t) ; remove welcome screen
(setq use-file-dialog nil)
(setq scroll-margin 8)
(setq scroll-conservatively 10000)

(setq backup-directory-alist `(("." "~/.emacs.d/.saves")))
(setq read-process-output-max (* 8 1024 1024)) ; 8MB
(add-to-list 'load-path "~/.emacs.d/lisp/")
(setq gc-cons-threshold (* 50 1024 1024)) ;; 50 MB

(add-to-list 'default-frame-alist '(fullscreen . maximized))


;; setting of package manager

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el"
                         (or (bound-and-true-p straight-base-dir)
                             user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent
         'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(setq straight-use-package-by-default t)
(setq use-package-always-defer t)
(setq package-native-compile t)


;; setup env variables for all other packages
(use-package
 exec-path-from-shell
 :ensure t
 :defer t
 :init (exec-path-from-shell-initialize))

(use-package
 ediff
 :ensure t
 :custom (ediff-window-setup-function 'ediff-setup-windows-plain))

(use-package general :ensure t :demand t)

;; Single source of truth for the leader key. :keymaps 'override binds into
;; general-override-mode-map, a global minor mode with very high priority in
;; emulation-mode-map-alist, so the leader always fires regardless of major
;; mode or which evil state the buffer happens to be in.
(general-create-definer
 my/leader
 :states '(normal visual motion emacs)
 :keymaps 'override
 :prefix "SPC")

(use-package
 majutsu
 :straight (:host github :repo "0WD0/majutsu")
 :preface
 ;; --- jj annotate (blame) for the current line ---
 (define-derived-mode
  jj-annotate-mode
  special-mode
  "jj-annotate"
  "Major mode for `jj file annotate' output.")

 (defun jj-annotate-line ()
   "Run `jj file annotate' on the current file and jump to the current line."
   (interactive)
   (unless buffer-file-name
     (user-error "Buffer is not visiting a file"))
   (let* ((line (line-number-at-pos))
          (file buffer-file-name)
          (default-directory
           (or (locate-dominating-file file ".jj") default-directory))
          (outbuf (get-buffer-create "*jj annotate*")))
     (with-current-buffer outbuf
       (let ((inhibit-read-only t))
         (erase-buffer)
         (call-process "jj" nil outbuf nil "file" "annotate" file)
         (goto-char (point-min))
         (forward-line (1- line))
         (jj-annotate-mode)))
     (pop-to-buffer outbuf)
     (with-selected-window (get-buffer-window outbuf)
       (recenter))))

 :general
 (my/leader
  "j" '(:ignore t :which-key "jj")
  "j a" #'jj-annotate-line ;; jj annotate current line
  "j j" 'majutsu))

(use-package
 avy
 :defer t
 :ensure t
 :general
 (my/leader
  "a"
  '(:ignore t :which-key "avy")
  "a w"
  'evil-avy-goto-word-1
  "a c"
  'evil-avy-goto-char))


(use-package
 ztree
 :ensure t
 :after (evil)
 :custom
 (evil-motion-state-modes
  (append evil-motion-state-modes '(ztree-mode)))
 :init (setq ztree-draw-unicode-lines t)
 :hook
 (ztreediff-mode
  .
  (lambda ()
    (hl-line-mode 1)
    ;; Keep highlighting visible above ztree's colorful diff states
    (make-local-variable 'hl-line-overlay-priority)
    (setq hl-line-overlay-priority 1)))
 :general
 (:states
  '(motion)
  :keymaps '(ztree-mode-map) "RET"
  'ztree-perform-action ; Open file/directory or launch Ediff
  "SPACE"
  'ztree-perform-action ; Alternative to Enter
  "g"
  'ztree-refresh ; Refresh the view
  "H"
  'ztree-toggle-show-equal-files ; Toggle hiding/showing identical files
  "q"
  'ztree-view-kill ; Quit ztree and return control to jj
  ))

(use-package
 dirvish
 :ensure t
 :demand t
 :config (dirvish-override-dired-mode)
 :preface
 (defun my/toggle-dirvish ()
   "Toggle Dirvish. If a session is active, quit it; otherwise, open it."
   (interactive)
   (if (dirvish-curr)
       (dirvish-quit)
     (dirvish)))

 :general (my/leader "`" 'my/toggle-dirvish))

(use-package ghostel :ensure t :defer t)

(use-package
 evil-ghostel
 :after (ghostel evil)
 :hook (ghostel-mode . evil-ghostel-mode))

(use-package
 ghostel-compile
 :straight nil
 :hook (after-init . ghostel-compile-global-mode))

(use-package
 claude-code-ide
 :ensure t
 :defer t
 :straight (:type git :host github :repo "manzaltu/claude-code-ide.el")
 :custom
 (claude-code-ide-terminal-backend 'ghostel)
 (claude-code-ide-show-claude-window-in-ediff nil)
 :config
 (claude-code-ide-emacs-tools-setup)) ; Optionally enable Emacs MCP tools

(use-package gcmh :ensure t :init (gcmh-mode 1))


;; basic config for emacs
(use-package
 emacs
 :init
 ;; (setq initial-scratch-message nil)
 (defun display-startup-echo-area-message ())
 (message "")
 (defalias 'yes-or-no-p 'y-or-n-p)
 (set-charset-priority 'unicode)
 (setq
  locale-coding-system 'utf-8
  coding-system-for-read 'utf-8
  coding-system-for-write 'utf-8)
 (set-terminal-coding-system 'utf-8)
 (set-keyboard-coding-system 'utf-8)
 (set-selection-coding-system 'utf-8)
 (prefer-coding-system 'utf-8)
 (setq default-process-coding-system '(utf-8-unix . utf-8-unix))
 (setq-default indent-tabs-mode nil)
 (setq-default tab-width 2)
 (set-face-attribute 'default nil)
 (set-face-attribute 'default nil
                     :font "CaskaydiaCove Nerd Font"
                     :height 120)
 (defun ab/enable-line-numbers ()
   "Enable relative line numbers"
   (interactive)
   (display-line-numbers-mode)
   (setq display-line-numbers 'relative))
 (ab/enable-line-numbers))


;; vim like navigation keymap
(use-package
 evil
 :demand t ; no lazy load
 :ensure t
 :init (setq evil-want-integration t) (evil-mode 1)
 :config
 :general (:states '(normal visual) :prefix "" "g c" 'my/toggle-comment))


(use-package
 devdocs
 :defer t
 :ensure t
 :hook
 (c++-ts-mode
  . (lambda () (setq-local devdocs-current-docs '("cpp"))))

 (emacs-lisp-mode
  . (lambda () (setq-local devdocs-current-docs '("elisp"))))
 :general
 (:keymaps
  'devdocs-mode-map
  :states
  'normal
  "H"
  'devdocs-go-back
  "L"
  'devdocs-go-forward
  "TAB"
  'forward-button
  "S-TAB"
  'backward-button
  "RET"
  'push-button))

(with-eval-after-load 'evil
  (evil-set-initial-state 'lsp-bridge-ref-mode 'emacs))

(defun my/toggle-comment ()
  (interactive)
  (if (use-region-p)
      (comment-or-uncomment-region (region-beginning) (region-end))
    (comment-or-uncomment-region
     (line-beginning-position) (line-end-position))))


(use-package
 doom-themes
 :demand t ;; no lazy load
 :config (load-theme 'doom-challenger-deep t))


(use-package
 doom-modeline
 :ensure t
 :defer t
 :init (doom-modeline-mode 1))


(use-package
 which-key
 :demand t
 :custom (which-key-idle-delay 0.15)
 :config (which-key-mode 1))

;; Keep temp files (e.g. /tmp diff files from jj/ztree reviews) out of the
;; recent-files list that the dashboard's "recents" section reads.
(use-package
 recentf
 :ensure t
 :defer t
 :init (recentf-mode 1)
 :config
 (add-to-list
  'recentf-exclude
  (concat
   "\\`" (regexp-quote (expand-file-name temporary-file-directory)))))


;; (use-package msgu
;;   :straight (msgu :type git :host github :repo "jcs-elpa/msgu"
;;                        :files (:defaults "msgu.el"))
;;   :ensure t
;;   :defer t
;;   )

;; language configuration

(require 'languages-config)


(use-package magit :ensure t :defer t)


(use-package nerd-icons :defer t :ensure t)


(require 'capf-config)

;; project management and searching

(require 'project-config)


(use-package
 dashboard
 :defer t
 :ensure t
 :custom
 (dashboard-projects-backend 'projectile)
 (dashboard-projects-switch-function
  'projectile-switch-project-by-name)
 (dashboard-items
  '((projects . 10) ;; Show 10 recent projects
    (recents . 5) ;; Show 5 recent files
    ))
 (dashboard-set-heading-icons t)
 (dashboard-set-file-icons nil)
 (dashboard-startup-banner 'logo) ;; Use Emacs logo
 (dashboard-center-content t)
 (dashboard-item-shortcuts '((recents . "r") (projects . "p")))
 :general
 (:states
  '(normal)
  :keymaps '(dashboard-mode-map)
  :prefix
  ""
  "j"
  'dashboard-next-line
  "k"
  'dashboard-previous-line

  ;; Item actions
  (kbd "RET")
  'dashboard-return
  (kbd "<return>")
  'dashboard-return

  ;; Shortcuts for sections
  "p"
  'dashboard-jump-to-projects
  "r"
  'dashboard-jump-to-recents
  "f"
  'dashboard-jump-to-bookmarks

  "q"
  'quit-window)
 :init (dashboard-setup-startup-hook))


(use-package
 indent-bars
 :defer t
 :ensure t
 :hook (prog-mode . indent-bars-mode)
 :custom
 (indent-bars-treesit-support t)
 (indent-bars-pattern "|"))


(add-hook 'prog-mode-hook 'electric-pair-mode)

(add-hook 'prog-mode-hook #'ab/enable-line-numbers)

(use-package topsy :defer t :ensure t :hook (prog-mode . topsy-mode))

;; (use-package silicon-el
;;   :vc ( :url "https://github.com/iensu/silicon-el" :branch "master" )
;;   )
;; (:url :branch :lisp-dir :main-file :vc-backend :rev :shell-command :make :ignored-files)

(use-package vc-jj :ensure t :defer t)


(use-package
 git-gutter
 :ensure t
 :defer t
 :init (global-git-gutter-mode +1))

(use-package
 popper
 :ensure t
 :defer t
 :custom
 (popper-reference-buffers
  '("\\*Messages\\*"
    "Output\\*$"
    "\\*Async Shell Command\\*"
    help-mode
    compilation-mode
    ghostel-mode
    majutsu-log-mode
    ghostel-compile-view-mode
    devdocs-mode))
 (popper-display-control nil)
 :general
 (my/leader
  "w"
  '(:ignore t :which-key "window/popup")
  "w p"
  'popper-toggle
  "w n"
  'popper-cycle
  "w N"
  'popper-cycle-backwards
  "w k"
  'popper-kill-latest-popup)
 :init (popper-mode +1) (popper-echo-mode +1))

(use-package
 ace-window
 :ensure t
 :defer t
 :custom (aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
 :general
 (my/leader
  "w w" 'ace-window "w s" 'ace-swap-window "w d" 'ace-delete-window))

(use-package
 evil-goggles
 :ensure t
 :demand t
 :custom
 (evil-goggles-blocking-duration 0.10)
 (evil-goggles-async-duration 0.50)
 :config (evil-goggles-mode) (evil-goggles-use-diff-faces))

(use-package
 silicon
 :defer t
 :straight (silicon :type git :host github :repo "iensu/silicon-el")
 :config
 (defun silicon-region-to-clipboard
     (start end &optional universal-arg)
   "Copy an image of the selected region between START and END to the clipboard using `silicon`.
With a universal argument, prompt for options or let you edit them manually."
   (interactive "r\nP")
   (if (not (executable-find silicon-executable-path))
       (error
        "Could not find `silicon` executable, check `silicon-executable-path`.")

     (let* ((region-text (buffer-substring-no-properties start end))
            (temp-file (make-temp-file "silicon-region" nil ".tmp"))
            (is-edit (equal universal-arg '(16)))
            (is-prompt (equal universal-arg '(4)))
            (options
             (cond
              (is-edit
               (read-string "Options: "
                            (-silicon--build-command-opts-string)
                            '-silicon--cmd-options-history
                            (-silicon--build-command-opts-string)))
              (is-prompt
               (let ((theme
                      (funcall silicon-completion-function
                               "Theme: "
                               silicon-available-themes
                               nil
                               (not (null silicon-available-themes))
                               silicon-default-theme))
                     (background-color
                      (read-string "Background color: "
                                   silicon-default-background-color
                                   '-silicon--background-color-history
                                   silicon-default-background-color))
                     (highlight-lines
                      (read-string "Highlight lines: " nil nil nil))
                     (show-line-numbers
                      (yes-or-no-p "Add line numbers? "))
                     (show-window-controls
                      (yes-or-no-p "Add window controls? "))
                     (rounded-corners
                      (yes-or-no-p "Rounded corners? ")))
                 (-silicon--build-command-opts-string
                  :theme theme
                  :background-color background-color
                  :highlight-lines
                  (if (string= "" highlight-lines)
                      nil
                    highlight-lines)
                  :line-numbers show-line-numbers
                  :window-controls show-window-controls
                  :rounded-corners rounded-corners)))
              (t
               (-silicon--build-command-opts-string))))

            (command
             `(,silicon-executable-path
               ,@ (split-string options) "-c" ,temp-file)))

       ;; Write the region to the temporary file
       (with-temp-file temp-file
         (insert region-text))

       ;; Run silicon as a process
       (apply #'start-process "silicon" "*silicon-output*" command)

       ;; Schedule deletion of temp file
       (run-at-time "10 sec" nil
                    (lambda (file)
                      (when (file-exists-p file)
                        (delete-file file)))
                    temp-file)

       (message
        "Copied region to clipboard as image using silicon")))))


(require 'org-config)

(use-package websocket :defer t :ensure t)

(require 'typst-preview)


;; setup dap-mode
(require 'dap-config)


(my/leader
 "b"
 '(:ignore t :which-key "buffer")
 "b b"
 'consult-buffer
 "b k"
 'kill-current-buffer
 "b n"
 'evil-next-buffer
 "b N"
 'evil-prev-buffer)

;; custom personalization
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(doom-modeline-buffer-file-name-style 'relative-from-project)
 '(indent-bars-unspecified-bg-color "gray"))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
