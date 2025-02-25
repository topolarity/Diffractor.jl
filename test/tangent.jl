module tagent
using Diffractor
using Diffractor: AbstractZeroBundle, ZeroBundle, DNEBundle
using Diffractor: TaylorBundle, TaylorTangentIndex, CompositeBundle
using ChainRulesCore
using Test

@testset "AbstractZeroBundle" begin
    @testset "Hierachy" begin
        @test ZeroBundle <: AbstractZeroBundle
        @test DNEBundle <: AbstractZeroBundle
        @test ZeroBundle{1} <: AbstractZeroBundle{1}
        @test ZeroBundle{1,typeof(getfield)} <: AbstractZeroBundle{1,typeof(getfield)}
    end

    @testset "Display" begin
        @test repr(ZeroBundle{1}(2.0)) == "ZeroBundle{1}(2.0)"
        @test repr(DNEBundle{1}(getfield)) == "DNEBundle{1}(getfield)"

        @test repr(ZeroBundle{1}) == "ZeroBundle{1}"
        @test repr(ZeroBundle{1, Float64}) == "ZeroBundle{1, Float64}"

        @test repr((ZeroBundle{N, Float64} where N).body) == "ZeroBundle{N, Float64}"

        @test repr(typeof(DNEBundle{1}(getfield))) == "DNEBundle{1, typeof(getfield)}"
    end
end

@testset "AD through constructor" begin
    #https://github.com/JuliaDiff/Diffractor.jl/issues/152
    # hits `getindex(::CompositeBundle{Foo152}, ::TaylorTangentIndex)`
    struct Foo152
        x::Float64
    end

    # Unit Test
    cb = CompositeBundle{1, Foo152}((TaylorBundle{1, Float64}(23.5, (1.0,)),))
    tti = TaylorTangentIndex(1,)
    @test cb[tti] == Tangent{Foo152}(; x=1.0)

    # Integration  Test
    var"'" = Diffractor.PrimeDerivativeFwd
    f(x) = Foo152(x)
    @test f'(23.5) == Tangent{Foo152}(; x=1.0)
end

end  # module
