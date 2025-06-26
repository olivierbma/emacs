(require 'general)

(use-package consult
  :ensure t
  :defer t
  )
(use-package consult-projectile
  :ensure t
  :after (consult projectile))

(use-package projectile
  :ensure t
  :init
  (projectile-mode 1)
  :config

  (general-define-key
   :prefix "SPC"
   :states '(normal visual emacs)
   "s r" 'consult-projectile-recentf
   "s f" 'my/smart-file-search
   "s g" 'consult-ripgrep
   "s m" 'consult-man
   "p i" 'projectile-project-info
   "p c" 'projectile-compile-project
   "p r" 'projectile-run-project
   "s p" 'consult-projectile-switch-project
   "s o" 'consult-outline
   "/" 'consult-line
   "`" 'consult-projectile-switch-to-buffer
   "<F5>" 'projectile-run-project
   "S-<F5>" 'projectile-compile-project
   )

  ;; Optional: Configure Projectile to use Consult for switching files
  (setq projectile-switch-project-action #'consult-projectile)

  (add-hook 'compilation-finish-functions
          (lambda (buffer string)
            "Switch to compilation buffer if compilation finished."
            (when (string-match-p "\\*compilation\\*" (buffer-name buffer))
              (switch-to-buffer-other-window buffer))))
  ;;"SPC SPC" '(projectile-switch-to-buffer :which-key "switch project buffer")
  ;;  "SPC p P" '(projectile-switch-project :which-key "switch project"))
  )

(defun my/smart-file-search ()
  "Use consult-projectile if in a project, otherwise use consult-find."
  (interactive)
  (if (projectile-project-p)
      (consult-projectile)
    (consult-fd default-directory)))


(provide 'project-config)
