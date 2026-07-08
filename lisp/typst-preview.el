;;; -*- lexical-binding: t; -*-
(use-package typst-preview
  :straight (:type git :host github :repo "havarddj/typst-preview.el")
  :after websocket
  :init
  (setq typst-preview-autostart t)
  (setq typst-preview-open-browser-automatically t)
  
  )

(provide 'typst-preview)
