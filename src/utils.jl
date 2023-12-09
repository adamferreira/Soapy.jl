# Data dir
DATADIR = joinpath(@__DIR__, "..", "data")

# A tabular data is eiter an object T, or a dataframe representation of a collection of T
const TabularData{T} = Union{T, DataFrame}

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

function to_df(x::T)::DataFrame where {T}
    return to_df([x])
end

function to_df(x::DataFrame)::DataFrame
    return x
end