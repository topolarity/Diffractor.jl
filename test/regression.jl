module regression_tests
using Diffractor
using Diffractor: var"'", ∂⃖, DiffractorRuleConfig
using ChainRules
using ChainRulesCore
using ChainRulesCore: ZeroTangent, NoTangent, frule_via_ad, rrule_via_ad
using LinearAlgebra

using Test

const fwd = Diffractor.PrimeDerivativeFwd
const bwd = Diffractor.PrimeDerivativeBack


# Regression tests
@test gradient(x -> sum(abs2, x .+ 1.0), zeros(3))[1] == [2.0, 2.0, 2.0]

function f_broadcast(a)
    l = a / 2.0 * [[0. 1. 1.]; [1. 0. 1.]; [1. 1. 0.]]
    return sum(l)
end
@test fwd(f_broadcast)(1.0) == bwd(f_broadcast)(1.0)

# Make sure that there's no infinite recursion in kwarg calls
g_kw(;x=1.0) = sin(x)
f_kw(x) = g_kw(;x)
@test bwd(f_kw)(1.0) == bwd(sin)(1.0)

function f_crit_edge(a, b, c, x)
    # A function with two critical edges. This used to trigger an issue where
    # Diffractor would fail to insert edges for the second split critical edge.
    y = 1x
    if a && b
        y = 2x
    end
    if b && c
        y = 3x
    end

    if c
        y = 4y
    end

    return y
end
@test bwd(x->f_crit_edge(false, false, false, x))(1.0) == 1.0
@test bwd(x->f_crit_edge(true, true, false, x))(1.0) == 2.0
@test bwd(x->f_crit_edge(false, true, true, x))(1.0) == 12.0
@test bwd(x->f_crit_edge(false, false, true, x))(1.0) == 4.0

# Issue #27 - Mixup in lifting of getfield
let var"'" = bwd
    @test (x->x^5)''(1.0) == 20.
    @test_broken (x->x^5)'''(1.0) == 60.
end

# Issue #38 - Splatting arrays
@test gradient(x -> max(x...), (1,2,3))[1] == (0.0, 0.0, 1.0)
@test gradient(x -> max(x...), [1,2,3])[1] == [0.0, 0.0, 1.0]

# Issue #40 - Symbol type parameters not properly quoted
@test Diffractor.∂⃖recurse{1}()(Val{:transformations})[1] === Val{:transformations}()

# PR #43
loss(res, z, w) = sum(res.U * Diagonal(res.S) * res.V) + sum(res.S .* w)
x43 = rand(10, 10)
@test Diffractor.gradient(x->loss(svd(x), x[:,1], x[:,2]), x43) isa Tuple{Matrix{Float64}}

# PR # 45 - Calling back into AD from ChainRules
y45, back45 = rrule_via_ad(DiffractorRuleConfig(), x -> log(exp(x)), 2)
@test y45 ≈ 2.0
@test back45(1) == (ZeroTangent(), 1.0)

z45, delta45 = frule_via_ad(DiffractorRuleConfig(), (0,1), x -> log(exp(x)), 2)
@test z45 ≈ 2.0
@test delta45 ≈ 1.0

# PR #82 - getindex on non-numeric arrays
@test gradient(ls -> ls[1](1.), [Base.Fix1(*, 1.)])[1][1] isa Tangent{<:Base.Fix1}

@testset "broadcast" begin
    @test gradient(x -> sum(x ./ x), [1,2,3]) == ([0,0,0],)  # derivatives_given_output
    @test gradient(x -> sum(sqrt.(atan.(x, transpose(x)))), [1,2,3])[1] ≈ [0.2338, -0.0177, -0.0661] atol=1e-3
    @test gradient(x -> sum(exp.(log.(x))), [1,2,3]) == ([1,1,1],)

    @test gradient(x -> sum((exp∘log).(x)), [1,2,3]) == ([1,1,1],)  # frule_via_ad
    exp_log(x) = exp(log(x))
    @test gradient(x -> sum(exp_log.(x)), [1,2,3]) == ([1,1,1],)
    @test gradient((x,y) -> sum(x ./ y), [1 2; 3 4], [1,2]) == ([1 1; 0.5 0.5], [-3, -1.75])
    @test gradient((x,y) -> sum(x ./ y), [1 2; 3 4], 5) == ([0.2 0.2; 0.2 0.2], -0.4)
    @test gradient(x -> sum((y -> y/x).([1,2,3])), 4) == (-0.375,)  # closure

    @test gradient(x -> sum(sum, (x,) ./ x), [1,2,3])[1] ≈ [-4.1666, 0.3333, 1.1666] atol=1e-3  # array of arrays
    @test gradient(x -> sum(sum, Ref(x) ./ x), [1,2,3])[1] ≈ [-4.1666, 0.3333, 1.1666] atol=1e-3
    @test gradient(x -> sum(sum, (x,) ./ x), [1,2,3])[1] ≈ [-4.1666, 0.3333, 1.1666] atol=1e-3
    @test gradient(x -> sum(sum, (x,) .* transpose(x)), [1,2,3])[1] ≈ [12, 12, 12]  # must not take the * fast path

    @test gradient(x -> sum(x ./ 4), [1,2,3]) == ([0.25, 0.25, 0.25],)
    @test gradient(x -> sum([1,2,3] ./ x), 4) == (-0.375,)  # x/y rule
    @test gradient(x -> sum(x.^2), [1,2,3]) == ([2.0, 4.0, 6.0],)  # x.^2 rule
    @test gradient(x -> sum([1,2,3] ./ x.^2), 4) == (-0.1875,)  # scalar^2 rule

    @test gradient(x -> sum((1,2,3) .- x), (1,2,3)) == (Tangent{Tuple{Int,Int,Int}}(-1.0, -1.0, -1.0),)
    @test gradient(x -> sum(transpose([1,2,3]) .- x), (1,2,3)) == (Tangent{Tuple{Int,Int,Int}}(-3.0, -3.0, -3.0),)
    @test gradient(x -> sum([1 2 3] .+ x .^ 2), (1,2,3)) == (Tangent{Tuple{Int,Int,Int}}(6.0, 12.0, 18.0),)

    @test gradient(x -> sum(x .> 2), [1,2,3]) |> only |> iszero  # Bool output
    @test gradient(x -> sum(1 .+ iseven.(x)), [1,2,3]) |> only |> iszero
    @test gradient((x,y) -> sum(x .== y), [1,2,3], [1 2 3]) == (NoTangent(), NoTangent())
    @test gradient(x -> sum(x .+ [1,2,3]), true) |> only |> iszero  # Bool input
    @test gradient(x -> sum(x ./ [1,2,3]), [true false]) |> only |> iszero
    @test gradient(x -> sum(x .* transpose([1,2,3])), (true, false)) |> only |> iszero

    tup_adj = gradient((x,y) -> sum(2 .* x .+ log.(y)), (1,2), transpose([3,4,5]))
    @test tup_adj[1] == Tangent{Tuple{Int64, Int64}}(6.0, 6.0)
    @test tup_adj[2] ≈ [0.6666666666666666 0.5 0.4]
    @test tup_adj[2] isa Transpose
    @test gradient(x -> sum(atan.(x, (1,2,3))), Diagonal([4,5,6]))[1] isa Diagonal

    @test gradient(x -> sum((y -> (x*y)).([1,2,3])), 4.0) == (6.0,)  # closure
end

@testset "broadcast, 2nd order" begin
    @test gradient(x -> gradient(y -> sum(y .* y), x)[1] |> sum, [1,2,3.0])[1] == [2,2,2]  # calls "split broadcasting generic" with f = unthunk
    @test gradient(x -> gradient(y -> sum(y .* x), x)[1].^3 |> sum, [1,2,3.0])[1] == [3,12,27]
    @test_broken gradient(x -> gradient(y -> sum(y .* 2 .* y'), x)[1] |> sum, [1,2,3.0])[1] == [12, 12, 12]  # Control flow support not fully implemented yet for higher-order

    @test_broken gradient(x -> sum(gradient(x -> sum(x .^ 2 .+ x'), x)[1]), [1,2,3.0])[1] == [6,6,6]  # BoundsError: attempt to access 18-element Vector{Core.Compiler.BasicBlock} at index [0]
    @test_broken gradient(x -> sum(gradient(x -> sum((x .+ 1) .* x .- x), x)[1]), [1,2,3.0])[1] == [2,2,2]
    @test_broken gradient(x -> sum(gradient(x -> sum(x .* x ./ 2), x)[1]), [1,2,3.0])[1] == [1,1,1]

    @test_broken gradient(x -> sum(gradient(x -> sum(exp.(x)), x)[1]), [1,2,3])[1] ≈ exp.(1:3)  # MethodError: no method matching copy(::Nothing)
    @test_broken gradient(x -> sum(gradient(x -> sum(atan.(x, x')), x)[1]), [1,2,3.0])[1] ≈ [0,0,0]
    @test_broken gradient(x -> sum(gradient(x -> sum(transpose(x) .* x), x)[1]), [1,2,3]) == ([6,6,6],) # accum(a::Transpose{Float64, Vector{Float64}}, b::ChainRulesCore.Tangent{Transpose{Int64, Vector{Int64}}, NamedTuple{(:parent,), Tuple{ChainRulesCore.NoTangent}}})
    @test_broken gradient(x -> sum(gradient(x -> sum(transpose(x) ./ x.^2), x)[1]), [1,2,3])[1] ≈ [27.675925925925927, -0.824074074074074, -2.1018518518518516]

    @test_broken gradient(z -> gradient(x -> sum((y -> (x^2*y)).([1,2,3])), z)[1], 5.0) == (12.0,)
end

end