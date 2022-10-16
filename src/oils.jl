using JSON
using DataClasses

OILS_DIR = joinpath(@__DIR__, "..", "data")

# Range is a pair
const Range{T} = Pair{T, T}
# Operator to easily define value ranges
(..)(lb::T, ub::T) where T <: Number = Range{T}(lb, ub)

function midpoint(x::Range{T})::Float64 where T <: Number
    return 0.5 * (x.first + x.second)
end

@mutable_dataclass Qualities{T} begin
    Hardness::T
    Cleansing::T
    Conditioning::T
    Bubbly::T
    Creamy::T
    Iodine::T
    INS::T
end

@dataclass FattyAcids{T<:Number} begin
    Lauric::T = 0.0
    Myristic::T = 0.0
    Palmitic::T = 0.0
    Stearic::T = 0.0
    Ricinoleic::T = 0.0
    Oleic::T = 0.0
    Linoleic::T = 0.0
    Linolenic::T = 0.0
end

# Matrix giving ffaty acid contribution to a soap quality
# If M[f, Q] = 1 then fatty acid f contributes to the quality f of the soap
#               Hardness    Cleansing   Bubbly  Creamy  Conditioning
# Lauric	    Yes	        Yes	        Yes	 	No      No 
# Myristic	    Yes	        Yes	        Yes	 	No      No 
# Palmitic	    Yes	 	 	No          No      Yes	    No
# Stearic	    Yes         No          No      Yes     No
# Ricinoleic    No          No          Yes     Yes     Yes
# Oleic         No          No          No      No      Yes
# Linoleic      No          No          No      No      Yes
# Linolenic     No          No          No      No      Yes
# http://soapcalc.net/info/SoapQualities.asp
# Fatty acids do NOT contribute to Iodine and INS, those are calculated before hands
# Iodine        No          No          No      No      No
# INS           No          No          No      No      No
QUALITY_MATRIX = [
    [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
    [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
    [1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
    [1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
]

function qualities()::Tuple{Vararg{Symbol}}
    return fieldnames(Qualities)
end

function fatty_acids()::Tuple{Vararg{Symbol}}
    return fieldnames(FattyAcids)
end

function recommended_qualities()::Qualities{Range{Float64}}
    return Qualities{Range{Float64}}(
        Hardness = 29.0..54.0,
        Cleansing = 2.0..22.0,
        Conditioning = 44.0..69.0,
        Bubbly = 14.0..46.0,
        Creamy = 16.0..48.0,
        Iodine = 41.0..70.0,
        INS = 136.0..170.0
    )
end

# https://www.fromnaturewithlove.com/resources/sapon.asp
# http://www.certified-lye.com/lye-soap.html#:~:text=Because%20the%20water%20is%20used,of%20lye%20from%20the%20result
@dataclass Oil begin
    # name of the oil
    name::String
    # Saponification index range
    sap::Range{Int64}
    # Saponification index when using Lye
    sap_naoh::Float64
    # When using KOH
    sap_koh::Float64
    # Iodine index content
    iodine::Float64
    # INS index = overall quality
    ins::Float64
    # Price in €/Kg
    price::Float64
    # Fatty Acid Compostion (sum = 1.0)
    fa_composition::Dict{String, Float64}
    # Is oil available for mix
    available::Bool
end
            
# If noah was not found in data, compute it from sap value
# Source : https://www.fromnaturewithlove.com/resources/sapon.asp     
function naoh(oil::Oil)
    if oil.sap_naoh != 0.0
        return oil.sap_naoh
    else
        return midpoint(oil.sap) / 1402.50       
    end
end

# Same goes for KOH
function koh(oil::Oil)
    if oil.sap_koh != 0.0
        return oil.sap_koh
    else
        return midpoint(oil.sap) / 1000.0       
    end
end

            
function load_oils(oil_database::String)::Vector{Oil}

    function default_value(d, k, default = 0.0 )
        return haskey(d, k) ? d[k] : default
    end

    oil_file = joinpath(OILS_DIR, oil_database)
    if !isfile(oil_file)
        throw(error("Cannot find oil file $oil_file"))
    end
    json = JSON.parsefile(oil_file)
    oils = Vector{Oil}()
    for o in json
        __sap = split(o["saponification"]["SAP-value"], "-")
        __naoh = default_value(o["saponification"], "NaOH")
        __koh = default_value(o["saponification"], "KOH")
        __iodine = default_value(o["saponification"], "Iodine")
        __ins = default_value(o["saponification"], "INS")
        __price_liter = default_value(o, "price (€/L)")
        __available = convert(Bool, default_value(o, "available", 1.0))
        __density = 0.0
        if haskey(o, "density")
            d = split(o["density"], "-")
            __density = midpoint(parse(Float64, d[1])..parse(Float64, d[2]))
        end
        push!(oils, 
            Oil(
                o["name"], 
                parse(Int64, __sap[1])..parse(Int64, __sap[2]),
                __naoh,
                __koh,
                __iodine,
                __ins,
                __price_liter * __density,
                o["fatty-acid-composition"],
                __available
            )
        )
    end
    return oils
end
