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

(setq ediff-window-setup-function 'ediff-setup-windows-plain)

(use-package vdiff
  :ensure t
  :defer t
  :config
  ;; Like ediff, automatically refine every hunk so the exact words that
  ;; changed within a line are highlighted (not just the whole changed line).
  (setq vdiff-auto-refine t)
  ;; The bindings below live in an evil auxiliary keymap on the vdiff-mode
  ;; minor mode. evil only rebuilds its active keymaps on a state change, and
  ;; vdiff enables the minor mode *after* the buffer is already in normal
  ;; state, so the "," prefix wouldn't activate until you refocused the window
  ;; (e.g. by clicking). Normalizing on the hook makes it work immediately.
  (add-hook 'vdiff-mode-hook #'evil-normalize-keymaps)
  ;; Evil keybinds for vdiff-mode (the local minor mode in diff buffers).
  ;; Bind the whole vdiff command set under "," and add vim-diff-style
  ;; direct keys for the common PR-review actions.
  (general-define-key
   :states 'normal
   :keymaps 'vdiff-mode-map
   ","   vdiff-mode-prefix-map      ; all vdiff commands under the comma prefix
   "q"   'vdiff-quit                ; quit the diff and return to the ztree menu
   "]c"  'vdiff-next-hunk           ; jump to next change (like vim diff)
   "[c"  'vdiff-previous-hunk       ; jump to previous change
   "gs"  'vdiff-send-changes        ; push this hunk to the other buffer
   "gr"  'vdiff-receive-changes     ; pull the other buffer's hunk into this one
   "gf"  'vdiff-refine-this-hunk    ; word-level refinement for this hunk
   "zo"  'vdiff-open-fold           ; reveal context folded around a hunk (vim fold key)
   "zc"  'vdiff-close-fold          ; fold context back up (vim fold key)
   "zR"  'vdiff-open-all-folds
   "zM"  'vdiff-close-all-folds)
  ;; The default vdiff faces just inherit from diff-added/changed/removed,
  ;; which doom-challenger-deep renders too subtly to see. Give them explicit
  ;; backgrounds from the challenger-deep palette so changes pop. The refine
  ;; faces highlight the exact words that changed within a hunk, so make them
  ;; the brightest.
  ;; (custom-set-faces
  ;;  '(vdiff-addition-face    ((t (:background "#1f4636" :foreground "#62d196"))))
  ;;  '(vdiff-subtraction-face ((t (:background "#4a2230" :foreground "#ff5458"))))
  ;;  '(vdiff-change-face      ((t (:background "#33335a" :foreground "#65b2ff"))))
  ;;  '(vdiff-refine-added     ((t (:background "#2f7d54" :foreground "#ffffff" :weight bold))))
  ;;  '(vdiff-refine-changed   ((t (:background "#4f4fa0" :foreground "#ffffff" :weight bold)))))
  )

(defvar ab/ztree-vdiff-window-config nil
  "Window configuration saved before launching vdiff from ztree-diff.
Restored on vdiff quit so we return to the ztree-diff menu.")

(use-package ztree
  :ensure t
  :config
  ;; Force ztree buffers to open in 'motion state so j/k work out of the box
  (setq ztree-draw-unicode-lines t)
  ;; Use vdiff instead of ediff when launching a file comparison from ztree.
  ;; ztree-diff has no customizable backend; it calls `ztree-diff-ediff'
  ;; directly, so override that function to drive vdiff instead.
  ;; `vdiff-files' is autoloaded, so the call below pulls in vdiff on demand.
  ;; Capture the ztree window layout first and restore it via vdiff's on-quit
  ;; callback, so quitting the diff (q / ,q) drops you back into the ztree menu
  ;; just like the original ediff hooks did.
  (advice-add 'ztree-diff-ediff :override
              (lambda (file-a file-b &optional _startup-hooks)
                (setq ab/ztree-vdiff-window-config (current-window-configuration))
                (vdiff-files file-a file-b nil
                             (lambda (&rest _buffers)
                               (when ab/ztree-vdiff-window-config
                                 (set-window-configuration
                                  ab/ztree-vdiff-window-config))))))
  (general-setq evil-motion-state-modes (append evil-motion-state-modes '(ztree-mode)))
  ;; ztreediff-mode is a *major* mode (define-derived-mode), so hook it
  ;; directly rather than guarding ztree-mode-hook on a nonexistent variable.
  (add-hook 'ztreediff-mode-hook
          (lambda ()
            (hl-line-mode 1)
            ;; Keep highlighting visible above ztree's colorful diff states
            (make-local-variable 'hl-line-overlay-priority)
            (setq hl-line-overlay-priority 1)))

  (general-define-key
   :keymaps 'ztree-mode-map
   :states 'motion
   "RET" 'ztree-perform-action       ; Open file/directory or launch Ediff
   "SPACE" 'ztree-perform-action     ; Alternative to Enter
   "g"   'ztree-refresh              ; Refresh the view
   "H"   'ztree-toggle-show-equal-files ; Toggle hiding/showing identical files
   "q"   'ztree-view-kill            ; Quit ztree and return control to jj
   )
  )

(use-package dirvish
  :ensure t
  :defer t
  :init
  (dirvish-override-dired-mode)
  )

(use-package ghostel
  :ensure t
  :defer t
  :config
  (ghostel-compile-global-mode t)
  )
(use-package claude-code-ide
  :straight (:type git :host github :repo "manzaltu/claude-code-ide.el")
  :init

  (setq claude-code-ide-terminal-backend 'ghostel)

  :config
  (claude-code-ide-emacs-tools-setup)
  ) ; Optionally enable Emacs MCP tools

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
                      :font "CaskaydiaCove Nerd Font"
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
  :ensure t
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

(with-eval-after-load 'evil
  (evil-set-initial-state 'lsp-bridge-ref-mode 'emacs))

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

;; Keep temp files (e.g. /tmp diff files from jj/ztree reviews) out of the
;; recent-files list that the dashboard's "recents" section reads.
(use-package recentf
  :init
  (recentf-mode 1)
  :config
  (add-to-list 'recentf-exclude
               (concat "\\`" (regexp-quote (expand-file-name temporary-file-directory)))))

(use-package msgu
  :straight (msgu :type git :host github :repo "jcs-elpa/msgu"
                       :files (:defaults "msgu.el"))
  :ensure t
  :defer t
  )

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

(use-package git-gutter
  :ensure t
  :defer t
  :init 
  (global-git-gutter-mode +1)
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
