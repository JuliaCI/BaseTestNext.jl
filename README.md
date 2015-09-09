# BaseTestNext

[![Build Status](https://travis-ci.org/IainNZ/BaseTestNext.jl.svg?branch=master)](https://travis-ci.org/IainNZ/BaseTestNext.jl)
[![codecov.io](http://codecov.io/github/IainNZ/BaseTestNext.jl/coverage.svg?branch=master)](http://codecov.io/github/IainNZ/BaseTestNext.jl?branch=master)

## Options

The `@testset` macro can be given options in the form

```julia
@testset "description" option1=val begin
    ...
end
```

Currently there is one allowed option, `verbosity`, which defaults to `typemax(Int)`.
BaseTestNext will report results for all `@testset`s nested less then this
depth, and beyond that will only report errors. A value of `0` will not report
any passed tests, `1` will show passed results for top-level `@testset`s, etc.
