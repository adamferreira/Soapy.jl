
# Place holder
function soapykey(v::V)::K where {K,V} end
soapykey(k::Int)::String = "$(k)"

Base.show(io::IO, d::SoapyDict) = Base.show(io, d.map)

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

Base.isempty(t::SoapyDict) = (Base.length(t.map) == 0)
Base.length(t::SoapyDict) = Base.length(t.map)



d = SoapyDict{String,Int}([1,2,5,9,8,7,11])
println(d)