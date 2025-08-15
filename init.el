;; basic variables definitions here

(tool-bar-mode -1)  ; hide the icons
(scroll-bar-mode -1); hide scrollbar
(setq inhibit-splash-screen t) ; remove welcome screen
(setq use-file-dialog nil) 
(setq scroll-margin 8)
(setq scroll-conservatively 10000)

(setq backup-directory-alist `(("." "~/.emacs.d/.saves")))
(setq read-process-output-max (* 8 1024 1024)) ; 8MB
(add-to-list 'load-path "~/.emacs.d/lisp/")
(setq gc-cons-threshold (* 50 1024 1024)) ;; 50 MB


;; setting of package manager

(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(setq straight-use-package-by-default t)
(setq use-package-always-defer t)
(setq package-native-compile t)


;; setup env variables for all other packages
(use-package exec-path-from-shell
  :ensure t
  :defer t
  :init
  (exec-path-from-shell-initialize)
  )

;; performant terminal emulator in emacs
(use-package vterm
  :ensure t
  )

(use-package gcmh
  :init
  (gcmh-mode 1))


;; package for setting keybinds
(use-package general
  :ensure t
  :defer t
  )

;; basic config for emacs
(use-package emacs
  :init
  ;; (setq initial-scratch-message nil)
  (defun display-startup-echo-area-message())
  (message "")
  (defalias 'yes-or-no-p 'y-or-n-p)
  (set-charset-priority 'unicode)
  (setq locale-coding-system 'utf-8
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
                      :font "JetBrainsMono Nerd Font"
                      :height 120)
  (defun ab/enable-line-numbers()
    "Enable relative line numbers"
    (interactive)
    (display-line-numbers-mode)
    (setq display-line-numbers 'relative)
    )
  (ab/enable-line-numbers )
  )



;; vim like navigation keymap
(use-package evil
  :demand t ; no lazy load
  :init
  (setq evil-want-integration t)
  :config

  (evil-set-leader '(normal visual emacs) (kbd "SPC"))
  (general-define-key
   :prefix ""
   :states '(normal visual)
   "gc" 'my/toggle-comment
   )
  (evil-mode 1)
  )

(defun my/toggle-comment ()
  (interactive)
  (if (use-region-p)
      (comment-or-uncomment-region (region-beginning) (region-end))
    (comment-or-uncomment-region (line-beginning-position) (line-end-position))))


(use-package doom-themes
  :demand t ;; no lazy load
  :config
  (load-theme 'doom-challenger-deep t))


(use-package doom-modeline
  :ensure t
  :defer t
  :init (doom-modeline-mode 1))


(use-package which-key
  :demand t
  :init
  (setq which-key-idle-delay 0.2) ; instead of 1s
  :config
  (which-key-mode 1 ))


;; language configuration

(require 'languages-config)


(use-package magit
  :ensure t
  ;; :defer t
  :init
  (general-define-key
   :prefix "SPC"
   :states '(normal)
   "m g" 'magit
   "m f" 'magit-fetch
   "m c" 'magit-commit
   )

  )


(use-package nerd-icons
  :defer t
  :ensure t)


(require 'capf-config)

;; project management and searching

(require 'project-config)


(use-package dashboard
  :defer t
  :ensure t
  :init
  (setq initial-buffer-choice 'dashboard-open)
  :config
  ;; Set projectile as the projects backend
  (setq dashboard-projects-backend 'projectile)

  ;; Set the action to take when clicking on a project
  (setq dashboard-projects-switch-function 'projectile-switch-project-by-name)

  ;; Configure dashboard items
  (setq dashboard-items '((projects . 10 )  ;; Show 10 recent projects
                          (recents . 5)    ;; Show 5 recent files
                          ) ;; Show 5 bookmarks
        dashboard-set-heading-icons t
        dashboard-set-file-icons t
        dashboard-startup-banner 'logo   ;; Use Emacs logo
        dashboard-center-content t)      ;; Center content

  (setq dashboard-item-shortcuts '(
                                 (recents . "r")
                                 (projects . "p")))
  (general-define-key
   :keymaps 'dashboard-mode-map
   :prefix ""
   :states 'normal
   ;; Navigation
    "j" 'dashboard-next-line
    "k" 'dashboard-previous-line
    
    ;; Item actions
    (kbd "RET") 'dashboard-return
    (kbd "<return>") 'dashboard-return
    
    ;; Shortcuts for sections
    "p" 'dashboard-jump-to-projects
    "r" 'dashboard-jump-to-recents
    "f" 'dashboard-jump-to-bookmarks

    "q" 'quit-window
   )

  ;; Initialize dashboard (this also tries to set up startup)
  (dashboard-setup-startup-hook)


  )


(use-package indent-bars
  :defer t
  :ensure t
  :hook (prog-mode . indent-bars-mode)
  :custom
  (indent-bars-treesit-support t)
  :config
  (setq indent-bars-pattern "|"))


(add-hook 'prog-mode-hook 'electric-pair-mode)

(add-hook 'prog-mode-hook #'ab/enable-line-numbers)

(use-package topsy
  :defer t
  :ensure t
  :hook
  (prog-mode . topsy-mode))

;; (use-package silicon-el
;;   :vc ( :url "https://github.com/iensu/silicon-el" :branch "master" )
;;   )
;; (:url :branch :lisp-dir :main-file :vc-backend :rev :shell-command :make :ignored-files)

(use-package vc-jj
  :ensure t
  :defer t
  :init
  )

(use-package jj-mode
  :ensure t
  :defer t
  :straight (:host github :repo "bolivier/jj-mode.el")
  ;; :after magit
  :init
  (require 'magit)
  )

(use-package silicon
  :straight (silicon :type git :host github :repo "iensu/silicon-el")
  :config
(defun silicon-region-to-clipboard (start end &optional universal-arg)
  "Copy an image of the selected region between START and END to the clipboard using `silicon`.
With a universal argument, prompt for options or let you edit them manually."
  (interactive "r\nP")
  (if (not (executable-find silicon-executable-path))
      (error "Could not find `silicon` executable, check `silicon-executable-path`.")

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
                    (highlight-lines (read-string "Highlight lines: " nil nil nil))
                    (show-line-numbers (yes-or-no-p "Add line numbers? "))
                    (show-window-controls (yes-or-no-p "Add window controls? "))
                    (rounded-corners (yes-or-no-p "Rounded corners? ")))
                (-silicon--build-command-opts-string
                 :theme theme
                 :background-color background-color
                 :highlight-lines (if (string= "" highlight-lines) nil highlight-lines)
                 :line-numbers show-line-numbers
                 :window-controls show-window-controls
                 :rounded-corners rounded-corners)))
             (t (-silicon--build-command-opts-string))))

           (command `(,silicon-executable-path
                      ,@ (split-string options)
                      "-c"
                      ,temp-file)))

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

      (message "Copied region to clipboard as image using silicon"))))

  )



(require 'org-config)

(use-package websocket
  :defer t
  :ensure t)

(require 'typst-preview)


;; setup dap-mode
(require 'dap-config)



(general-define-key
   :states '(normal)
   :prefix "SPC"
   :keymaps '(general-default-keymaps dired-mode-map compilation-mode-map emacs-lisp-compilation-mode)
   "s b" 'consult-buffer
   "b k" 'kill-current-buffer
   "b n" 'evil-next-buffer
   "b N" 'evil-prev-buffer
   )

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
