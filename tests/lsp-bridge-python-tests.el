;;; lsp-bridge-python-tests.el --- Python root discovery tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'lsp-bridge-python)

(defvar lsp-bridge-get-project-path-by-filepath nil)

(defmacro my/with-python-project (&rest body)
  "Run BODY in a temporary nested Python project."
  (declare (indent 0))
  `(let* ((root (make-temp-file "lsp-bridge-python-" t))
          (package (expand-file-name "ai" root))
          (source (expand-file-name "src/data.py" package))
          (lsp-bridge-get-project-path-by-filepath nil))
     (unwind-protect
         (progn
           (make-directory (file-name-directory source) t)
           (make-directory (expand-file-name ".git" root))
           ,@body)
       (delete-directory root t))))

(ert-deftest my/lsp-bridge-python-finds-nested-pyproject ()
  (my/with-python-project
    (write-region "" nil (expand-file-name "pyproject.toml" package) nil 'silent)
    (should (equal (my/lsp-bridge-python-project-root source) package))))

(ert-deftest my/lsp-bridge-python-finds-nearest-venv ()
  (my/with-python-project
    (write-region "" nil (expand-file-name "pyproject.toml" root) nil 'silent)
    (make-directory (expand-file-name ".venv" package))
    (should (equal (my/lsp-bridge-python-project-root source) package))))

(ert-deftest my/lsp-bridge-python-finds-pyright-config-for-stubs ()
  (my/with-python-project
    (write-region "{}" nil (expand-file-name "pyrightconfig.json" package) nil 'silent)
    (should (equal (my/lsp-bridge-python-project-root
                    (concat source "i")) package))))

(ert-deftest my/lsp-bridge-python-preserves-other-languages-and-root-callback ()
  (my/with-python-project
    (write-region "" nil (expand-file-name "pyproject.toml" package) nil 'silent)
    (should-not (my/lsp-bridge-python-project-root
                 (expand-file-name "main.rs" package)))
    (let ((lsp-bridge-get-project-path-by-filepath #'ignore))
      (should-not (my/lsp-bridge-python-project-root source)))))

(ert-deftest my/lsp-bridge-python-leaves-remote-files-to-existing-root-discovery ()
  (should-not (my/lsp-bridge-python-project-root "/ssh:example:/project/main.py")))

(ert-deftest my/lsp-bridge-python-expands-abbreviated-home-for-python-process ()
  (cl-letf (((symbol-function 'locate-dominating-file) (lambda (&rest _) "~/")))
    (should (equal (my/lsp-bridge-python-project-root "/tmp/main.py")
                   (directory-file-name (expand-file-name "~/"))))))

;;; lsp-bridge-python-tests.el ends here
