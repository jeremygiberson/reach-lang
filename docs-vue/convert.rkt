#lang racket/base
(require racket/runtime-path
         racket/path
         racket/file
         racket/pretty
         racket/match
         lang-file/read-lang-file)

(define-runtime-path scrbl "../docs-src")

(define d display)

(define (code c [lang #f])
  ;; XXX lang
  (d "`")
  (for-each d c)
  (d "`"))

(define (code-block l [lang #f])
  (d "```")
  (when lang (d lang))
  (d "\n")
  (for-each d l)
  (d "\n```\n"))

(define (header lvl opts)
  (define hash-lvl (make-string lvl #\#))
  (define tag "")
  (define name '())
  (let loop ([o opts])
    (match o
      [`(#:version ,_ ,@o)
        (loop o)]
      [`(#:style ,_ ,@o)
        (loop o)]
      [`(#:tag ,t ,@o)
        (set! tag (format "{#~a} " t))
        (loop o)]
      [(cons (? list?) _)
       (set! name o)]
      [(cons (? string?) _)
       (set! name o)]))
  (d (format "~a ~a" hash-lvl tag))
  (egol name))

(define ego
  (match-lambda
    [(? string? s) (d s)]
    [`(tech ,t) (ego t)]
    [`(link ,t ,l)
      (d (format "[~a](~a)" l t))]
    [`(reachexlink ,f #:dir ,e)
      (d (format "[~a](${repo}}/~a/~a)" f e f))]
    [`(reachexlink ,f)
      (d (format "[~a](${repo}}/examples/~a)" f f))]
    [`(reachexlink ,f ,c #:dir ,e)
      (d "[")
      (ego c)
      (d (format "](${repo}}/~a/~a)" e f))]
    [`(reachexlink ,f ,c)
      (d "[")
      (ego c)
      (d (format "](${repo}}/examples/~a)" f))]
    [`(title ,@o) (header 1 o)]
    [`(section ,@o) (header 2 o)]
    [`(subsection ,@o) (header 3 o)]
    [`(subsubsection ,@o) (header 4 o)]
    [`(secref ,t)
      (d (format "${seclink(~s)}" t))]
    [`(seclink ,t ,l)
      (d (format "[~a](##~a)" l t))]
    [`(reachin ,@c) (code c 'reach)]
    [`(jsin ,@c) (code c 'js)]
    [`(pyin ,@c) (code c 'py)]
    [`(goin ,@c) (code c 'go)]
    [`(author (author+email ,a ,e)) (void)]
    [`DApp (d "DApp")]
    [`DApps (d "DApps")]
    [`(hrule) (d "---")]
    [`RPS (d "_Rock, Paper, Scissors!_")]
    [`(emph . ,c) (d "_") (egol c) (d "_")]
    [`(italic . ,c) (d "_") (egol c) (d "_")]
    [`(bold . ,c) (d "**") (egol c) (d "**")]
    [`(tt ,@c) (code c)]
    [`(exec ,@c) (code c)]
    [`(envref ,@c) (code c)]
    [`(defconmode ,@c) (code c)]
    [`(conmode ,@c) (code c)]
    [`(defenv ,@c) (code c)]
    [`(envvar ,@c) (code c)]
    [`(nonterm ,@c) (code c)]
    [`(cmd ,@c)
      (d "```\n$ ") (egol c) (d "\n```\n")]
    [`(Flag ,@c) (code (cons "-" c))]
    [`(DFlag ,@c) (code (cons "--" c))]
    [`(filepath ,@c) (code c)]
    [`(litchar ,@c) (code c)]
    [`(the-community-link)
      (ego '(link "${discord}" "the Discord community"))]
    [`(local-table-of-contents . ,_) (d "${toc}")]
    [`(table-of-contents . ,_) (d "${toc}")]
    [`(element (make-style #f (list (url-anchor ,a))) '())
      (d (format "<a name=~s></a>" a))]
    [`(require . ,_) (void)]
    [`(mint-scope ,ms)
      (set-box! mint-scope ms)
      (void)]
    [`(define . ,_) (void)]
    [`(deftech ,c)
      (d (format "${defn(~s)}" c))]
    [`(error ,x) (ego `(section #:tag ,x ,x))]
    [`(mint-define! ,@ts)
      (define s (unbox mint-scope))
      (cond
        [(not s)
         (set-box! BAD #t)
         (eprintf "XXX no mint-scope at ~v\n" ts)]
        [else
          (for ([ts (in-list ts)])
            (match-define `'(,@tsl) ts)
            (define t (apply string-append tsl))
            (d (format "${ref(~s, ~s)}" s t)))])]
    [`(include-section . ,_) (void)]
    [`(index-section . ,_) (void)]
    [`(index . ,_) (void)]
    [`(reach . ,l) (code-block l 'reach)]
    [`(go . ,l) (code-block l 'go)]
    [`(js . ,l) (code-block l 'js)]
    [`(py . ,l) (code-block l 'py)]
    [`(verbatim . ,l) (code-block l #f)]
    [`(,(or 'itemize 'itemlist) #:style 'ordered ,@l)
      (for ([i (in-naturals 1)]
            [ei (in-list l)])
        (d i) (d ". ")
        (ego ei))]
    [`(,(or 'itemize 'itemlist) ,@l)
      (for ([ei (in-list l)])
        (d "+ ") (ego ei))]
    [`(item ,@l)
      (egol l) (d "\n")]
    [`(margin-note . ,l)
      (d "::: note\n")
      (egol l)
      (d "\n:::")]
    [(or
       `(reachex ,f 'only ,from ,to ,_)
       `(reachex #:mode ,_ ,f 'only ,from ,to ,_))
      (d (format "${code(\"/examples/~a\", ~a, ~a)}" f from to))]
    [`(reachex #:dir "rpc-client" py-impl 'only ,from ,to ,_)
      (d (format "${code(\"/rpc-client/py/src/reach_rpc/__init__.py\", ~a, ~a)}" from to))]
    [(or
       `(reachex ,f)
       `(reachex #:mode ,_ ,f))
      (d (format "${code(\"/examples/~a\")}" f))]
    [`reach-vers
     (d "${VERSION}")]
    [`(error-version #:to ,t)
     (d (format "${errver(~s)}" t))]
    [`(workshop-deps)
      (d (format "${workshopDeps()}"))]
    [`(workshop-deps ,t)
      (d (format "${workshopDeps(~s)}" t))]
    [`(WIP/XXX)
      (d (format "${workshopWIP()}"))]
    [`(WIP/XXX ,x)
      (d (format "${workshopWIP(~s)}" x))]
    [`(drstep-pr ,t)
      (ego `(section #:tag ,(format "~a-pr" t) "Problem Analysis"))]
    [`(drstep-dd ,t)
      (ego `(section #:tag ,(format "~a-dd" t) "Data Definition"))]
    [`(drstep-cc ,t)
      (ego `(section #:tag ,(format "~a-cc" t) "Communication Construction"))]
    [`(drstep-ai ,t)
      (ego `(section #:tag ,(format "~a-ai" t) "Assertion Insertion"))]
    [`(drstep-ii ,t)
      (ego `(section #:tag ,(format "~a-ii" t) "Interaction Introduction"))]
    [`(drstep-de ,t)
      (ego `(section #:tag ,(format "~a-de" t) "Deployment Decisions"))]
    [`(drstep-dd-datatype-mn)
      (ego `(margin-note "Refer to " (secref "ref-programs-types") "for a reminder of what data types are available in Reach."))]
    [`(drstep-pr-stop)
      (d "**Write down the problem analysis of this program as a comment.**")]
    [`(drstep-dd-stop)
      (d "**Write down the data definitions for this program as definitions.**")]
    [`(drstep-cc-stop1)
      (d "**Write down the communication pattern for this program as comments.**")]
    [`(drstep-cc-stop2)
      (d "**Write down the communication pattern for this program as code.**")]
    [`(drstep-ai-stop1)
      (d "**Write down the properties you know are true about the various values in the program.**")]
    [`(drstep-ai-stop2)
      (d "**Insert assertions into the program corresponding to facts that should be true.**")]
    [`(drstep-ii-stop)
      (d "**Insert `interact` calls to the frontend into the program.**")]
    [`(drstep-de-stop)
      (d "**Decide how you will deploy and use this application.**")]
    [`(pkg-fmts)
      (ego `(verbatim "
@account/repo
@account/repo:
@account/repo:a/b/file.rsh
@account/repo:a/b/
@account/repo:file.rsh
@account/repo#
@account/repo#:
@account/repo#:a/b/file.rsh
@account/repo#:a/b/
@account/repo#:file.rsh
@account/repo#ref
@account/repo#ref:
@account/repo#ref:a/b/file.rsh
@account/repo#ref:a/b/
@account/repo#ref:file.rsh
@server:account/repo
@server:account/repo:
@server:account/repo:a/b/file.rsh
@server:account/repo:a/b/
@server:account/repo:file.rsh
@server:account/repo#
@server:account/repo#:
@server:account/repo#:a/b/file.rsh
@server:account/repo#:a/b/
@server:account/repo#:file.rsh
@server:account/repo#ref
@server:account/repo#ref:
@server:account/repo#ref:a/b/file.rsh
@server:account/repo#ref:a/b/
@server:account/repo#ref:file.rsh
"))]
    [x
      (set-box! BAD #t)
      (define xs (pretty-format x #:mode 'write))
      (eprintf "XXX ~a\n" (string-limit xs 70))
      (d "XXX ")
      (d xs)]))

(define (string-limit s n)
  (substring s 0 (min n (string-length s))))

(define (egol l)
  (for-each ego l))

(define (go! sp dest)
  (match-define
    `(module ,_ ,_ (#%module-begin doc ,@cs))
    (syntax->datum (read-lang-file sp)))
  (with-output-to-file dest
    #:exists 'replace
    (lambda ()
      (egol cs))))

(define BAD (box #f))
(define mint-scope (box #f))
(module+ main
  (define ns (normalize-path scrbl))
  (for ([p (in-directory scrbl)])
    (define bn (file-name-from-path p))
    (when (equal? #".scrbl" (path-get-extension bn))
      (set-box! BAD #f)
      (set-box! mint-scope #f)
      (define rp (find-relative-path ns (normalize-path p)))
      (define n (build-path "src" (path-replace-extension rp #".md")))
      (make-parent-directory* n)
      (go! p n)
      (when (unbox BAD)
        (eprintf "^ >>> ~a\n" n)))))