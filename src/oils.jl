using JSON

export load_oils

OILS_FILE = joinpath(@__DIR__, "..", "data", "oils.json")

@enum FattyAcid begin
    Lauric = 1	 
    Myristic 
    Palmitic
    Stearic
    Ricinoleic
    Oleic
    Linoleic
    Linolenic
end

@enum Quality begin
    Hardness = 1 
    Cleansing 
    Bubbly
    Creamy
    Conditioning
end

FATTY_ACIDS = Dict(zip([string(i) for i in instances(FattyAcid)], [Int64(i) for i in instances(FattyAcid)]))
QUALITIES = Dict(zip([string(i) for i in instances(Quality)], [Int64(i) for i in instances(Quality)]))

function qualities()::Vector{String}
    return collect(keys(QUALITIES))
end

function recommended_qualities()::Dict{String, Pair{Float64, Float64}}
    return Dict(
        "Hardness" => (29.0 => 54.0),
        "Cleansing" => (12.0 => 22.0),
        "Conditioning" => (44.0 => 69.0),
        "Bubbly" => (14.0 => 46.0),
        "Creamy" => (16.0 => 48.0),
    )
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
QUALITY_MATRIX = [
    [1.0, 1.0, 1.0, 0.0, 0.0],
    [1.0, 1.0, 1.0, 0.0, 0.0],
    [1.0, 0.0, 0.0, 1.0, 0.0],
    [1.0, 0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 1.0, 1.0, 1.0],
    [0.0, 0.0, 0.0, 0.0, 1.0],
    [0.0, 0.0, 0.0, 0.0, 1.0],
    [0.0, 0.0, 0.0, 0.0, 1.0],
]

# https://www.fromnaturewithlove.com/resources/sapon.asp
mutable struct Oil
    name::String
    # Saponification index
    sap::Pair{Int64, Int64}
    # Saponification index when using Lye
    sap_naoh::Float64
    # When using KOH
    sap_koh::Float64
    # Fatty Acid Compostion (sum = 1.0)
    fa_composition::Dict{String,Float64}
end

function quality_contribution(fatty_acid::String, quality::String)::Float64
    return QUALITY_MATRIX[FATTY_ACIDS[fatty_acid]][QUALITIES[quality]]
end


function load_oils()::Vector{Oil}
    if !isfile(OILS_FILE)
        throw(error("Cannot find oil file $OILS_FILE"))
    end
    json = JSON.parsefile(OILS_FILE)
    oils = Vector{Oil}()
    for o in json
        sap = split(o["saponification"]["value"], "-")
        push!(oils, 
            Oil(
                o["name"], 
                Pair{UInt64, UInt64}(parse(Int64, sap[1]), parse(Int64, sap[2])),
                o["saponification"]["NaOH"],
                o["saponification"]["KOH"],
                o["fatty-acid-composition"],
            )
        )
    end
    return oils
end