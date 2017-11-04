# __precompile__()

module ForwardDiff

#=
This is a mock implementation of forward-mode AD using Cassette. This code does not
actually run yet, but it hopefully will in a week or so.

The below implementation constitutes a nearly complete replacement of ForwardDiff's dual
numbers for unary and binary functions. Besides being drastically simpler code, note in
particular the following advantages:

- It doesn't require any extraneous method overloads, such as hashing, conversion/promotion
predicates, irrelevant numeric methods (e.g. `one`/`zero`).

- Safe nested differentiation is baked in, since metadata extraction is contextualized. This
implementation can compute the correct result even in the presence of perturbation confusion.

- It doesn't require dealing with any type ambiguities; new types and even other Cassette
contexts can be completely unaware of `DiffCtx` and still compose correctly.
=#

using Cassette: @context, @primitive, unwrap, meta, Wrapper
using SpecialFunctions
using DiffRules

@context DiffCtx

for (M, f, arity) in DiffRules.diffrules()
    if arity == 1
        dfdx = DiffRules.diffrule(M, f, :vx)
        @eval begin
            @primitive ctx::DiffCtx function (::typeof($f))(x::@Wrapper)
                vx, dx = unwrap(ctx, x), meta(ctx, x)
                return Wrapper(ctx, $f(vx), propagate($dfdx, dx))
            end
        end
    elseif arity == 2
        dfdx, dfdy = DiffRules.diffrule(M, f, :vx, :vy)
        @eval begin
            @primitive ctx::DiffCtx function (::typeof($f))(x::@Wrapper, y::@Wrapper)
                vx, dx = unwrap(ctx, x), meta(ctx, x)
                vy, dy = unwrap(ctx, y), meta(ctx, y)
                return Wrapper(ctx, $f(vx, vy), propagate($dfdx, dx, $dfdy, dy))
            end
            @primitive ctx::DiffCtx function (::typeof($f))(x::@Wrapper, vy)
                vx, dx = unwrap(ctx, x), meta(ctx, x)
                return Wrapper(ctx, $f(vx, vy), propagate($dfdx, dx))
            end
            @primitive ctx::DiffCtx function (::typeof($f))(vx, y::@Wrapper)
                vy, dy = unwrap(ctx, y), meta(ctx, y)
                return Wrapper(ctx, $f(vx, vy), propagate($dfdy, dy))
            end
        end
    end
end

propagate(dfdx::Number, dx::AbstractVector) = dfdx * dx

propagate(dfdx::Number, dx::AbstractVector, dfdy::Number, dy::AbstractVector) = propagate(dfdx, dx) + propagate(dfdy, dy)

end # module ForwardDiff
