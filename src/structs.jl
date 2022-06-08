# Place holder
function soapykey(v::V)::K where {K,V} end

mutable struct SoapyDict{K,V} <: AbstractDict{K,V}
    values::Vector{V}
    map::Dict{K,UInt}
    
    function SoapyDict{K,V}(v::Vector{V}) where {K,V}
        __map = Dict{K,UInt}()
        for i = 1:length(v)
            push!(__map, soapykey(v[i]) => i)
        end
        return new(v, __map)
    end
end

isempty(t::SoapyDict) = (length(t.map) == 0)
length(t::SoapyDict) = length(t.map)


function iterate(d::SoapyDict{K,V}) where {K, V}
    
end

soapykey(k::Int)::String = "$(k)"

#Base.show(io::IO, d::SoapyDict) = Base.show(io, d.map)

d = SoapyDict{String,Int}([1,2,5,9,8,7,11])
println(d)
println(length(d.map))