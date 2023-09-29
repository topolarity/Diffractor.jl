# module forward_mutation
using Diffractor
using Diffractor: ∂☆, ZeroBundle, TaylorBundle
using Diffractor: bundle, first_partial, TaylorTangentIndex
using ChainRulesCore
using Test


mutable struct MDemo1
    x::Float64
end

@testset "construction" begin
    🍞 = ∂☆{1}()(ZeroBundle{1}(MDemo1), TaylorBundle{1}(1.5, (1.0,)))
    @test 🍞[TaylorTangentIndex(1)] isa MutableTangent{MDemo1}
    @test 🍞[TaylorTangentIndex(1)].x == 1.0

    🥯 = ∂☆{2}()(ZeroBundle{2}(MDemo1), TaylorBundle{2}(1.5, (1.0, 10.0)))
    @test 🥯[TaylorTangentIndex(1)] isa MutableTangent{MDemo1}
    @test 🥯[TaylorTangentIndex(1)].x == 1.0
    @test 🥯[TaylorTangentIndex(2)] isa MutableTangent
    @test 🥯[TaylorTangentIndex(2)].x == 10.0
end

function double!(val::MDemo1)
    val.x *= 2.0
    return val
end
function wrap_and_double(x)
    val = MDemo1(x)
    double!(val)
end
🐰 = ∂☆{1}()(ZeroBundle{1}(wrap_and_double), TaylorBundle{1}(1.5, (1.0,)))
@test first_partial(🐰) isa MutableTangent{MDemo1}
@test first_partial(🐰).x == 2.0

# second derivative
🐇 = ∂☆{2}()(ZeroBundle{2}(wrap_and_double), TaylorBundle{2}(1.5, (1.0, 10.0)))
@test 🐇[TaylorTangentIndex(1)] isa MutableTangent{MDemo1}
@test 🐇[TaylorTangentIndex(1)].x == 2.0
@test 🐇[TaylorTangentIndex(2)] isa MutableTangent
@test 🐇[TaylorTangentIndex(2)] == 0.0  # returns 20



foo(val) = val^2
🥖 = ∂☆{2}()(ZeroBundle{2}(foo), TaylorBundle{2}(1.0, (0.0, 10.0)))
🥖[TaylorTangentIndex(1)] # returns 0
🥖[TaylorTangentIndex(2)] # returns 20

# end # module