;;; -*- lexical-binding: t -*-
(defcustom +light-theme 'ashen-day
  "Theme used when the system appearance is light."
  :type 'symbol
  :group 'faces)

(defcustom +dark-theme 'ashen-night
  "Theme used when the system appearance is dark."
  :type 'symbol
  :group 'faces)
(defvar +system-appearance nil
  "Last reported system appearance, either `light' or `dark'.")

(defun +system-appearance-changed (appearance)
  "Remember APPEARANCE and update the theme using a graphical frame."
  (setq +system-appearance appearance)
  ;; Notifications may arrive while a terminal frame is selected.
  (when-let* ((frame (seq-find #'display-graphic-p (frame-list))))
    (with-selected-frame frame
      (+load-theme))))

(add-hook! tty-setup-hook :unless-daemonp-call-immediately
  (defun +load-theme (&optional theme)
    "Load THEME, or choose a theme matching the system or terminal."
    (setq theme
          (or theme
              (if (eq (if (display-graphic-p)
                          (or +system-appearance
                              (and (boundp 'ns-system-appearance) ns-system-appearance)
                              'dark)
                        (or (terminal-parameter nil 'background-mode)
                            (frame-parameter nil 'background-mode)))
                      'dark)
                  +dark-theme
                +light-theme)))
    (unless (member theme custom-enabled-themes)
      (mapc #'disable-theme custom-enabled-themes)
      (load-theme theme t))))

(add-hook! after-make-frame-functions
  (defun +load-theme-for-frame (frame)
    "Choose the theme for a newly created graphical FRAME."
    (when (display-graphic-p frame)
      (with-selected-frame frame
        (+load-theme)))))

(provide 'init-theme)
