

(require 'spork)

(ert-deftest spork/buffered-read ()
  (with-temp-buffer
    (list
     (equal '(:none) (spork/buffered-read (current-buffer) "(data"))
     (equal '(:result (data)) (spork/buffered-read (current-buffer) ")(more"))
     (equal '(:result (more)) (spork/buffered-read (current-buffer) ")")))))

(ert-deftest spork/read-and-eval ()
  (flet ((my-func () 10))
    (with-temp-buffer
      (list
       (equal nil (spork/read-and-eval (current-buffer) "(my-"))
       (equal '(:result 10) (spork/read-and-eval (current-buffer) "func)(more"))
       (equal '(:error (void-function more))
              (spork/read-and-eval (current-buffer) ")"))))))

(ert-deftest spork/channel-repl ()
  (fakir-mock-process :proc ()
    (flet ((my-func () 10))
      (list
       (equal nil (spork/channel-repl :proc "(my-"))
       (equal '(:result 10) (spork/channel-repl :proc "func)(more"))
       (equal '(:error (void-function more)) (spork/channel-repl :proc ")"))))))

;;; spork-tests.el ends here
