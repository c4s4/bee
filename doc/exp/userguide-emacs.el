;;******************************************************************************
;;*                                      BEE                                   *
;;******************************************************************************
;; Bee command name
(defvar bee-command "bee")
;; Bee options
(defvar bee-options "-r")
;; build using prompt target
(defun bee-build ()
  "Bee build prompting for target in the minibuffer."
  (interactive)
  ()
  (let 
    ((target-name 
      (read-from-minibuffer "Target: ")))
    (compile (concat bee-command " " bee-options " " target-name))))
;; set F6 as shortcut
(global-set-key [f6]     'bee-build)
;; set compilation window height to 15 lines
(setq compilation-window-height 15)
;; enable compilation window scrolling
(setq compilation-scroll-output 1)
