;;; -*- lexical-binding: t; -*-

(require 'general)

(use-package consult :ensure t :defer t)
(use-package consult-projectile :ensure t :after (consult projectile))
(use-package consult-fff
  :straight nil
  :commands (consult-fff consult-fff-stop consult-fff-grep
                         consult-fff-grep-regexp consult-fff-grep-fuzzy))

(use-package
 projectile
 :ensure t
 :init (projectile-mode 1)
 :config


 ;; Optional: Configure Projectile to use Consult for switching files
 (setq projectile-switch-project-action #'consult-projectile)

 ;; Don't treat temp dirs (e.g. /tmp diff files from jj/ztree reviews) as
 ;; projects, so they stay out of the dashboard's projects list. This filters
 ;; what `projectile-relevant-known-projects' returns (what dashboard shows).
 (setq projectile-ignored-project-function
       (lambda (project-root)
         (string-prefix-p
          (expand-file-name temporary-file-directory)
          (expand-file-name project-root))))

 (add-hook
  'compilation-finish-functions
  (lambda (buffer string)
    "Switch to compilation buffer if compilation finished."
    (when (string-match-p "\\*compilation\\*" (buffer-name buffer))
      (switch-to-buffer-other-window buffer))))
 ;;"SPC SPC" '(projectile-switch-to-buffer :which-key "switch project buffer")
 ;;  "SPC p P" '(projectile-switch-project :which-key "switch project"))
 :general
 (my/leader
  "b p" 'consult-projectile-switch-to-buffer ;; buffers in current project

  "p" '(:ignore t :which-key "project")
  "p i" 'projectile-project-info
  "p c" 'projectile-compile-project
  "p r" 'projectile-run-project
  "p t" 'projectile-test-project

  "s" '(:ignore t :which-key "search")
  "s r" 'consult-projectile-recentf
  "s f" 'my/smart-file-search
  "s F" 'my/directory-file-search
  "s g" 'consult-fff-grep
  "s G" 'consult-fff-grep-fuzzy
  "s m" 'devdocs-lookup
  "s p" 'consult-projectile-switch-project
  "s o" 'consult-outline
  "/" 'consult-line

  "g h" 'projectile-find-other-file))

(defun my/smart-file-search (&optional choose-directory)
  "Search indexed project files, or choose a directory with a prefix argument."
  (interactive "P")
  (consult-fff
   (cond
    (choose-directory (read-directory-name "FFF directory: " nil nil t))
    ((projectile-project-p) (projectile-project-root))
    (t default-directory))))

(defun my/directory-file-search (&optional choose-directory)
  "Search indexed files below the current directory.
With CHOOSE-DIRECTORY, prompt for a different directory."
  (interactive "P")
  (consult-fff (if choose-directory
                   (read-directory-name "FFF directory: " nil nil t)
                 default-directory)))


(provide 'project-config)
