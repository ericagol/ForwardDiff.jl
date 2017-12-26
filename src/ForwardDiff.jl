# __precompile__()

module ForwardDiff

#=
This is a mock implementation of forward-mode AD using Cassette.

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

using Cassette: @context, @primitive, unbox, meta, hasmeta, overdub, Box
using DiffRules

@context DiffCtx

################################
# "dual number" implementation #
################################

for (M, f, arity) in DiffRules.diffrules()
    M == :Base || continue
    if arity == 1
        dfdx = DiffRules.diffrule(M, f, :vx)
        @eval begin
            @primitive ctx::DiffCtx function (::typeof($f))(x::@Box)
                vx, dx = unbox(ctx, x), meta(ctx, x)
                return Box(ctx, $f(vx), propagate($dfdx, dx))
            end
        end
    elseif arity == 2
        dfdx, dfdy = DiffRules.diffrule(M, f, :vx, :vy)
        @eval begin
            @primitive ctx::DiffCtx function (::typeof($f))(x::@Box, y::@Box)
                vx, dx = unbox(ctx, x), meta(ctx, x)
                vy, dy = unbox(ctx, y), meta(ctx, y)
                return Box(ctx, $f(vx, vy), propagate($dfdx, dx, $dfdy, dy))
            end
            @primitive ctx::DiffCtx function (::typeof($f))(x::@Box, vy)
                vx, dx = unbox(ctx, x), meta(ctx, x)
                return Box(ctx, $f(vx, vy), propagate($dfdx, dx))
            end
            @primitive ctx::DiffCtx function (::typeof($f))(vx, y::@Box)
                vy, dy = unbox(ctx, y), meta(ctx, y)
                return Box(ctx, $f(vx, vy), propagate($dfdy, dy))
            end
        end
    end
end

propagate(dfdx::Number, dx::AbstractVector) = dfdx * dx

propagate(dfdx::Number, dx::AbstractVector, dfdy::Number, dy::AbstractVector) = propagate(dfdx, dx) + propagate(dfdy, dy)

#######
# API #
#######

isscalar(::Type{<:Any}) = false
isscalar(::Type{<:Number}) = true
isscalar(::Type{<:Box{<:Any,U}}) where {U} = isscalar(U)
isscalar(x) = isscalar(typeof(x))

function diff(f, x)
    ctx = DiffCtx(f)
    if isscalar(x)
        y = overdub(ctx, f)(Box(ctx, x, [one(x)]))
        if isscalar(y)
            return hasmeta(ctx, y) ? meta(ctx, y)[] : zero(unbox(ctx, y))
        end
    end
    error("API does not yet support non-scalar functions")
end

end # module ForwardDiff
