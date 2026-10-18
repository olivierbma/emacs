;;; consult-fff-tests.el --- Process integration tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'consult-fff)

(defun consult-fff-test--wait (predicate &optional seconds)
  "Wait up to SECONDS for PREDICATE while processing timers and process output."
  (let ((deadline (+ (float-time) (or seconds 8))))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.01))
    (should (funcall predicate))))

(defmacro consult-fff-test--with-directory (&rest body)
  "Run BODY with a temporary ROOT, fixtures, and isolated process cache."
  (declare (indent 0))
  `(let ((root (file-name-as-directory (make-temp-file "consult-fff-test-" t)))
         (consult-fff--processes (make-hash-table :test #'equal)))
     (unwind-protect
         (progn
           (make-directory (expand-file-name "src" root))
           (write-region "project" nil (expand-file-name "src/project-config.el" root) nil 'silent)
           (write-region "other" nil (expand-file-name "unrelated.txt" root) nil 'silent)
           ,@body)
       (consult-fff-stop)
       (delete-directory root t))))

(defun consult-fff-test--search (process query &optional operation mode)
  "Search PROCESS for QUERY, returning its candidates."
  (let (finished paths)
    (process-put process 'consult-fff-sink
                 (lambda (action)
                   (cond ((eq action 'flush) (setq paths nil))
                         ((equal action [indicator finished]) (setq finished t))
                         ((consp action) (setq paths action)))))
    (let ((id (1+ (process-get process 'consult-fff-counter))))
      (process-put process 'consult-fff-counter id)
      (process-put process 'consult-fff-current-id id)
      (process-put process 'consult-fff-query query)
      (consult-fff--send process `(:id ,id :query ,query :limit 20
                                  :op ,(or operation "find") :mode ,(or mode "plain"))))
    (consult-fff-test--wait (lambda () finished))
    paths))

(ert-deftest consult-fff-search-typos-and-warm-reuse ()
  (consult-fff-test--with-directory
    (let ((process (consult-fff--process root)))
      (dolist (query '("project" "projet" "porject" "prjcfg"))
        (should (member "src/project-config.el" (consult-fff-test--search process query))))
      (should (equal process (consult-fff--process root)))
      (should (= 1 (hash-table-count consult-fff--processes)))
      (should-not (consult-fff-test--search process "zzzzzzzzzzzzzzzzzzzz")))))

(ert-deftest consult-fff-json-filenames-and-directory-scope ()
  (consult-fff-test--with-directory
    (let ((path "src/naïve \"quote\" $shell\nnew.el"))
      (write-region "utf8" nil (expand-file-name path root) nil 'silent)
      (should (member path (consult-fff-test--search (consult-fff--process root) "naïve"))))
    (let* ((nested (file-name-as-directory (expand-file-name "src" root)))
           (paths (consult-fff-test--search (consult-fff--process nested) "")))
      (should (member "project-config.el" paths))
      (should-not (member "unrelated.txt" paths)))))

(ert-deftest consult-fff-watcher-adds-and-removes ()
  (consult-fff-test--with-directory
    (let ((process (consult-fff--process root))
          (file (expand-file-name "src/watchunique.el" root)))
      (consult-fff-test--search process "project")
      (write-region "new" nil file nil 'silent)
      (consult-fff-test--wait
       (lambda () (member "src/watchunique.el" (consult-fff-test--search process "watchunique"))))
      (delete-file file)
      (consult-fff-test--wait
       (lambda () (not (member "src/watchunique.el"
                              (consult-fff-test--search process "watchunique"))))))))

(ert-deftest consult-fff-split-json-and-stale-responses ()
  (consult-fff-test--with-directory
    (let ((process (consult-fff--process root)) events)
      (process-put process 'consult-fff-sink (lambda (action) (push action events)))
      (process-put process 'consult-fff-current-id 9)
      (consult-fff--filter process "{\"id\":8,\"paths\":[\"stale\"]}\n{\"id\":9,\"pa")
      (should-not events)
      (consult-fff--filter process "ths\":[\"current\"]}\n")
      (should (member '("current") events))
      (should-not (member '("stale") events))
      (setq events nil)
      (process-put process 'consult-fff-current-id nil)
      (consult-fff--filter process "{\"id\":9,\"paths\":[\"canceled\"]}\n")
      (should-not events))))

(ert-deftest consult-fff-pipeline-cancel-and-idle-release ()
  (consult-fff-test--with-directory
    (with-temp-buffer
      (let* ((consult-fff-idle-timeout 0.05)
             (sink (consult--async-sink))
             (collection (funcall (consult-fff--collection root)
                                  (lambda (action)
                                    (unless (vectorp action) (funcall sink action))))))
        (unwind-protect
            (progn
              (funcall collection 'setup)
              (funcall collection "porject")
              (consult-fff-test--wait (lambda () (member "src/project-config.el"
                                                       (funcall collection nil))))
              (should (get-text-property 4 'face (car (funcall collection nil))))
              (funcall collection 'cancel)
              (should-not (process-get (gethash root consult-fff--processes)
                                      'consult-fff-current-id)))
          (funcall collection 'destroy))
        (consult-fff-test--wait (lambda () (zerop (hash-table-count consult-fff--processes))))))))

(ert-deftest consult-fff-lru-keeps-active-index ()
  (consult-fff-test--with-directory
    (let* ((consult-fff-max-processes 1)
           (first (consult-fff--process root))
           (second (consult-fff--process (file-name-as-directory (expand-file-name "src" root)))))
      (process-put second 'consult-fff-sink #'ignore)
      (consult-fff--trim)
      (should-not (process-live-p first))
      (should (process-live-p second))
      (should (= 1 (hash-table-count consult-fff--processes))))))

(ert-deftest consult-fff-restarts-dead-worker ()
  (consult-fff-test--with-directory
    (let ((first (consult-fff--process root)))
      (delete-process first)
      (let ((second (consult-fff--process root)))
        (should-not (eq first second))
        (should (member "src/project-config.el" (consult-fff-test--search second "porject")))))))

(ert-deftest consult-fff-rejects-remote-directory ()
  (should-error (consult-fff "/ssh:example.invalid:/tmp/") :type 'user-error))

(ert-deftest consult-fff-highlight-literal-abbreviation-and-typos ()
  (let ((path "src/project-config.el"))
    (dolist (case '(("project" . (4 5 6 7 8 9 10))
                    ("porject" . (4 5 6 7 8 9 10))
                    ("projet" . (4 5 6 7 8 10))
                    ("prjcfg" . (4 5 7 12 15 17))
                    ("prohect" . (4 5 6 8 9 10))))
      ;; `projet' omits c, so only the actual corresponding letters light up.
      (let* ((expected (cdr case))
             (highlighted (consult-fff--highlight (car case) path)))
        (should (equal highlighted path))
        (should (equal (cl-loop for i below (length path)
                                when (get-text-property i 'face highlighted) collect i)
                       expected))))
    (should-not (text-properties-at 4 path))))

(ert-deftest consult-fff-highlight-constraints-case-and-empty-input ()
  (let* ((path "src/project-config.el")
         (highlighted (consult-fff--highlight "!src/ *.el PORJECT" path)))
    (should (equal (cl-loop for i below (length path)
                            when (get-text-property i 'face highlighted) collect i)
                   '(4 5 6 7 8 9 10)))
    (should-not (text-properties-at 0 (consult-fff--highlight "" path)))
    (should-not (text-properties-at 0 (consult-fff--highlight "!src/ *.el" path))))
  (should (equal (consult-fff--match-positions "naïve" "NAÏVE.el") '(0 1 2 3 4)))
  (should (equal (consult-fff--match-positions "proj" "proj/src/proj.el") '(9 10 11 12))))

(ert-deftest consult-fff-content-modes-and-shared-worker ()
  (consult-fff-test--with-directory
    (write-region "header\nnaïve α needle needle\nlast\n" nil
                  (expand-file-name "src/project-config.el" root) nil 'silent)
    (let ((process (consult-fff--process root)))
      (should (consult-fff-test--search process "project"))
      (dolist (query-mode '(("needle" "plain") ("n.edle" "regex") ("nedle" "fuzzy")))
        (let ((matches (consult-fff-test--search process (car query-mode) "grep" (cadr query-mode))))
          (should (= (length matches) 1))
          (should (equal (car matches) "src/project-config.el:2:naïve α needle needle"))))
      ;; Plain mode treats regex punctuation literally.
      (should-not (consult-fff-test--search process "n.edle" "grep" "plain"))
      (should-not (consult-fff-test--search process "" "grep" "plain"))
      (should (consult-fff-test--search process "needle" "grep" "plain"))
      (should (eq process (consult-fff--process root))))))

(ert-deftest consult-fff-content-highlight-and-jump-unicode-path ()
  (consult-fff-test--with-directory
    (let* ((relative "src/name:with\nnewline.txt")
           (file (expand-file-name relative root))
           (default-directory root))
      (write-region "header\nnaïve α needle needle\nlast\n" nil file nil 'silent)
      (let* ((candidate (car (consult-fff-test--search
                             (consult-fff--process root) "needle" "grep" "plain")))
             (content-start (+ (length relative) 3))
             (position (consult--grep-position candidate #'find-file-noselect))
             (marker (car position)))
        (unwind-protect
            (progn
              (should (equal (substring candidate content-start) "naïve α needle needle"))
              (should (eq (get-text-property (+ content-start 8) 'face candidate)
                          'consult-highlight-match))
              (should-not (get-text-property (+ content-start 7) 'face candidate))
              (with-current-buffer (marker-buffer marker)
                (goto-char marker)
                (should (= (line-number-at-pos) 2))
                (should (looking-at "needle"))))
          (when (markerp marker)
            (kill-buffer (marker-buffer marker))))))))

(ert-deftest consult-fff-content-watcher-updates-content ()
  (consult-fff-test--with-directory
    (let* ((process (consult-fff--process root))
           (file (expand-file-name "src/project-config.el" root)))
      (should-not (consult-fff-test--search process "contentwatchunique" "grep" "plain"))
      (write-region "contentwatchunique\n" nil file nil 'silent)
      (consult-fff-test--wait
       (lambda () (consult-fff-test--search process "contentwatchunique" "grep" "plain")))
      (write-region "changed\n" nil file nil 'silent)
      (consult-fff-test--wait
       (lambda () (not (consult-fff-test--search process "contentwatchunique" "grep" "plain")))))))

(ert-deftest consult-fff-replaces-incompatible-worker ()
  (consult-fff-test--with-directory
    (let ((first (consult-fff--process root)))
      (process-put first 'consult-fff-protocol 1)
      (let ((second (consult-fff--process root)))
        (should-not (process-live-p first))
        (should-not (eq first second))
        (should (consult-fff-test--search second "project"))))))

;;; consult-fff-tests.el ends here
