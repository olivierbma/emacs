;;; -*- lexical-binding: t; -*-

(setq load-prefer-newer t) ;; load latest version of bytecompiled files
(setq native-comp-jit-compilation t) ;; enable native compilation

;; PGTK otherwise waits up to 100 ms when showing or hiding LSP popups.
(when (boundp 'pgtk-wait-for-event-timeout)
  (setq pgtk-wait-for-event-timeout 0.001))

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

(setq package-enable-at-startup nil)

(setq native-comp-speed 2)
(setenv "LSP_USE_PLISTS" "true")
