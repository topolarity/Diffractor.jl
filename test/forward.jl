module forward_tests
using Diffractor
using Diffractor: var"'", ∂⃖, DiffractorRuleConfig
using ChainRules
using ChainRulesCore
using ChainRulesCore: ZeroTangent, NoTangent, frule_via_ad, rrule_via_ad
using LinearAlgebra

using Test

const fwd = Diffractor.PrimeDerivativeFwd
const bwd = Diffractor.PrimeDerivativeBack



# Minimal 2-nd order forward smoke test
@test Diffractor.∂☆{2}()(Diffractor.ZeroBundle{2}(sin),
    Diffractor.ExplicitTangentBundle{2}(1.0, (1.0, 1.0, 0.0)))[Diffractor.CanonicalTangentIndex(1)] == sin'(1.0)

# Simple Forward Mode tests
let var"'" = Diffractor.PrimeDerivativeFwd
    recursive_sin(x) = sin(x)
    ChainRulesCore.frule(∂, ::typeof(recursive_sin), x) = frule(∂, sin, x)

    # Integration tests
    @test recursive_sin'(1.0) == cos(1.0)
    @test recursive_sin''(1.0) == -sin(1.0)
    # Error: ArgumentError: Tangent for the primal Tangent{Tuple{Float64, Float64}, Tuple{Float64, Float64}}
    # should be backed by a NamedTuple type, not by Tuple{Tangent{Tuple{Float64, Float64}, Tuple{Float64, Float64}}}.
    @test_broken recursive_sin'''(1.0) == -cos(1.0)
    @test_broken recursive_sin''''(1.0) == sin(1.0)
    @test_broken recursive_sin'''''(1.0) == cos(1.0)
    @test_broken recursive_sin''''''(1.0) == -sin(1.0)

    # Test the special rules for sin/cos/exp
    @test sin''''''(1.0) == -sin(1.0)
    @test cos''''''(1.0) == -cos(1.0)
    @test exp''''''(1.0) == exp(1.0)
    @test (x->prod([x, 4]))'(3) == 4
end

# Some Basic Mixed Mode tests
function sin_twice_fwd(x)
    let var"'" = Diffractor.PrimeDerivativeFwd
            sin''(x)
    end
end
let var"'" = Diffractor.PrimeDerivativeFwd
    @test sin_twice_fwd'(1.0) == sin'''(1.0)
end



end