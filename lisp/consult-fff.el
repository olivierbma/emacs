;;; consult-fff.el --- Async indexed, typo-tolerant file search -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1") (consult "2.0"))
;; Keywords: files, matching

;;; Commentary:
;; A persistent Nushell helper owns each directory's FFF index and watcher.
;; All scanning and searching happens outside Emacs.  Consult supplies the
;; minibuffer UI, optional second-stage filtering, and file preview.
;; See ../docs/consult-fff.md for installation and usage.

;;; Code:

(require 'cl-lib)
(require 'consult)
(require 'project)
(require 'subr-x)

(defvar vertico-sort-override-function)

(defgroup consult-fff nil
  "Indexed, typo-tolerant file search through Consult."
  :group 'consult)

(defconst consult-fff--helper
  (expand-file-name "consult-fff.nu"
                    (file-name-directory (or load-file-name buffer-file-name))))

(defcustom consult-fff-nushell-command
  (let ((local (expand-file-name "var/consult-fff/nushell/bin/nu" user-emacs-directory)))
    (if (file-executable-p local) local "nu"))
  "Nushell executable providing FFF-backed idx commands.
Tested with Nushell 0.114.1.  Version 0.112 does not include idx."
  :type 'string)

(defcustom consult-fff-max-results 200
  "Maximum number of ranked files returned per search."
  :type '(integer :tag "Results" 1))

(defcustom consult-fff-max-processes 3
  "Maximum number of warm directory indexes to retain.
Active minibuffer sessions are never evicted."
  :type '(integer :tag "Processes" 1))

(defcustom consult-fff-idle-timeout 900
  "Seconds to keep an unused index and watcher alive."
  :type 'number)

(defvar consult-fff--processes (make-hash-table :test #'equal))
(defvar consult-fff--history nil)
(defvar consult-fff--grep-history nil)
(defconst consult-fff--protocol-version 2
  "Worker protocol version, used to replace incompatible cached workers.")

(defun consult-fff--byte-index (bytes offset)
  "Convert UTF-8 byte OFFSET within BYTES to an Emacs character index."
  (length (decode-coding-string (substring bytes 0 (max 0 (min offset (length bytes))))
                                'utf-8)))

(defun consult-fff--format-match (match)
  "Format a structured content MATCH for Consult's grep preview and action."
  (let* ((file (plist-get match :relative_path))
         (line (number-to-string (plist-get match :line_number)))
         (content (copy-sequence (plist-get match :line)))
         (bytes (encode-coding-string content 'utf-8))
         (offset (plist-get match :byte_offset)))
    ;; idx returns absolute byte ranges; Emacs text properties use characters.
    (dolist (range (plist-get match :matches))
      (let ((start (consult-fff--byte-index bytes (- (plist-get range :start) offset)))
            (end (consult-fff--byte-index bytes (- (plist-get range :end) offset))))
        (when (< start end)
          (add-face-text-property start end 'consult-highlight-match nil content))))
    (concat (propertize file 'face 'consult-file 'consult--prefix-group file)
            ":" (propertize line 'face 'consult-line-number) ":" content)))

(defun consult-fff--match-positions (query path)
  "Approximate QUERY's matched character positions in PATH.
Nushell does not return FFF's alignment.  Use a local alignment with free
path prefixes/suffixes, gaps, substitutions, and adjacent transpositions.
This affects highlighting only; FFF decides membership and ranking."
  (let* ((query (downcase query))
         (path (downcase path))
         (m (length query))
         (n (length path))
         (case-fold-search t)
         (literal (and (> m 0)
                       ;; Prefer the basename when the same literal appears
                       ;; in both the filename and an ancestor directory.
                       (or (string-match (regexp-quote query) path
                                         (- n (length (file-name-nondirectory path))))
                           (string-match (regexp-quote query) path)))))
    (cond
     (literal (number-sequence literal (+ literal m -1)))
     ;; Bound the work for unusually long paths or pasted queries.
     ((and (> m 0) (<= (* m n) 20000))
      (let ((scores (make-vector (1+ m) nil))
            (steps (make-vector (1+ m) nil))
            (best-score 0) (end 0) positions)
        (aset scores 0 (make-vector (1+ n) 0))
        (cl-loop for i from 1 to m do
                 (let ((row (make-vector (1+ n) 0))
                       (trace (make-vector (1+ n) nil))
                       (previous (aref scores (1- i))))
                   (aset scores i row)
                   (aset steps i trace)
                   (aset row 0 (* -3 i))
                   (cl-loop for j from 1 to n do
                            (let* ((equal-char (= (aref query (1- i)) (aref path (1- j))))
                                   (score (+ (aref previous (1- j)) (if equal-char 4 -3)))
                                   (step 'diagonal)
                                   (left (1- (aref row (1- j))))
                                   (up (- (aref previous j) 3)))
                              (when (> left score) (setq score left step 'left))
                              (when (> up score) (setq score up step 'up))
                              (when (and (> i 1) (> j 1)
                                         (= (aref query (1- i)) (aref path (- j 2)))
                                         (= (aref query (- i 2)) (aref path (1- j))))
                                (let ((swapped (+ 6 (aref (aref scores (- i 2)) (- j 2)))))
                                  (when (> swapped score)
                                    (setq score swapped step 'swap))))
                              (aset row j score)
                              (aset trace j step)))))
        (cl-loop for j from 1 to n
                 for score = (aref (aref scores m) j)
                 when (> score best-score) do (setq best-score score end j))
        (let ((i m) (j end))
          (while (and (> i 0) (> j 0))
            (pcase (aref (aref steps i) j)
              ('diagonal
               (when (= (aref query (1- i)) (aref path (1- j)))
                 (push (1- j) positions))
               (cl-decf i) (cl-decf j))
              ('swap
               (push (1- j) positions)
               (push (- j 2) positions)
               (cl-decf i 2) (cl-decf j 2))
              ('left (cl-decf j))
              ('up (cl-decf i)))))
        positions)))))

(defun consult-fff--highlight (query path)
  "Add Consult match faces for QUERY to a copy of PATH."
  (let ((highlighted (copy-sequence path)))
    (save-match-data
      (dolist (term (split-string (or query "") "[[:space:]]+" t))
        ;; Constraints affect membership; they are not fuzzy search terms.
        (unless (or (string-prefix-p "!" term)
                    (string-match-p (rx (any "*?{}[]")) term))
          (dolist (position (consult-fff--match-positions term path))
            (add-face-text-property position (1+ position)
                                    'consult-highlight-match nil highlighted)))))
    highlighted))

(defun consult-fff--send (process request)
  "Send JSON REQUEST to PROCESS without invoking a shell."
  (process-send-string process (concat (json-serialize request) "\n")))

(defun consult-fff--report-error (process message)
  "Report MESSAGE from PROCESS to its active completion session."
  (with-current-buffer (get-buffer-create "*consult-fff-log*")
    (goto-char (point-max))
    (insert message "\n"))
  (when-let* ((sink (process-get process 'consult-fff-sink)))
    (funcall sink 'flush)
    (funcall sink [indicator failed])
    (funcall sink 'refresh)
    (message "FFF: %s (see *consult-fff-log*)" message)))

(defun consult-fff--receive (process response)
  "Deliver a parsed RESPONSE from PROCESS if its request is still current."
  (let ((id (plist-get response :id))
        (sink (process-get process 'consult-fff-sink)))
    (cond
     ((and (null id) (plist-get response :error))
      (consult-fff--report-error process (plist-get response :error)))
     ((and sink id (equal id (process-get process 'consult-fff-current-id)))
      (if-let* ((error-message (plist-get response :error)))
          (consult-fff--report-error process error-message)
        (funcall sink 'flush)
        (cond
         ((plist-member response :matches)
          (when-let* ((matches (plist-get response :matches)))
            (funcall sink (mapcar #'consult-fff--format-match matches))))
         ((plist-get response :paths)
          (funcall sink (mapcar (apply-partially #'consult-fff--highlight
                                               (process-get process 'consult-fff-query))
                               (plist-get response :paths)))))
        (funcall sink [indicator finished])
        (funcall sink 'refresh))))))

(defun consult-fff--filter (process output)
  "Decode complete JSON lines from PROCESS OUTPUT, retaining partial lines."
  (let* ((lines (split-string (concat (process-get process 'consult-fff-rest) output) "\n"))
         (tail (last lines)))
    (process-put process 'consult-fff-rest (car tail))
    (dolist (line (butlast lines))
      (unless (string-empty-p line)
        (condition-case error-data
            (consult-fff--receive
             process (json-parse-string line :object-type 'plist :array-type 'list
                                        :null-object nil :false-object nil))
          (error (consult-fff--report-error
                  process (format "Invalid helper response: %s" (error-message-string error-data)))))))))

(defun consult-fff--stop (process)
  "Stop PROCESS and remove its cached index."
  (when-let* ((timer (process-get process 'consult-fff-timer)))
    (cancel-timer timer))
  (process-put process 'consult-fff-sink nil)
  (remhash (process-get process 'consult-fff-root) consult-fff--processes)
  (when (process-live-p process)
    (delete-process process)))

(defun consult-fff--trim ()
  "Evict the least recently used inactive indexes above the cache limit."
  (let (inactive)
    (maphash (lambda (_ process)
               (unless (process-get process 'consult-fff-sink)
                 (push process inactive)))
             consult-fff--processes)
    (setq inactive (sort inactive (lambda (a b)
                                   (< (process-get a 'consult-fff-used)
                                      (process-get b 'consult-fff-used)))))
    (while (and inactive (> (hash-table-count consult-fff--processes)
                            (max 1 consult-fff-max-processes)))
      (consult-fff--stop (pop inactive)))))

(defun consult-fff--process (root)
  "Return or start the persistent helper for ROOT."
  (let ((process (gethash root consult-fff--processes)))
    (unless (and process (process-live-p process)
                 (equal (process-get process 'consult-fff-protocol)
                        consult-fff--protocol-version))
      (when process (consult-fff--stop process))
      (unless (executable-find consult-fff-nushell-command)
        (user-error "Nushell missing; see docs/consult-fff.md"))
      (setq process
            (make-process
             :name "consult-fff" :buffer nil :connection-type 'pipe
             :coding 'utf-8-unix :noquery t
             :stderr (get-buffer-create "*consult-fff-log*")
             :command (list consult-fff-nushell-command "--no-config-file"
                            "--no-history" consult-fff--helper root)
             :filter #'consult-fff--filter
             :sentinel
             (lambda (proc event)
               (unless (process-live-p proc)
                 (consult-fff--report-error proc (concat "Helper exited: " (string-trim event)))))))
      (process-put process 'consult-fff-root root)
      (process-put process 'consult-fff-counter 0)
      (process-put process 'consult-fff-protocol consult-fff--protocol-version)
      (puthash root process consult-fff--processes))
    (when-let* ((timer (process-get process 'consult-fff-timer)))
      (cancel-timer timer))
    (process-put process 'consult-fff-used (float-time))
    process))

(defun consult-fff--collection (root &optional operation mode)
  "Build an async collection for ROOT, using OPERATION and content MODE."
  (consult--async-pipeline
   (consult--async-throttle 0.05 0.03)
   (lambda (sink)
     (let (process)
       (lambda (action)
         (pcase action
           ('setup
            (setq process (consult-fff--process root))
            (process-put process 'consult-fff-sink sink)
            (consult-fff--trim)
            (funcall sink action))
           ((pred stringp)
            (if (not (process-live-p process))
                (consult-fff--report-error process "Helper is not running; restart the search")
              (let ((id (1+ (process-get process 'consult-fff-counter))))
                (process-put process 'consult-fff-counter id)
                (process-put process 'consult-fff-current-id id)
                (process-put process 'consult-fff-query action)
                (funcall sink 'flush)
                (funcall sink [indicator running])
                (consult-fff--send
                 process `(:op ,(or operation "find") :mode ,(or mode "plain")
                           :id ,id :query ,action
                           :limit ,consult-fff-max-results)))))
           ((or 'cancel 'destroy)
            (when process
              (process-put process 'consult-fff-current-id nil)
              (when (eq action 'destroy)
                (process-put process 'consult-fff-sink nil)
                (process-put process 'consult-fff-used (float-time))
                (process-put process 'consult-fff-timer
                             (run-at-time consult-fff-idle-timeout nil
                                          #'consult-fff--stop process))))
            (funcall sink action))
           (_ (funcall sink action))))))))

(defun consult-fff--directory (directory)
  "Resolve and validate local search DIRECTORY, defaulting to the project."
  (let ((directory (or directory
                       (when-let* ((project (project-current))) (project-root project))
                       default-directory)))
    (when (file-remote-p directory)
      (user-error "FFF requires a local directory"))
    (unless (file-directory-p directory)
      (user-error "Not a directory: %s" directory))
    (file-name-as-directory (file-truename directory))))

;;;###autoload
(defun consult-fff (&optional directory initial)
  "Find files in DIRECTORY using FFF's indexed, typo-tolerant search.
Default to the current project, or `default-directory' outside a project.
With a prefix argument, prompt for a directory.  INITIAL seeds the query.
Use #query#filter for optional additional Emacs completion filtering."
  (interactive
   (list (when current-prefix-arg
           (read-directory-name "FFF directory: " nil nil t))))
  (let* ((default-directory (consult-fff--directory directory))
           ;; Consult's input splitting sends only the explicit second-stage
           ;; filter to Emacs completion.  Keep the backend's relevance order.
           (vertico-sort-override-function nil)
           (selected
            (consult--read
             (consult-fff--collection default-directory)
             :prompt (format "FFF (%s): " (abbreviate-file-name default-directory))
             :initial initial :sort nil :require-match t :category 'file
             :state (consult--file-preview)
             :history '(:input consult-fff--history))))
      (when selected
        (find-file (expand-file-name selected default-directory)))))

;;;###autoload
(defun consult-fff-grep (&optional directory initial mode)
  "Search file contents in DIRECTORY with FFF's warm content index.
MODE is `plain' (literal, the default), `regex', or `fuzzy'.
INITIAL seeds the query.  With a prefix argument, prompt for DIRECTORY.
Use #query#filter for additional Emacs filtering of the results."
  (interactive
   (list (when current-prefix-arg
           (read-directory-name "FFF content directory: " nil nil t))))
  (setq mode (or mode 'plain))
  (unless (memq mode '(plain regex fuzzy))
    (user-error "Unknown FFF content mode: %s" mode))
  (let ((default-directory (consult-fff--directory directory))
        (vertico-sort-override-function nil))
    (consult--read
     (consult-fff--collection default-directory "grep" (symbol-name mode))
     :prompt (format "FFF %s (%s): " mode (abbreviate-file-name default-directory))
     :initial initial :sort nil :require-match t :category 'consult-grep
     :lookup #'consult--lookup-member :state (consult--grep-state)
     :group #'consult--prefix-group
     :add-history (thing-at-point 'symbol)
     :history '(:input consult-fff--grep-history))))

;;;###autoload
(defun consult-fff-grep-regexp (&optional directory initial)
  "Search contents using a Rust regex in DIRECTORY, seeded by INITIAL."
  (interactive
   (list (when current-prefix-arg
           (read-directory-name "FFF regexp directory: " nil nil t))))
  (consult-fff-grep directory initial 'regex))

;;;###autoload
(defun consult-fff-grep-fuzzy (&optional directory initial)
  "Search contents with typo tolerance in DIRECTORY, seeded by INITIAL."
  (interactive
   (list (when current-prefix-arg
           (read-directory-name "FFF fuzzy directory: " nil nil t))))
  (consult-fff-grep directory initial 'fuzzy))

;;;###autoload
(defun consult-fff-stop ()
  "Release all FFF indexes and filesystem watchers."
  (interactive)
  (dolist (process (hash-table-values consult-fff--processes))
    (consult-fff--stop process)))

(add-hook 'kill-emacs-hook #'consult-fff-stop)

(provide 'consult-fff)
;;; consult-fff.el ends here
