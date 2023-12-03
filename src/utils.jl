# Data dir
DATADIR = joinpath(@__DIR__, "..", "data")

# Range is a pair
const Range{T} = Pair{T, T}
# Operator to easily define value ranges
(..)(lb::T, ub::T) where T <: Number = Range{T}(lb, ub)

# Midpoint operator
function midpoint(x::Range{T})::Float64 where T <: Number
    return 0.5 * (x.first + x.second)
end

"""
    type_to_df(type::Type)::DataFrame

Creates an empty Dataframe for a given types where:
- Colunm names are type field names
- Column types are type field types
"""
function type_to_df(type::Type)::DataFrame
    return DataFrame([(n => t[]) for (n,t) in zip(fieldnames(type), fieldtypes(type))])
end

function to_df(objs::AbstractVector{T})::DataFrame where {T}
    # Creates Dataframe headers from type
    df = type_to_df(T)
    # Populate from collection
    for obj in objs
        push!(df, map(f -> getfield(obj, f), fieldnames(T)))
    end
    
    return df
end