;;; lsp-bridge-python.el --- Discover nested Python projects -*- lexical-binding: t; -*-

;;; Commentary:
;; A Python package can live below the Git root.  Starting basedpyright at
;; that package's root lets it discover pyproject.toml and the local .venv.

;;; Code:

(defun my/lsp-bridge-python-project-root (filename)
  "Return the nearest Python project root for local Python FILENAME.
Leave other files and explicit lsp-bridge root callbacks to lsp-bridge."
  (when (and (not (bound-and-true-p lsp-bridge-get-project-path-by-filepath))
             (not (file-remote-p filename))
             (member (file-name-extension filename) '("py" "pyi")))
    (when-let* ((root
                 (locate-dominating-file
                  filename
                  (lambda (directory)
                    (or (file-exists-p (expand-file-name "pyproject.toml" directory))
                        (file-exists-p (expand-file-name "pyrightconfig.json" directory))
                        (file-directory-p (expand-file-name ".venv" directory)))))))
      (directory-file-name (expand-file-name root)))))

(advice-add 'lsp-bridge--get-project-path-func :before-until
            #'my/lsp-bridge-python-project-root)

(provide 'lsp-bridge-python)
;;; lsp-bridge-python.el ends here
