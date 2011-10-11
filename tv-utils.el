;;; tv-utils.el --- Some useful functions for Emacs. 
;; 
;; Author: ThierryVolpiatto
;; Maintainer: ThierryVolpiatto
;; 
;; Created: mar jan 20 21:49:07 2009 (+0100)
;; Version: 
;; URL: 
;; Keywords: 
;; Compatibility: 
;; 
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

(require 'cl)

;;; Global keys
;;
;;
(global-set-key (kbd "<f5> r")    'find-file-as-root)
(global-set-key (kbd "C-c Y")     'tv-yank-from-screen)
(global-set-key (kbd "C-c C")     'tv-copy-for-screen)
(global-set-key [C-left]          'screen-top)
(global-set-key [C-right]         'screen-bottom)
(global-set-key (kbd "C-<")       'other-window-backward)
(global-set-key (kbd "C->")       'other-window)
(global-set-key (kbd "<f11> s c") 'go-to-scratch)
(global-set-key (kbd "C-x r a")   'tv-append-to-register)
(global-set-key (kbd "C-x r L")   'list-registers)
(global-set-key (kbd "C-c t r")   'translate-at-point)
(global-set-key (kbd "<f5> c")    'tv-toggle-calendar)
(global-set-key (kbd "C-c h e")   'tv-tail-echo-area-messages)
(global-set-key (kbd "C-c k")     'tv-kill-backward)
(global-set-key (kbd "C-d")       'tv-delete-char)
(global-set-key (kbd "C-x C-'")   'tv-toggle-resplit-window)

;; mount-and-umount-sshfs 

;;;###autoload
(defun mount-sshfs (fs mp)
  (interactive (list (read-string "FileSystem: "
                                  "thievol:/home/thierry")
                     (read-directory-name "MountPoint: "
                                          "/home/thierry/"
                                          "/home/thierry/sshfs-thievol/"
                                          t
                                          "sshfs-thievol")))
  (set-buffer (get-buffer-create "*sshfs*"))
  (text-mode) (erase-buffer) (insert "=====*sshfs*=====\n\n")
  (if (> (length (cddr (directory-files mp))) 0)
      (insert (format "Directory %s is busy, mountsshfs aborted" mp))
      (call-process-shell-command "sshfs" nil t nil (format "%s %s" fs mp))
      (if (= (length (cddr (directory-files mp))) 0)
          (insert (format "Failed to mount remote filesystem %s on %s" fs mp))
          (insert (format "%s Mounted successfully on %s" fs mp)))))
  

;;;###autoload
(defun umount-sshfs (mp)
  (interactive (list (read-directory-name "MountPoint: "
                                          "/home/thierry/"
                                          "/home/thierry/sshfs-thievol/"
                                          t
                                          "sshfs-thievol")))
  (if (equal (pwd) (format "Directory %s" mp))
      (message "Filesystem is busy can't umount!")
      (progn
        (if (>= (length (cddr (directory-files mp))) 0)
            (progn
              (set-buffer (get-buffer-create "*sshfs*"))
              (erase-buffer) (insert "=====*sshfs*=====\n\n")
              (text-mode) (goto-char (point-min))
              (forward-line 2) (delete-region (point) (point-max))
              (and (call-process-shell-command "fusermount" nil t nil (format "-u %s" mp))
                   (insert (format "%s Successfully unmounted" mp)))
              (display-buffer "*sshfs*"))
            (message "No existing remote filesystem to unmount!")))))

;;;###autoload
(defun thievol-connect ()
  "sshfs mount of thievol."
  (interactive)
  (mount-sshfs "thievol:" "~/sshfs-thievol")
  (anything-find-files-1 "~/sshfs-thievol"))

;;;###autoload
(defun thievol-disconnect ()
  "sshfs umount of thievol."
  (interactive)
  (umount-sshfs "~/sshfs-thievol"))

;; find-file-as-root 
;;;###autoload
(defun find-file-as-root (file)
  (interactive "fFindFileAsRoot: ")
  (find-file (concat "/su::" (expand-file-name file))))

;; get-ip 
;; get my external ip (need my python script)
;;;###autoload
(defun tv-get-ip ()
  "get my ip"
  (interactive)
  (let ((my-ip (with-temp-buffer
                 (call-process "get_IP.py" nil t nil)
                 (buffer-string))))
    (message "%s" (replace-regexp-in-string "\n" "" my-ip))))

;; network-info 
(defun tv-network-info (network)
  (let ((info (loop for (i . n) in (network-interface-list)
                 when (string= network i)
                 return (network-interface-info i))))
    (when info
      (destructuring-bind (address broadcast netmask mac state)
          info
        (list :address address :broadcast broadcast :netmask netmask :mac (cdr mac) :state state)))))


(defun tv-network-state (&optional network)
  (interactive)
  (let* ((network (or network (read-string "Network: " "wlan0")))
         (info (car (last (getf (tv-network-info network) :state))))
         (state (if info (symbol-name info) "down")))
    (if (interactive-p)
        (message "%s is %s" network state)
        state)))

;; Crontab 
;;;###autoload
(defun crontab (min hr month-day month week-day progr)
  "Insert interactively crontab line at point.
Run first crontab -e in shell and when emacsclient popup run M-x crontab."
  (interactive "sMin (0 to 59 or 0-59/every_x_mn or *): \
\nsHour (0 to 23 or 0-59/every_x_ hr or *): \
\nsDayOfMonth (1 to 31 or *): \
\nsMonth (1 to 12 or *): \
\nsDayOfWeek (0 to 7 or x,y,z or *): \nsCommand: ")
  (let ((abs-prog (with-temp-buffer
                    (call-process "which" nil t nil (format "%s" progr))
                    (buffer-string))))
    (insert
     (concat min " " hr " " month-day " " month " " week-day " " abs-prog))))

;; Madagascar 

;;;###autoload
(defun* tv-convert-euro-to-mga (eur-amount &key (eur-mga-value 3.77))
  (interactive "nEuroAmount: ")
  (if current-prefix-arg
      (setq eur-mga-value (read-number "NewValueFor10000MGA: ")))
  (let* ((1euro-value (/ 10000 eur-mga-value))
         (result (/ (round (* 100 (* eur-amount 1euro-value)))
                    100.00)))
    (message "%s Euros = %s Ariary (Based on 10000 MGA = %s Euros)"
             eur-amount
             (int-to-string result)
             eur-mga-value)))

;;;###autoload
(defun* tv-convert-mga-to-euro (mga-amount &key (eur-mga-value 3.77))
  (interactive "nMgaAmount: ")
  (if current-prefix-arg
      (setq eur-mga-value (read-number "NewValueFor10000MGA: ")))
  (let* ((1mga-value (/ eur-mga-value 10000))
         (result (/ (round (* 100
                              (* mga-amount 1mga-value)))
                    100.00)))
    (message "%s Ariary = %s Euro (Based on 10000 MGA = %s Euros)"
             mga-amount
             (int-to-string result)
             eur-mga-value)))


;; tv-yank-from-screen 

(defvar screen-exchange-file "~/.screen_exchange")
;;;###autoload
(defun tv-yank-from-screen (arg)
  "Yank text copied in a GNU/screen session."
  (interactive "P")
  (let* ((content  (with-current-buffer
                       (find-file-noselect screen-exchange-file)
                       (prog1
                           (buffer-substring (point-min) (point-max))
                         (kill-buffer))))
         (len      (length content))
         (one-line (replace-regexp-in-string "\n" "" content)))
    ;; With prefix arg don't remove new lines.
    (if arg (insert content) (insert one-line))
    (forward-char len)))

;;;###autoload
(defun tv-copy-for-screen (arg beg end)
  "Copy region without newlines in `screen-exchange-file'."
  (interactive "P\nr")
  (let ((region (buffer-substring-no-properties beg end))
        (require-final-newline nil))
    (with-current-buffer
        (find-file-noselect screen-exchange-file)
      (goto-char (point-min))
      (erase-buffer)
      (if arg
          ;; With prefix arg don't remove new lines.
          (insert region)
          (insert (replace-regexp-in-string "\n" "" region)))
      (save-buffer)
      (shell-command "screen -X readbuf > /dev/null")
      (kill-buffer))))

;; Chrono-func 
;;;###autoload
(defmacro chrono-func (fn &rest args)
  `(let* ((init-time    (cadr (current-time)))
          (final-result (funcall ,fn ,@args))
          (final-time   (- (cadr (current-time)) init-time)))
     (message "Time:%2s s" final-time)
     final-result))

;; cat-like-cat 
;;;###autoload
(defun cat (file)
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

;; Show-current-face 
;;;###autoload
(defun whatis-face ()
  (interactive)
  (message "CurrentFace: %s"
           (get-text-property (point) 'face)))

;; mcp 
;;;###autoload
(defun mcp (file &optional list-of-dir)
  "Copy `file' in multi directory.
At each prompt of directory add + to input
to be prompt for next directory.
When you do not add a + to directory name
input is finish and function executed"
  (interactive "fFile: ")
  (let* ((dest-list nil)
         (final-list
          (if list-of-dir
              list-of-dir
              (multi-read-name 'read-directory-name))))
    (loop for i in final-list
       do
         (copy-file file i t))))

;; Multi-read-name 
;;;###autoload
(defun* multi-read-name (&optional (fn 'read-string))
  "Prompt as many time you add + to end of prompt.
Return a list of all inputs in `var'.
You can specify input function to use."
  (let (var)
    (labels ((multiread ()
               (let ((stock)
                     (str (funcall fn (cond ((eq fn 'read-string)
                                             "String(add + to repeat): ")
                                            ((eq fn 'read-directory-name)
                                             "Directory(add + to repeat): ")
                                            (t
                                             "File(add + to repeat): ")))))
                 (push (replace-regexp-in-string "\+" "" str) stock)
                 (cond ((string-match "\+" str)
                        (push (car stock) var)
                        (multiread))
                       (t
                        (push (car stock) var)
                        (nreverse var))))))
      
      (multiread))))


;; move-to-window-line 
;;;###autoload
(defun screen-top (&optional n)
  "Move the point to the top of the screen."
  (interactive "p")
  (move-to-window-line (or n 0)))

;;;###autoload
(defun screen-bottom (&optional n)
  "Move the point to the bottom of the screen."
  (interactive "P")
  (move-to-window-line (- (prefix-numeric-value n))))

;; switch-other-window 
;; C-x o inversé de n windows(optional)
;;;###autoload
(defun other-window-backward (&optional n)
  "Move to other window or frame.
With a prefix arg move N window forward or backward
depending the value of N is positive or negative."
  (interactive "p")
  (other-window (- (or n 1)) t)
  (select-frame-set-input-focus (selected-frame)))

;; Persistent-scratch 
;;;###autoload
(defun go-to-scratch ()
  (interactive)
  (unless (buffer-file-name (get-buffer "*scratch*"))
    (when (get-buffer "*scratch*") (kill-buffer "*scratch*")))
  (if (and (get-buffer "*scratch*")
           (buffer-file-name (get-buffer "*scratch*")))
      (progn (switch-to-buffer "*scratch*") (lisp-interaction-mode))
      (find-file "~/.emacs.d/save-scratch.el")
      (rename-buffer "*scratch*")
      (lisp-interaction-mode)
      (use-local-map lisp-interaction-mode-map)
      (when (eq (point-min) (point-max))
        (insert ";; SCRATCH BUFFER\n;; ==============\n\n"))
      (current-buffer)))

;; registers-config 

;; Redefine append-to-register with a "\n"
;;;###autoload
(defun tv-append-to-register (register start end &optional delete-flag)
  "Append region to text in register REGISTER.
With prefix arg, delete as well.
Called from program, takes four args: REGISTER, START, END and DELETE-FLAG.
START and END are buffer positions indicating what to append."
  (interactive "cAppend to register: \nr\nP")
  (let ((reg  (get-register register))
        (text (filter-buffer-substring start end)))
    (set-register
     register (cond ((not reg) text)
                    ((stringp reg) (concat reg "\n" text))
                    (t (error "Register does not contain text")))))
  (if delete-flag (delete-region start end)))

;; Stardict 
(defun translate-at-point ()
  (interactive)
  (let* ((word (thing-at-point 'word))
         (tooltip-hide-delay 30)
         (result
          (condition-case nil
              (shell-command-to-string (format "LC_ALL=\"fr_FR.UTF-8\" sdcv -n %s" word))
            (error nil))))
    (setq result (replace-regexp-in-string "^\\[ color=\"blue\">\\|</font>\\|\\]" "" result))
    (if result
        (with-current-buffer (get-buffer-create "*Dict*")
          (erase-buffer)
          (save-excursion
            (insert result) (fill-region (point-min) (point-max)))
          ;; Assume dict buffer is in `special-display-buffer-names'.
          (switch-to-buffer-other-frame "*Dict*")
          (view-mode 1))
        (message "Nothing found."))))

;; Get-mime-type-of-file 
(defun file-mime-type (fname)
  "Get the mime-type of fname"
  (interactive "fFileName: ")
  (if (interactive-p)
      (message "%s" (mailcap-extension-to-mime (file-name-extension fname t)))
      (mailcap-extension-to-mime (file-name-extension fname t))))

;; Eval-region 
(defun tv-eval-region (beg end)
  (interactive "r")
  (eval-region beg end t))

;; String-processing 

;; like `make-string' :-)
(defmacro *string (str num)
  `(let ((str-lis))
    (dotimes (n ,num)
      (push ,str str-lis))
    (mapconcat #'(lambda (i) i) str-lis "")))
    
(defmacro +string (str-0 str-1)
  `(let ((str-lis (list ,str-0 ,str-1)))
     (mapconcat #'(lambda (i) i) str-lis "")))

;;; Time-functions 
(defun* tv-time-date-in-n-days (days &key (separator "-") french)
  "Return the date in string form in n +/-DAYS."
  (let* ((days-in-sec       (* 3600 (* (+ days) 24)))
         (interval-days-sec (if (< days 0)
                                (+ (float-time (current-time)) days-in-sec)
                                (- (float-time (current-time)) days-in-sec)))
         (sec-to-time       (seconds-to-time interval-days-sec))
         (time-dec          (decode-time sec-to-time))
         (year              (int-to-string (nth 5 time-dec)))
         (month             (if (= (% (nth 4 time-dec) 10) 0)
                                (int-to-string (nth 4 time-dec))
                                (substring (int-to-string (/ (float (nth 4 time-dec)) 100)) 2)))
         (day-str           (if (= (% (nth 3 time-dec) 10) 0)
                                (int-to-string (nth 3 time-dec))
                                (substring (int-to-string (/ (float (nth 3 time-dec)) 100)) 2)))
         (day               (if (< (length day-str) 2) (concat day-str "0") day-str))
         (result            (list year month day)))
    (if french
        (mapconcat 'identity (reverse result) separator)
        (mapconcat 'identity result separator))))


(defun* tv-date-string (&key (separator "-") french (date (current-time)))
  "Return DATE under string form."
  (let* ((year      (nth 5 (decode-time date)))
         (month     (nth 4 (decode-time date)))
         (month-str (substring (int-to-string (/ (float month) 100)) 2))
         (day       (nth 3 (decode-time (current-time))))
         (day-str   (substring (int-to-string (/ (float day) 100)) 2))
         (result    (list (int-to-string year)
                          (if (< (length month-str) 2) (concat month-str "0") month-str)
                          (if (< (length day-str) 2) (concat day-str "0") day-str))))
    (if french
        (mapconcat 'identity (reverse result) separator)
        (mapconcat 'identity result separator))))

(defun* tv-cur-date-string (&key (separator "-") french)
  "Return current date under string form."
  (if french
      (tv-date-string :separator separator :french t)
      (tv-date-string :separator separator)))

;; mapc-with-progress-reporter 
(defmacro mapc-with-progress-reporter (message func seq)
  `(let* ((max               (length ,seq))
          (progress-reporter (make-progress-reporter (message ,message) 0 max))
          (count             0))
     (mapc #'(lambda (x)
               (progress-reporter-update progress-reporter count)
               (funcall ,func x)
               (incf count))
           ,seq)
     (progress-reporter-done progress-reporter)))

;; mapcar-with-progress-reporter 
(defmacro mapcar-with-progress-reporter (message func seq)
  `(let* ((max               (length ,seq))
          (progress-reporter (make-progress-reporter (message ,message) 0 max))
          (count             0)
          new-seq)
     (setq new-seq (mapcar #'(lambda (x)
                               (progress-reporter-update progress-reporter count)
                               (incf count)
                               (funcall ,func x))
                           ,seq))
     (progress-reporter-done progress-reporter)
     new-seq))

;; Send current buffer htmlized to uzbl. 
(defun tv-htmlize-buffer-to-uzbl ()
  (interactive)
  (let* ((fname           (concat "/tmp/" (symbol-name (gensym "emacs2uzbl"))))
         (html-fname      (concat fname ".html"))
         (buffer-contents (buffer-substring (point-min) (point-max))))
    (with-current-buffer (find-file-noselect fname)
      (insert buffer-contents)
      (save-buffer)
      (kill-buffer))
    (htmlize-file fname html-fname)
    (browse-url-uzbl (format "file://%s" html-fname))))

;; key-for-calendar 
(defvar tv-calendar-alive nil)
(defun tv-toggle-calendar ()
  (interactive)
  (if tv-calendar-alive
      (when (get-buffer "*Calendar*")
        (with-current-buffer "diary" (save-buffer)) 
        (calendar-exit)) ; advice reset win conf
      ;; In case calendar were called without toggle command
      (unless (get-buffer-window "*Calendar*")
        (setq tv-calendar-alive (current-window-configuration))
        (calendar))))

(defadvice calendar-exit (after reset-win-conf activate)
  (when tv-calendar-alive
    (set-window-configuration tv-calendar-alive)
    (setq tv-calendar-alive nil)))

;; Cvs-update-current-directory-and-compile-it 
;; <2009-04-17 Ven. 16:15>
(require 'pcvs)
(defun update-cvs-dir-and-compile ()
  "Cvs update current dir and compile it."
  (interactive)
  (let ((dir default-directory))
    (cvs-update dir nil)
    (while (not (equal cvs-mode-line-process "exit"))
      (sit-for 1))
    (message "Wait compiling %s..." dir)
    (shell-command "make")))


;; get-pid-from-process-name 
(defun tv-get-pid-from-process-name (process-name)
  (let ((process-list (list-system-processes)))
    (catch 'break
      (dolist (i process-list)
        (let ((process-attr (process-attributes i)))
          (when process-attr
            (when (string-match process-name
                                (cdr (assq 'comm
                                           process-attr)))
              (throw 'break
                i))))))))

;; copy-files-async-with-slime 

(setq slime-enable-evaluate-in-emacs t)
(defvar tv-slime-copy-files-list nil)
(defvar tv-slime-copy-dest-dir nil)
(defun tv-slime-dired-copy-files-or-dir-async (&optional file-list dir)
  "Copy a list of marked files-or-dirs async to a given directory using slime.
give FILE-LIST as a list of files.
DIR is a regular directory name.
`slime-enable-evaluate-in-emacs' have to be non--nil."
  (interactive)
  (slime-check-connected)
  (cond (file-list ; Non interactive call
         (setq tv-slime-copy-files-list file-list))
        ((eq major-mode 'dired-mode)
         (setq tv-slime-copy-files-list (mapcar #'(lambda (x)
                                                    (if (file-directory-p x)
                                                        (file-name-as-directory x)
                                                        x))
                                                (dired-get-marked-files)))))
  (if dir ; Non interactive call
      (setq tv-slime-copy-dest-dir dir)
      (setq tv-slime-copy-dest-dir
            (expand-file-name
             (read-directory-name (format "Copy %s files to directory: " (length tv-slime-copy-files-list))
                                  nil nil nil
                                  (when dired-dwim-target
                                    (dired-dwim-target-directory))))))
  (slime-eval-async '(cl:loop
                      with l = (swank::eval-in-emacs 'tv-slime-copy-files-list)
                      with d = (swank::eval-in-emacs 'tv-slime-copy-dest-dir) 
                      for i in l
                      do
                      (tv-fad-extensions:copy-file-or-dir i d)) 
                    (lambda (result)
                      ;(message "%S" result)
                      (message "%s files copied to %s"
                               (length tv-slime-copy-files-list)
                               tv-slime-copy-dest-dir))))

;; Delete-files-async-with-slime 

(defvar tv-slime-delete-files-list nil)
(defun tv-slime-dired-delete-files-async (&optional file-list)
  (interactive)
  (slime-check-connected)
  (cond (file-list
         (setq tv-slime-delete-files-list file-list))
        ((eq major-mode 'dired-mode)
         (setq tv-slime-delete-files-list (dired-get-marked-files)))
        (t
         (setq tv-slime-delete-files-list (read-file-name "File: "))))
  (if (y-or-n-p (format "Really delete %s files?" (length tv-slime-delete-files-list))) 
      (slime-eval-async '(cl:loop
                          with l = (swank::eval-in-emacs 'tv-slime-delete-files-list)
                          for i in l
                          do
                          (cl:delete-file i))
                        (lambda (result)
                          (message "%s files deleted" (length tv-slime-delete-files-list))))))

;; Mime-types 
(defun tv-dired-mime-type ()
  (interactive)
  (let ((fname (dired-filename-at-point)))
    (message "%s" (file-mime-type fname))))

;; Underline 
(defun tv-underline (beg end &optional underline-str)
  (interactive "r")
  (let ((str        (buffer-substring beg end))
        (ustr       (cond (underline-str)
                          (current-prefix-arg
                           (read-string "String: "))
                          (t
                           "=")))
        (len-str    (- end beg))
        (len-bol-pt (- beg (point-at-bol))))
    (forward-line 1)
    (insert (make-string len-bol-pt ? ))
    (insert (concat (*string ustr len-str) "\n"))))

;; Insert-pairs 
;; Yes i hate paredit.
;; (find-fline "/usr/share/emacs/23.1.50/lisp/emacs-lisp/lisp.el" "defun insert-pair")
(setq parens-require-spaces t)

(defun tv-insert-double-quote (&optional arg)
  (interactive "P")
  (insert-pair arg ?\" ?\"))


(defun tv-insert-double-backquote (&optional arg)
  (interactive "P")
  (insert-pair arg ?\` ?\'))


(defun tv-insert-vector (&optional arg)
  (interactive "P")
  (insert-pair arg ?\[ ?\]))


(defun tv-move-pair-forward ()
  (interactive)
  (let (action)
    (catch 'break
      (while t
        (setq action (read-key "`(': Insert, (any key to exit)."))
        (case action
          ('?\(
           (skip-chars-forward " ")
           (insert "(")
           (forward-sexp 1)
           (insert ")"))
          (t
           (throw 'break nil)))))))


(defun tv-insert-double-quote-and-close-forward ()
  (interactive)
  (let (action
        (prompt (and (not (minibufferp))
                     "\": Insert, (any key to exit).")))
    (unless prompt (message "\": Insert, (any key to exit)."))
    (catch 'break
      (while t
        (setq action (read-key prompt))
        (case action
          ('?\"
           (skip-chars-forward " \n")
           (insert "\"")
           (forward-sexp 1)
           (insert "\""))
          (t
           (throw 'break (when (characterp action) (insert (string action))))))))))


(defun tv-insert-pair-and-close-forward ()
  (interactive)
  (let (action)
    (insert "(")
    (catch 'break
      (while t
        (setq action (read-key "`)': Insert, (any key to exit)."))
        (case action
          ('?\)
           (unless (looking-back "(")
             (delete-char -1))
           (skip-chars-forward " ")
           (forward-symbol 1)
           (insert ")"))
          (t
           (forward-char -1)
           (throw 'break nil)))))))


;; Copy-boxquote 
(defun boxquote-copy-box-without-box (beg end)
  (interactive "r")
  (let (new-beg
        new-end
        next-end
        title)
    (deactivate-mark)
    (save-excursion
      (goto-char beg)
      (setq title (boxquote-get-title)))
    (boxquote-unbox-region beg end)
    (setq new-end (point))
    (goto-char beg)
    (while (not (looking-at ".*[^ \n]"))
      (forward-char 1))
    (setq new-beg (point))
    (goto-char new-end)
    (while (not (looking-back ".*[^ \n]"))
      (forward-char -1))
    (setq next-end (point))
    (copy-region-as-kill new-beg next-end)
    (boxquote-region beg new-end)
    (when title
      (boxquote-title title))))

;; Binded to <f7> q c
;; (find-fline "~/.emacs.d/emacs-config-laptop/.emacs.el" "require 'boxquote")


;; Goto-precedent-level-of-tree-in-dired 
(defun tv-dired-find-alternate-updir ()
  (interactive)
  (when (eq major-mode 'dired-mode)
    (goto-char (point-min))
    (when (re-search-forward ".*[.]\\{2\\}$" nil t)
      (dired-find-alternate-file))))
          
(define-key dired-mode-map (kbd "C-c .") 'tv-dired-find-alternate-updir)


;; Open-file-in-gimp 
;; <2009-08-13 Jeu. 10:29>
(defun gimp-open-file (file)
  (interactive
   (list (anything-comp-read "Image: "
                             (loop
                                with f = (cddr (directory-files default-directory))
                                with img = '("jpg" "png" "gif" "jpeg")
                                for i in f
                                if (member (file-name-extension i) img)
                                collect i))))
  (message "Starting Gimp...") (sit-for 0.2)
  (start-process "Gimp" nil "gimp" (expand-file-name file))
  (set-process-sentinel (get-process "Gimp")
                        #'(lambda (process event)
                            (message
                             "%s process is %s"
                             process
                             event))))


;; Insert-an-image-at-point 
(defun tv-insert-image-at-point (image)
  (interactive "fImage: ")
  (let ((img (create-image image)))
    (insert-image img)))

(defun tv-show-img-from-fname-at-point ()
  (interactive)
  (let ((img (thing-at-point 'sexp)))
    (forward-line)
    (tv-insert-image-at-point img)))

;; Show-message-buffer-a-few-seconds 
(autoload 'View-scroll-to-buffer-end "view")
(defun tv-tail-echo-area-messages ()
  (interactive)
  (save-window-excursion
    (delete-other-windows)
    (pop-to-buffer (get-buffer-create "*Messages*") t)
    (View-scroll-to-buffer-end)
    (sit-for 10)))

;; Align-for-sections-in-loop 
(defun align-loop-region-for (beg end)
  (interactive "r")
  (align-regexp beg end "\\(\\s-*\\) = " 1 1 nil)
  (indent-region beg end))

(define-key lisp-interaction-mode-map (kbd "C-M-&") 'align-loop-region-for)
(define-key lisp-mode-map (kbd "C-M-&") 'align-loop-region-for)
(define-key emacs-lisp-mode-map (kbd "C-M-&") 'align-loop-region-for)

;;;;;;;;;;;;;;;;;;;;;;;
;;; Persistent-objects
;;
;; Main function to save objects.
(defun dump-object-to-file (obj file)
  "Save symbol object OBJ to the byte compiled version of FILE.
OBJ can be any lisp object, list, hash-table, etc...
FILE is an elisp file with ext *.el.(Don't give a .elc as arg!!!)
Loading the *.elc file will restitute object.
That may not work with Emacs versions <=23.1 (use vcs versions)."
  (require 'cl) ; Be sure we use the CL version of `eval-when-compile'.
  (if (file-exists-p file)
      (error "dump-object-to-file: File `%s' already exists, please remove it." file)
      (with-temp-file file
        (erase-buffer)
        (let* ((str-obj (symbol-name obj))
               (fmt-obj (format "(setq %s (eval-when-compile %s))" str-obj str-obj)))
          (insert fmt-obj)))
      (byte-compile-file file) (delete-file file)
      (message "`%s' dumped to %sc" obj file)))

(defvar elisp-objects-default-directory "~/.emacs.d/elisp-objects/")
(defvar object-to-save-alist '((ioccur-history . "ioccur-history.el")
                               (extended-command-history . "extended-command-history.el")
                               (anything-external-command-history . "anything-external-command-history.el")
                               (anything-surfraw-engines-history . "anything-surfraw-engines-history.el")
                               (tv-save-buffers-alist . "tv-save-buffers-alist.el")
                               (anything-ff-history . "anything-ff-history.el")
                               (anything-c-grep-history . "anything-c-grep-history.el")
                               ))

(defun dump-object-to-file-save-alist ()
  (when object-to-save-alist
    (loop for (o . f) in object-to-save-alist
       for abs = (expand-file-name f elisp-objects-default-directory)
       do (progn
            (dump-object-to-file o abs)))))

(defun* restore-objects-from-directory
    (&optional (dir elisp-objects-default-directory))
  (let ((file-list (cddr (directory-files dir t))))
    (mapc 'load file-list)))

;; Persistents-buffer 
;; Get rid of desktop.el, too slow.

(defun tv-save-some-buffers ()
  (loop
     with dired-blist = (loop for (f . b) in dired-buffers
                           when (buffer-name b)
                           collect b)
     with blist = (append (buffer-list) dired-blist)
     for b in blist
     for buf-fname = (or (buffer-file-name b) (car (rassoc b dired-buffers)))
     for place = (with-current-buffer b (point))
     when (and buf-fname
               (not (string-match tramp-file-name-regexp buf-fname))
               (file-exists-p buf-fname))
     collect (cons buf-fname place)))

(defvar tv-save-buffers-alist nil)
(defun tv-dump-some-buffers-to-list ()
  (setq tv-save-buffers-alist (tv-save-some-buffers)))

(defun tv-restore-some-buffers ()
  (let* ((max (length tv-save-buffers-alist))
         (progress-reporter (make-progress-reporter "Restoring buffers..." 0 max)))
    (loop for (f . p) in tv-save-buffers-alist
       for count from 0
       do
       (with-current-buffer (find-file-noselect f 'nowarn)
         (goto-char p)
         (progress-reporter-update progress-reporter count)))
    (progress-reporter-done progress-reporter)))

;; (add-hook 'kill-emacs-hook 'dump-object-to-file-save-alist)
;; (add-hook 'emacs-startup-hook 'restore-objects-from-directory)
;; (add-hook 'kill-emacs-hook 'tv-dump-some-buffers-to-list)
;; (add-hook 'emacs-startup-hook 'tv-restore-some-buffers 'append)

(defun* tv-set-emacs-session-backup (&key enable)
  (if enable
      (unless (or (memq 'dump-object-to-file-save-alist kill-emacs-hook)
                  (memq 'tv-dump-some-buffers-to-list kill-emacs-hook)
                  (memq 'restore-objects-from-directory emacs-startup-hook)
                  (memq 'tv-restore-some-buffers emacs-startup-hook))
        (add-hook 'kill-emacs-hook 'dump-object-to-file-save-alist)
        (add-hook 'emacs-startup-hook 'restore-objects-from-directory)
        (add-hook 'kill-emacs-hook 'tv-dump-some-buffers-to-list)
        (add-hook 'emacs-startup-hook 'tv-restore-some-buffers 'append))
      (when (or (memq 'dump-object-to-file-save-alist kill-emacs-hook)
                (memq 'tv-dump-some-buffers-to-list kill-emacs-hook)
                (memq 'restore-objects-from-directory emacs-startup-hook)
                (memq 'tv-restore-some-buffers emacs-startup-hook))
        (remove-hook 'kill-emacs-hook 'dump-object-to-file-save-alist)
        (remove-hook 'emacs-startup-hook 'restore-objects-from-directory)
        (remove-hook 'kill-emacs-hook 'tv-dump-some-buffers-to-list)
        (remove-hook 'emacs-startup-hook 'tv-restore-some-buffers))))

;; Kill-backward 
(defun tv-kill-backward ()
  (interactive)
  (let ((end (point)) beg)
    (forward-line 0)
    (while (get-text-property (point) 'read-only)
      (forward-char 1))
    (setq beg (point)) (kill-region beg end))
  (when (eq (point-at-bol) (point-at-eol))
    (delete-blank-lines) (skip-chars-forward " ")))

;; Delete-char-or-region 
(defun tv-delete-char (arg)
  (interactive "p")
  (if (anything-region-active-p)
      (delete-region (region-beginning) (region-end))
      (delete-char arg)))

;; Browse-url 
(defun firefox-browse-url (url)
  (interactive "sURL: ")
  (anything-c-generic-browser url "firefox"))

(defun tv-w3m-view-this-page-in-firefox ()
  (interactive)
  (let ((url (or (w3m-print-this-url)
                 (w3m-print-current-url))))
    (firefox-browse-url url)))

(defun w3m-view-this-page-in-uzbl ()
  (interactive)
  (let ((url (or (w3m-print-this-url)
                 (w3m-print-current-url))))
    (browse-url-uzbl url)))

(defun w3m-view-this-page-in-chrome ()
  (interactive)
  (let ((url (or (w3m-print-this-url)
                 (w3m-print-current-url))))
    (browse-url-chromium url)))

;; Easypg 
(defun epa-sign-to-armored ()
  "Create a .asc file."
  (interactive)
  (let ((epa-armor t))
    (call-interactively 'epa-sign-file)))

;; Same as above but usable as alias in eshell
(defun gpg-sign-to-armored (file)
  "Create a .asc file."
  (let ((epa-armor t))
    (epa-sign-file file nil nil)))

;; Usable from eshell as alias
(defun gpg-sign-to-sig (file)
  "Create a .sig file."
  (epa-sign-file file nil 'detached))

;; Insert-log-from-patch 
(defun tv-insert-log-from-patch (patch)
  (interactive (list (anything-c-read-file-name
                      "Patch: ")))
  (let (beg end data)
    (with-current-buffer (find-file-noselect patch)
      (goto-char (point-min))
      (while (re-search-forward "^#" nil t) (forward-line 1))
      (setq beg (point))
      (when (re-search-forward "^diff" nil t)
        (forward-line 0) (skip-chars-backward "\\s*|\n*")
        (setq end (point)))
      (setq data (buffer-substring beg end))
      (kill-buffer))
    (insert data)))

;; Show infos on files using an easy interface for `file-attributes'.
;; [DEPRECATED] Use `anything-ff-attributes'
;;
(defun* show-file-attributes
    (file &key type links uid gid access-time modif-time status size mode gid-change inode device-num dired)
  "Comprehensive reading of `file-attributes'."
  (let ((all (destructuring-bind
                   (type links uid gid access-time modif-time status size mode gid-change inode device-num)
                 (file-attributes file 'string)
               (list :type        type
                     :links       links
                     :uid         uid
                     :gid         gid
                     :access-time access-time
                     :modif-time  modif-time
                     :status      status
                     :size        size
                     :mode        mode
                     :gid-change  gid-change
                     :inode       inode
                     :device-num  device-num))))
    (cond (type
           (let ((result (getf all :type)))
             (cond ((stringp result)
                    "symlink")
                   (result "directory")
                   (t "file"))))
          (links (getf all :links))
          (uid   (getf all :uid))
          (gid   (getf all :gid))
          (access-time
           (format-time-string "%Y-%m-%d %R" (getf all :access-time)))
          (modif-time
           (format-time-string "%Y-%m-%d %R" (getf all :modif-time)))
          (status
           (format-time-string "%Y-%m-%d %R" (getf all :status)))
          (size (getf all :size))
          (mode (getf all :mode))
          (gid-change (getf all :gid-change))
          (inode (getf all :inode))
          (device-num (getf all :device-num))
          (dired
           (concat
            (getf all :mode) " "
            (number-to-string (getf all :links)) " "
            (getf all :uid) ":"
            (getf all :gid) " "
            (number-to-string (getf all :size)) " "
            (format-time-string "%Y-%m-%d %R" (getf all :modif-time))))
          (t all))))


(defun* serial-rename-with1 (dir &key ext suffix prefix without)
  (let* ((ls-dir     (file-expand-wildcards (if ext
                                                (format "%s*.%s" (file-name-as-directory dir) ext)
                                                (format "%s*" (file-name-as-directory dir)))
                                            t)))
    (loop for i in ls-dir
         for no-ext = (file-name-sans-extension (file-name-nondirectory i))
         for new-name = (if (and without (string-match without no-ext))
                            (replace-match "" t t no-ext)
                            no-ext)
         for suffixed = (and suffix (expand-file-name (concat new-name suffix "." ext) dir))
         for prefixed = (and prefix (expand-file-name (concat prefix new-name "." ext) dir))
         for both = (and prefix suffix (expand-file-name (concat prefix new-name suffix "." ext) dir))
         for replace = (expand-file-name (concat new-name "." ext) dir)
         do (rename-file i (or both suffixed prefixed replace)))))


(defun* rename-file-with1 (file &key suffix prefix without)
  (let* ((dir (file-name-directory file))
         (ext (file-name-extension file))
         (no-ext (file-name-sans-extension (file-name-nondirectory file)))
         (new-name (if (and without (string-match without no-ext))
                       (replace-match "" t t no-ext)
                       no-ext))
         (suffixed (and suffix (expand-file-name (concat new-name suffix "." ext) dir)))
         (prefixed (and prefix (expand-file-name (concat prefix new-name "." ext) dir)))
         (both (and prefix suffix (expand-file-name (concat prefix new-name suffix "." ext) dir)))
         (replace (expand-file-name (concat new-name "." ext) dir)))
     (rename-file file (or both suffixed prefixed replace))))


;; eshell-pager 
(require 'iterator)
(defun eshell-pager (command &rest args)
  "Display the output of COMMAND by chunk of lines."
  (let* ((height   (/ (frame-height) 2)) ; Assume we use 1 or 2 windows.
         (split    (with-temp-buffer
                     (apply #'call-process command nil t nil args)
                     (goto-char (point-min))
                     (loop
                        while (not (eobp))
                        for beg = (point)
                        do (forward-line (- height 3))
                        collect (buffer-substring beg (point)))))
         (it       (iter-list split)) ; Initialize with a simple iterator.
         (last-elm (iter-next it)))
    (flet ((print-result ()
             (pop-to-buffer (get-buffer-create "*Pager*"))
             (erase-buffer)
             (save-excursion
               (when last-elm
                 (insert last-elm)))))
      (save-window-excursion
        (print-result) ; Print the first chunk of lines before starting loop.
        (while (let ((char (read-key "===[ Next: SPACE, Prec: b, AnyKey:Exit ]===")))
                 (case char
                   (32 ; SPACE: Continue with a circular iterator.
                    (setq it (iter-sub-next-circular split last-elm))
                    (setq last-elm (iter-next it)))
                   (98 ; b Go back.
                    (setq it (iter-sub-prec-circular split last-elm))
                    (setq last-elm (iter-next it)))
                   (t nil))) ; Exit loop if any other key is pressed.
          (print-result))))))

;; gmail-notify 
;; Timer is started in .emacs:
;; (find-fline "~/.emacs.d/emacs-config-laptop/.emacs.el" "(gmail-notify-start")
(defun* tv-get-gmail (&key mail password)
  (let* ((gmail
          (auth-source-user-or-password
           '("login" "password") "smtp.gmail.com" "587"))
         (name (car gmail))
         (pass (cadr gmail)))
    (cond (mail name)
          (password pass)
          (t gmail))))

(defun gmail-notify-curl ()
  (let* ((login (tv-get-gmail :mail t))
         (pass  (tv-get-gmail :password t))
         proc)
    (apply #'start-process
           "gmailnotify" nil "curl"
           (list "-u"
                 (concat login ":" pass)
                 "https://mail.google.com/mail/feed/atom"))
    (setq proc (get-process "gmailnotify"))
    (when proc
      (set-process-filter proc
                          #'(lambda (process output)
                              (let* ((all   (with-temp-buffer
                                              (insert output)
                                              (car (xml-parse-region (point-min) (point-max)))))
                                     (title (caddar (xml-get-children all 'title)))
                                     (tag   (caddar (xml-get-children all 'tagline)))
                                     (count (caddar (xml-get-children all 'fullcount)))
                                     (date  (caddar (xml-get-children all 'modified))))
                                (when (and (> (length all) 0)
                                           (or (not (stringp count))
                                               (> (string-to-number count) 0)))
                                  (tooltip-show
                                   (format "%s\nLast modified: %s\n%s: [%s]" title date tag count)))))))))

(defun gmail-notify-check ()
  (interactive)
  (gmail-notify-curl))

(defvar gmail-notification-timer nil)
(defun gmail-notify-start ()
  (interactive)
  (setq gmail-notification-timer (run-with-timer 1 60 'gmail-notify-curl)))

(defun gmail-notify-stop ()
  (interactive)
  (cancel-timer gmail-notification-timer)
  (setq gmail-notification-timer nil))

;; List recursively contents of directory
(defun* walk-directory (directory &key (path 'basename) (directories t) match)
  "Walk through DIRECTORY tree.
PATH can be one of basename, relative, or full.
DIRECTORIES when non--nil (default) return also directories names, otherwise
skip directories names.
MATCH when non--nil mention only file names that match the regexp MATCH."
  (let (result
        (fn (case path
              (basename 'file-name-nondirectory)
              (relative 'file-relative-name)
              (full     'identity)
              (t (error "Error: Invalid path spec `%s', must be one of basename, relative or full." path)))))
    (labels ((ls-R (dir)
               (loop with ls = (directory-files dir t directory-files-no-dot-files-regexp)
                  for f in ls
                  if (file-directory-p f)
                  do (progn (when directories
                              (push (funcall fn f) result))
                            ;; Don't recurse in directory symlink.
                            (unless (file-symlink-p f)
                              (ls-R f)))
                  else do 
                    (unless (and match (not (string-match match (file-name-nondirectory f))))
                      (push (funcall fn f) result)))))
      (ls-R directory)
      (nreverse result))))


;; Switch indenting lisp style.
(defun toggle-lisp-indent ()
  (interactive)
  (if (eq lisp-indent-function 'common-lisp-indent-function)
      (progn
        (setq lisp-indent-function 'lisp-indent-function)
        (message "Switching to Emacs lisp indenting style."))
      (setq lisp-indent-function 'common-lisp-indent-function)
      (message "Switching to Common lisp indenting style.")))

;; C-mode conf
(defun tv-cc-this-file ()
  (interactive)
  (when (eq major-mode 'c-mode)
    (let* ((iname (buffer-file-name (current-buffer)))
           (oname (file-name-sans-extension iname)))
      (compile (format "make -k %s" oname)))))
(add-hook 'c-mode-hook #'(lambda ()
                           (define-key c-mode-map (kbd "C-c C-c") 'tv-cc-this-file)))

;; Insert line numbers in region
(defun tv-insert-lineno-in-region (beg end)
  (interactive "r")
  (save-restriction
    (narrow-to-region beg end)
    (goto-char (point-min))
    (loop while (re-search-forward "^.*$" nil t)
       for count from 1 do
         (replace-match
          (concat (format "%d " count) (match-string 0))))))

;; switch to emacs version
(defun eselect-emacs ()
  (interactive)
  (when (y-or-n-p (format "Really switch from %s to another emacs? " emacs-version))
    (loop for i in '("b2m" "ctags" "ebrowse" "emacs" "emacsclient" "etags" "grep-changelog" "rcs-checkin")
       do (delete-file (expand-file-name i "/sudo::/usr/local/bin/")))
    (delete-file "/sudo::/usr/local/share/info")
    (let* ((src-bin (expand-file-name (anything-comp-read
                                       "EmacsVersion: "
                                       (directory-files "/sudo::/usr/local/sbin"
                                                        nil directory-files-no-dot-files-regexp))
                                      "/sudo::/usr/local/sbin"))
           (bin-list (loop for i in '("b2m" "ctags"
                                      "ebrowse" "emacs"
                                      "emacsclient" "etags"
                                      "grep-changelog" "rcs-checkin")
                                       collect (expand-file-name
                                                i src-bin)))
           (src-info (anything-comp-read
                      "EmacsInfoVersion: "
                      (loop for i in
                           (directory-files "/sudo::/usr/local/share" t directory-files-no-dot-files-regexp)
                           when (string-match "info" i) collect i))))
      (anything-dired-action "/sudo::/usr/local/bin/"
                             :action 'symlink
                             :files bin-list)
      (anything-dired-action "/sudo::/usr/local/share/info"
                             :action 'symlink :files (list src-info))
      (message "Switched to %s version" (file-name-nondirectory src-bin)))))

;; Permutations

(defun* permutations (bag &key result-as-string print)
  "Return a list of all the permutations of the input."
  ;; If the input is nil, there is only one permutation:
  ;; nil itself
  (when (stringp bag) (setq bag (split-string bag "" t)))
  (let ((result
         (if (null bag)
             '(())
             ;; Otherwise, take an element, e, out of the bag.
             ;; Generate all permutations of the remaining elements,
             ;; And add e to the front of each of these.
             ;; Do this for all possible e to generate all permutations.
             (loop for e in bag append
                  (loop for p in (permutations (remove e bag))
                     collect (cons e p))))))
    (when (or result-as-string print)
        (setq result (loop for i in result collect (mapconcat 'identity i ""))))
    (if print
        (with-current-buffer (get-buffer-create "*permutations*")
          (erase-buffer)
          (loop for i in result
             do (insert (concat i "\n")))
          (pop-to-buffer (current-buffer)))
        result)))

;; Verlan.
(defun tv-reverse-lines-in-region (beg end)
  (interactive "r")
  "Verlan region."
  (save-restriction
    (narrow-to-region beg end)
    (goto-char (point-min))
    (while (not (eobp))
      (let* ((bl (point-at-bol))
             (el (point-at-eol))
             (cur-line (buffer-substring bl el))
             (split (loop for i across cur-line collect i)))
        (delete-region bl el)
        (loop for i in (reverse split) do (insert i)))
      (forward-line 1))))

;; Interface to df command-line.
;; See:
;; [EVAL] (find-fline "~/.emacs.d/emacs-config-laptop/dired-extension.el" "defun\* tv-get-disk-info")
(defun dfh (directory)
  "Interface to df -h command line.
If a prefix arg is given choose directory, otherwise use `default-directory'."
  (interactive (list (if current-prefix-arg
                         (anything-c-read-file-name
                          "Directory: " :test 'file-directory-p)
                         default-directory)))
  (let ((df-info (tv-get-disk-info directory t)))
    (pop-to-buffer (get-buffer-create "*df info*"))
    (erase-buffer)
    (insert (format "*Volume Info for `%s'*\n\nDevice: %s\nMaxSize: \
%s\nUsed: %s\nAvailable: %s\nCapacity in use: %s\nMount point: %s"
                    directory
                    (getf df-info :device)
                    (getf df-info :blocks)
                    (getf df-info :used)
                    (getf df-info :available)
                    (getf df-info :capacity)
                    (getf df-info :mount-point)))
    (view-mode-enable)))

(defun tv-toggle-resplit-window ()
  (interactive)
  (when (> (count-windows) 1)
    (let ((buf (current-buffer))
          before-height) 
      (with-current-buffer buf
        (setq before-height (window-height))
        (delete-window)
        (set-window-buffer
         (select-window (if (= (window-height) before-height)
                            (split-window-vertically)
                            (split-window-horizontally)))
         buf)))))

;; Euro million
(defun euro-million ()
  (interactive)
  (flet ((star-num (limit)
           ;; Get a random number between 1 to 12.
           (let ((n 0))
             (while (= n 0) (setq n (random limit)))
             n))
         (get-stars ()
           ;; Return a list of 2 differents numbers from 1 to 12.
           (let* ((str1 (number-to-string (star-num 12)))
                  (str2 (let ((n (number-to-string (star-num 12))))
                          (while (string= n str1)
                            (setq n (number-to-string (star-num 12))))
                          n)))
             (list str1 str2)))           
         (result ()
           ;; Collect random numbers without  dups.
           (loop with L repeat 5
              for r = (star-num 51)
              if (not (member r L))
              collect r into L
              else
              collect (let ((n (star-num 51)))
                        (while (memq n L)
                          (setq n (star-num 51)))
                        n) into L
              finally return L)))
    (with-current-buffer (get-buffer-create "*Euro million*")
      (erase-buffer)
      (insert "Grille aléatoire pour l'Euro Million\n\n")
      (loop with ls = (loop repeat 5 collect (result))  
         for i in ls do
         (progn
           (insert (mapconcat #'(lambda (x)
                                  (let ((elm (number-to-string x)))
                                    (if (= (length elm) 1) (concat elm " ") elm)))
                              i " "))
           (insert " Stars: ")
           (insert (mapconcat 'identity (get-stars) " "))
           (insert "\n"))
         finally do (pop-to-buffer "*Euro million*")))))

;; Fast remove-duplicates
(defun* remove-dups (seq &key (test 'eq))
  (let ((cont (make-hash-table :test test)))
    (loop for elm in seq
       unless (gethash elm cont)
       do (puthash elm elm cont)
       finally return
         (loop for i being the hash-values in cont collect i))))

;; Just an example to use `url-retrieve'
(defun tv-download-file-async (url &optional noheaders to)
  (lexical-let ((noheaders noheaders) (to to))
    (url-retrieve url #'(lambda (status)
                          (if (plist-get status :error)
                              (signal (car status) (cadr status))
                              (switch-to-buffer (current-buffer))
                              (let ((inhibit-read-only t))
                                (goto-char (point-min))
                                ;; remove headers
                                (when noheaders
                                  (save-excursion
                                    (re-search-forward "^$")
                                    (forward-line 1)
                                    (delete-region (point-min) (point))))
                                (when to
                                  (write-file to)
                                  (kill-buffer (current-buffer)))))))))

;; Tool to take all sexps matching regexps in buffer and bring
;; them at point. Useful to reorder defvar, defcustoms etc...

(defun tv-group-sexp-matching-regexp-at-point (arg regexp)
  "Put all sexps matching REGEXP and put them at point.
The sexps are searched after point, unless ARG.
In this case, sexps are searched before point."
  (interactive "P\nsRegexp: ")
  (let ((pos (point))
        (fun (if arg 're-search-backward 're-search-forward))
        (sep (and (y-or-n-p "Separate sexp with newline? ") "\n")))
    (loop while (funcall fun regexp nil t)
      do (progn
           (beginning-of-defun)
           (let ((beg (point))
                 (end (save-excursion (end-of-defun) (point))))
             (save-excursion
               (forward-line -1)
               (when (search-forward "###autoload" (point-at-eol) t)
                 (setq beg (point-at-bol))))
             (kill-region beg end)
             (delete-blank-lines))
           (save-excursion
             (goto-char pos)
             (yank)
             (insert (concat "\n" sep))
             (setq pos (point))))
       finally do (goto-char pos))))

;; Check paren errors
(defun tv-check-paren-error ()
  (interactive)
  (let (pos-err)
    (save-excursion
      (goto-char (point-min))
      (catch 'error
        (condition-case err
            (forward-list 9999)
          (error
           (throw 'error
             (setq pos-err (caddr err)))))))
    (if pos-err
        (message "Paren error found in sexp starting at %s"
                 (goto-char pos-err))
        (message "No paren error found")))) 

;; Sha-sum
(defun sha-sum (file)
  (let ((algo-list '(md5 sha1 sha224 sha256 sha384 sha512)))
    (kill-new
     (secure-hash (intern
                   (anything-comp-read
                    "Algorithm: " algo-list))
                  file))))

;; Provide 
(provide 'tv-utils)

;;; tv-utils.el ends here
