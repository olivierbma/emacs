;;; -*- lexical-binding: t; -*-

(require 'general)

(use-package consult :ensure t :defer t)
(use-package consult-projectile :ensure t :after (consult projectile))

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
  "s g" 'consult-ripgrep
  "s m" 'devdocs-lookup
  "s p" 'consult-projectile-switch-project
  "s o" 'consult-outline
  "/" 'consult-line

  "g h" 'projectile-find-other-file))

(defun my/smart-file-search ()
  "Use consult-projectile if in a project, otherwise use consult-find."
  (interactive)
  (if (projectile-project-p)
      (projectile-find-file projectile-project-root)
    ;; (consult-projectile-find-file)
    (consult-fd default-directory)))


(provide 'project-config)
