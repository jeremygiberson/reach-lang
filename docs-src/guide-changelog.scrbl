#lang scribble/manual
@(require "lib.rkt")

@title[#:version reach-vers #:tag "guide-changelog"]{Reach's Changelog}

Below is a list of changes to Reach.
Versions and changes-within-versions are listed in reverse-chronological order: newest things first.

@section[#:style 'hidden-number]{0.1.3: 2020/07 - present}

Version 0.1.3 is the current Reach release candidate version.
@itemlist[
@item{2021/07/01: Algorand connector updated to AVM 0.9 (TEAL 4)}
@item{2021/07/01: Algorand devnet version updated to 2.7.1, plus @litchar{DevMode} patch}
@item{2021/07/01: Algorand devnet image renamed to @litchar{devnet-algo}}
@item{2021/07/01: version tagged}
]

@section[#:style 'hidden-number]{0.1.2: 2020/09 - 2021/07}

Version 0.1.2 is the current Reach release version.

It is the last version that supports Algorand using TEAL3; if you deployed a contract on Algorand using Reach version 0.1.2, you will need to continue accessing it via the 0.1.2 version of the standard library.

@itemlist[
@item{2021/07/09: @reachin{.define} component added to @reachin{parallelReduce}}
@item{2021/07/08: @secref["ref-error-codes"] created}
@item{2021/06/20: @tech{Token minting} introduced, with implementation on ETH.}
@item{... many interesting things ...}
@item{2020/09/01: version tagged}
]

@section[#:style 'hidden-number]{0.1.1: 2019/09 - 2020/09}

Version 0.1.1 was used prior to our documented release process.

@section[#:style 'hidden-number]{0.1.0: 2019/09 - 2020/09}

Version 0.1.0 was used prior to our documented release process.