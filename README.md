# BaseTestNext

[![Build Status](https://travis-ci.org/IainNZ/BaseTestNext.jl.svg?branch=master)](https://travis-ci.org/IainNZ/BaseTestNext.jl)
[![codecov.io](http://codecov.io/github/IainNZ/BaseTestNext.jl/coverage.svg?branch=master)](http://codecov.io/github/IainNZ/BaseTestNext.jl?branch=master)

## Settings

Currently there is one setting, `:verbose_depth`, which defaults to `Inf`.
BaseTestNext will report results for all `@testset`s nested less then this
depth, and beyond that will only report errors. A value of `0` will not report
any passed tests, `1` will show passed results for top-level `@testset`s, etc.
Configure the setting by adding `BaseTestNext.settings[:verbose_depth] = 1` to
your test suite.
