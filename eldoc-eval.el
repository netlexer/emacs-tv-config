;;; eldoc-eval.el -- Show eldoc when using M-:

;; Copyright (C) 2011, Thierry Volpiatto, all rights reserved.

;;; This file is NOT part of GNU Emacs

;;; License
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;; Code:
(require 'eldoc)


;;; Minibuffer support.
;;  Enable displaying eldoc info in something else
;;  Than minibuffer when this one is in use.
;;
(defcustom eldoc-in-minibuffer t
  "Turn on eldoc in minibuffer."
  :group 'eldoc
  :type 'bolean)

(defcustom eldoc-in-minibuffer-show-fn 'eldoc-show-in-mode-line
  "A function to display eldoc info.
Should take one arg: the string to display"
  :group 'eldoc
  :type 'function)

(defcustom eldoc-show-in-mode-line-delay 12
  "The time we show eldoc when emacs is idle."
  :group 'eldoc
  :type 'number)

;; Internal.
(defvar eldoc-active-minibuffers-list nil
  "Store actives minibuffers with eldoc enabled.")

(defun eldoc-store-minibuffer ()
  "Store minibuffer buffer name in `eldoc-active-minibuffers-list'.
This function is called by each minibuffer started with eldoc support.
See `with-eldoc-in-minibuffer'."
  (with-selected-window (minibuffer-window)
    (push (buffer-name) eldoc-active-minibuffers-list)))

(defmacro with-eldoc-in-minibuffer (&rest body)
  "Enable eldoc support for minibuffer input that run in BODY."
  (declare (indent 0) (debug t))
  `(let ((timer (and eldoc-in-minibuffer
                     (run-with-idle-timer
                      eldoc-idle-delay
                      'repeat 'eldoc-mode-in-minibuffer))))
     (unwind-protect
         (minibuffer-with-setup-hook
             ;; When minibuffer is activated in body,
             ;; store it.
             'eldoc-store-minibuffer
           ,@body)
       (and timer (cancel-timer timer))
       ;; Each time a minibuffer exit or abort
       ;; his buffer is removed from stack,
       ;; assuming we can only exit the active minibuffer
       ;; on top of stack.
       (setq eldoc-active-minibuffers-list
             (cdr eldoc-active-minibuffers-list)))))

(defun eldoc-show-in-mode-line (str)
  "Display string STR in the mode-line next to minibuffer."
  (let (mode-line-in-non-selected-windows)
    (with-current-buffer (window-buffer
                          (with-selected-frame (selected-frame)
                            (if (fboundp 'window-in-direction)
                                (window-in-direction ; Only emacs24
                                 'above (minibuffer-window))
                                (minibuffer-selected-window))))
      (make-local-variable 'mode-line-format)
      (let ((mode-line-format (concat " " str)))
        (force-mode-line-update nil)
        (sit-for eldoc-show-in-mode-line-delay))
      (force-mode-line-update))))


(defun eldoc-mode-in-minibuffer ()
  "Show eldoc for current minibuffer input."
  (let ((buf (with-selected-window (minibuffer-window)
               (buffer-name))))
    ;; If this minibuffer have been started with
    ;;`with-eldoc-in-minibuffer' give it eldoc support
    ;; and update mode-line, otherwise do nothing.
    (when (member buf eldoc-active-minibuffers-list)
      (let* ((str-all (with-current-buffer buf
                        (minibuffer-completion-contents)))
             (sym     (when str-all
                        (with-temp-buffer
                          (insert str-all)
                          (goto-char (point-max))
                          (unless (looking-back ")\\|\"")
                            (forward-char -1))
                          (eldoc-current-symbol))))
             (doc     (or (eldoc-get-var-docstring sym)
                          (eldoc-get-fnsym-args-string
                           (car (eldoc-fnsym-in-current-sexp))))))
        (when doc (funcall eldoc-in-minibuffer-show-fn doc))))))

(defadvice pp-eval-expression (around with-eldoc activate)
  "This advice enable eldoc support."
  (interactive
   (list (with-eldoc-in-minibuffer
           (read-from-minibuffer "Eval: " nil read-expression-map t
                                 'read-expression-history))))
   ad-do-it)
(global-set-key [remap eval-expression] 'pp-eval-expression)

(provide 'eldoc-eval)
;; eldoc-extensions.el ends here
