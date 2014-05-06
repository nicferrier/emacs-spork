;;; spork.el --- spork - a fork/spoon combination for emacs -*- lexical-binding: t -*-

;; Copyright (C) 2014  Nic Ferrier

;; Author: Nic Ferrier <nferrier@ferrier.me.uk>
;; Keywords: processes
;; Version: 0.0.001
;; Package-requires: ((dash "2.5.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; 

;;; Code:

(require 'dash)

(defun spork-make-shallow-elpa-clone ()
  (let ((name (make-temp-name "/tmp/elpa-clone")))
    (make-directory name t)
    (--map
     (make-symbolic-link it (format "%s/%s" name (file-name-nondirectory it)))
     (directory-files package-user-dir t "^[^.].*[^~]$" ))
    name))

(defun spork-make-emacsd ()
  "Make an Emacs HOME that we can boot an Emacs on.

The HOME clones your local packages in a read only way."
  (let ((elpa-clone (spork-make-shallow-elpa-clone))
        (emacsd-temp (make-temp-name "/tmp/emacs-home")))
    (make-directory (concat emacsd-temp "/.emacs.d") t)
    (rename-file elpa-clone (format "%s/.emacs.d/elpa" emacsd-temp))
    emacsd-temp))

(defun spork/buffered-read (buffer data)
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-max))
      (insert data)
      (goto-char (point-min))
      (condition-case err
          (prog1 (list :result (read (current-buffer)))
            (delete-region (point-min) (point)))
        (end-of-file (list :none))
        (error (list :error err))))))

(defun spork/read-and-eval (buffer data)
  (pcase (spork/buffered-read buffer data)
    (`(:result . ,value) (condition-case err
                             (list :result (eval (car value) t))
                           (error (list :error err))))
    (`(:error . ,err) err)
    (`(:none))))

(defun spork/channel-repl (process data)
  (spork/read-and-eval (process-buffer process) data))

;;;###autoload
(defun spork/bootstrap ()
  (let ((env (getenv "CHANNEL")))
    (when env
      (let ((proc (make-network-process
                   :name (concat "*spork-channel-" (file-base-name env) "*")
                   :family 'local
                   :server nil
                   :service env)))
        (set-process-filter proc 'spork/channel-repl)))))

(defun make/spork-channel ()
  (let* ((socket-file (concat "/tmp/" (make-temp-name "spork-server")))
         (myproc (make-network-process
                  :name socket-file
                  :family 'local
                  :server t
                  :service socket-file)))
    myproc))

(defun make-spork ()
  (let ((emacsd (spork-make-emacsd))
        (spork-channel (make/spork-channel))
        (saved-HOME (getenv "HOME"))
        (saved-CHANNEL (getenv "CHANNEL")))
    (setenv "HOME" emacsd)
    (setenv "CHANNEL" spork-channel)
    (unwind-protect
         (start-process
          "*spork*"
          "*spork*"
          (file-truename (expand-file-name invocation-name invocation-directory))
          "-batch" "-e" "(while t (sleep-for 10))")
      (setenv "HOME" saved-HOME)
      (getenv "CHANNEL" saved-CHANNEL))))


;;;###autoload
(eval-after-load 'spork
  '(spork/bootstrap))

(provide 'spork)

;;; spork.el ends here
