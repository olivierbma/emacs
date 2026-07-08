;;; -*- lexical-binding: t; -*-

(use-package dape
  :ensure t
  :defer t
  :custom
  (dape-buffer-window-arrangement 'right)
  (dape-inlay-hints t)
  :general
  (my/leader
    "d" '(:ignore t :which-key "Dape keybinds")
    "d d" 'dape
    "d r" 'dape-restart
    "d q" 'dape-quit
    "d b" 'dape-breakpoint-toggle
    "d h" 'hydra-dape/body
    ))

(use-package hydra
  :ensure t
  :after dape)

(defhydra hydra-dape (:color pink :hint nil)
  "
^Dape Hydra^
------------------------------------------------
_n_: Next       _e_: Eval    _Q_: Disconnect
_i_: Step In    _b_: Breakpoint
_o_: Step Out   _R_: Restart
_c_: Continue
"
  ("n" dape-next)
  ("i" dape-step-in)
  ("o" dape-step-out)
  ("c" dape-continue)
  ("e" dape-evaluate-expression)
  ("b" dape-breakpoint-toggle)
  ("R" dape-restart)
  ("q" nil "Quit" :color blue)
  ("Q" dape-quit :color blue))


(provide 'dap-config)
