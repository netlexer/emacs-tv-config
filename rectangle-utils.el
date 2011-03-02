;;; rectangle-utils.el --- Some useful rectangle functions.

;	$Id: rectangle-utils.el,v 1.11 2010/02/17 10:30:05 thierry Exp $

;; Author: Thierry Volpiatto

;; Copyright (C) 2010 Thierry Volpiatto, all rights reserved.

;; Compatibility: GNU Emacs 23.1.92.1

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.


;;; Code:

(defun goto-longest-region-line (beg end)
  "Find the longest line in region and go to it."
  (let* ((real-end  (save-excursion (goto-char end) (end-of-line) (point)))
         (buf-str   (buffer-substring beg real-end))
         (line-list (split-string buf-str "\n"))
         (longest   0)
         (count     0)
         nth-longest-line)
    (loop for i in line-list
         do (progn
              (when (> (length i) longest)
                (setq longest (length i))
                (setq nth-longest-line count))
              (incf count)))
    (goto-char beg)
    (forward-line nth-longest-line)))

(defun extend-rectangle-to-end (beg end)
  "Create a rectangle based on the longest line of region."
  (interactive "r")
  (let ((longest-len (save-excursion
                       (goto-longest-region-line beg end)
                       (length (buffer-substring (point-at-bol) (point-at-eol)))))
        column-beg column-end)
    (goto-char beg) (setq column-beg (current-column))
    (save-excursion (goto-char end) (setq column-end (current-column)))
    (if (not (eq column-beg column-end))
        (progn
          (while (< (point) end)
            (goto-char (point-at-eol))
            (let ((len-line (- (point-at-eol) (point-at-bol))))
              (when (< len-line longest-len)
                (let ((diff (- longest-len len-line)))
                  (insert (make-string diff ? ))
                  (setq end (+ diff end)))))
            (forward-line))
          ;; Go back to END and end-of-line to be sure END is there.
          (goto-char end) (end-of-line) (setq end (point))
          ;; Go back to BEG and push mark to new END.
          (goto-char beg)
          (push-mark end 'nomsg 'activate)
          (setq deactivate-mark  nil))
        (deactivate-mark 'force)
        (error "Error: not in a rectangular region."))))


(defvar rectangle-menu
  "Rectangle Menu:
==============
i  ==>insert,      a==>insert at right.
k  ==>kill,        d==>delete.
o  ==>open,        w==>copy to register.
e  ==>mark to end, y==>yank.
M-w==>copy,        c==>clear.
r  ==>replace,     q==>quit.
C-g==>exit and restore."
  "Menu for command `rectangle-menu'.")

(defun rectangle-menu (beg end)
  (interactive "r")
  (if (and transient-mark-mode (region-active-p))
      (unwind-protect
           (while (let ((input (read-key (propertize rectangle-menu
                                          'face 'minibuffer-prompt))))
                    (case input
                      (?i
                       (let* ((def-val (car string-rectangle-history))
                              (string  (read-string (format "String insert rectangle (Default %s): " def-val)
                                                    nil 'string-rectangle-history def-val)))
                         (string-insert-rectangle beg end string) nil))
                      (?a
                       (let* ((def-val (car string-rectangle-history))
                              (string  (read-string (format "String insert rectangle (Default %s): " def-val)
                                                    nil 'string-rectangle-history def-val)))
                         (rectangle-insert-at-right beg end string) nil))
                      (?k (kill-rectangle beg end) nil)
                      (?\M-w (copy-rectangle beg end) nil)
                      (?d (delete-rectangle beg end) nil)
                      (?o (open-rectangle beg end) nil)
                      (?c (clear-rectangle beg end) nil)
                      (?w (copy-rectangle-to-register (read-string "Register: ") beg end) nil)
                      (?e (extend-rectangle-to-end beg end)
                          (setq beg (region-beginning)
                                end (region-end)) t)
                      (?\C-g (delete-trailing-whitespace)
                             (goto-char beg) nil)
                      (?y (yank-rectangle) nil)
                      (?r
                       (let* ((def-val (car string-rectangle-history))
                              (string  (read-string (format "Replace region by String (Default %s): " def-val)
                                                    nil 'string-rectangle-history def-val)))
                         (string-rectangle beg end string) nil) nil)
                      (?q nil))))
        (deactivate-mark t)
        (message nil))
      (message "No region, activate region please!")))

;; (defun rectangle-insert-at-right (beg end arg &optional string)
;;   "Create a new rectangle based on longest line of region\
;; and insert string at right of it.
;; With prefix arg, insert string at end of each lines (no rectangle)."
;;   (interactive "r\nP")
;;   (let ((def-val (car string-rectangle-history)))
;;     (unless string
;;       (setq string
;;             (read-string
;;              (format "Replace region by String (Default %s): " def-val)
;;              nil 'string-rectangle-history def-val))))
;;   (unless arg
;;     (extend-rectangle-to-end beg end)
;;     (setq end (region-end)))
;;   (goto-char beg) (end-of-line)
;;   (unless arg (setq beg (point)))
;;   (while (< (point) end)
;;     (insert string)
;;     (forward-line) (end-of-line)
;;     (setq end (+ end (length string))))
;;   (insert string))


(defun rectangle-insert-at-right (beg end arg)
  "Create a new rectangle based on longest line of region\
and insert string at right of it.
With prefix arg, insert string at end of each lines (no rectangle)."
  (interactive "r\nP")
  (flet ((incstr (str)
           (if (and str (string-match "[0-9]+" str))
               (let ((rep (match-string 0 str)))
                 (replace-match
                  (int-to-string (1+ (string-to-int rep)))
                  nil t str))
               str)))
    (let (str)
      (unless arg
        (extend-rectangle-to-end beg end)
        (setq end (region-end)))
      (goto-char beg) (end-of-line)
      (unless arg (setq beg (point)))
      (while (< (point) end)
        (let ((init (incstr str)))
          (setq str (read-string "Insert String: " init))
          (insert str)
          (forward-line 1)
          (end-of-line)
          (setq end (+ end (length str)))))
      (setq str (read-string "Insert String: " (incstr str)))
      (insert str))))

(defun copy-rectangle (beg end)
  "Well, copy rectangle, not kill."
  (interactive "r")
  (setq killed-rectangle (extract-rectangle beg end))
  (setq deactivate-mark t))

(provide 'rectangle-utils)

;;; rectangle-utils.el ends here.