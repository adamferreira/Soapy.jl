
"""
http://soapcalc.net/info/SoapQualities.asp:

Hardness -
This refers to the hardness of the soap bar.
Higher is harder.  A range of 29 to 54 is satisfactory for this soap quality.
A low Iodine value also contributes to hardness (see below).

Cleansing -
This refers to the soap's ability to grab on to oils.
A soap molecule is a chain of carbon atoms. One end of the chain attracts water, the other end attracts oil.
When you wash your skin with soap and water, multiple chains will gather around a droplet of oil (which contains, for lack of a better word, dirt) with their oil-hungry ends attached to the oil droplet.
The water hungry ends are surrounded with water. To make this happen you need to mix up (scrub or rub) the soap and water on your skin.
When you rinse, the oil droplets with the attached soap molecules are washed away.

Some soap molecules can have a very hungry oil grabbing end.
Soap made with too much Lauric and/or Myristic Acid can irritate the skin by washing away not only the top dirty layer of oils, but also the protective layer of surface oils on the skin.
Generally speaking, keeping the total of coconut and palm kernel in your recipe to no more than 30-35% is considered the norm.
However, when using large or very large percentages of coconut and palm kernel the strong cleansing can be compensated for by superfating with an oil or butter that has a high conditioning value.
A typical range for Cleansing would be 12 to 22.

Condition -
Conditioning refers to the soap’s emollient content.
A soap’s emollients are left on the skin. They help the skin  retain moisture.
They sooth the skin and keep it soft.  A range of 44 to 69 is satisfactory for this soap quality.

Bubbly lather -
This refers to the soap’s ability to lather up and get bubbly.
A typical range of values would be 14 to 46.
The higher Bubbly numbers will tend to produce a foamy, fluffy lather rather than a creamy lather with littler or no bubbles.

Creamy lather -
This value indicates the stability and creaminess of the lather.
Usually, increasing Bubbly will decrease Creamy and vice versa.
A range of 16 to 48 is common here.
The higher Creamy numbers will tend to produce a creamy lather with lesser amounts of bubbles or foam.
Soap made with oils that do not contain Lauric, Myristic or Ricinoleic acids will produce a soap with just creamy lather.
An example would be 100% olive oil soap.

Iodine -
As a general rule, the lower the number, the harder the bar and the less the conditioning qualities and vice versa.
A recipe with iodine values higher than 70 will tend to produce a somewhat soft bar of soap.
Definition: number of grams of iodine that will react with the double bonds in 100 grams of fats or oils.

INS -
A measure of the physical qualities of the soap based on the SAP and iodine value.
This value was introduced by Dr. Robert S. McDaniel in his wonderful book "Essentially Soap".
The exact origin of the value is unclear but INS is derived from Iodine value and the SAP value;
hence INS - "Iodine ’n SAP"  If the value is not in "Essentially Soap", it is estimated by subtracting the Iodine Value from the KOH SAP.
It is used to predict the physical characteristics of the soap bar - the ideal being 160.
Experience has proven a range of about 136 - 170 will gennerally be acceptable.

Summary of values:
Hardness	29 to 54
Cleansing	12 to 22
Condition	44 to 69
Bubbly lather	14 to 46
Creamy lather	16 to 48
Iodine	41 to 70 (lower = harder bar)
INS	136 to 170 (higher = harder bar)
"""

SATURATED_FAT = [
    :Caprylic,
    :Capric,
    :Lauric,
    :Myristic,
    :Palmitic,
    :Stearic,
    :Arachidic,
    :Behenic,
    :Lignoceric,
    :Cerotic
]
# https://en.wikipedia.org/wiki/List_of_unsaturated_fatty_acids
UNSATURATED_FAT = [
    :Ricinoleic,
    :Oleic,
    :Linoleic,
    :Linolenic
]

FATTY_ACIDS = vcat(SATURATED_FAT, UNSATURATED_FAT)

QUALITIES = [
    :Hardness,
    :Cleansing,
    :Bubbly,
    :Creamy,
    :Conditioning,
    :Iodine,
    :INS
]

struct Qualities{T}
    Hardness::T
    Cleansing::T
    Bubbly::T
    Creamy::T
    Conditioning::T
    Iodine::T
    INS::T
end


# Matrix giving fatty acid contribution to a soap quality
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
# QUALITY_MATRIX = [
#     [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
#     [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
#     [1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
#     [1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0],
#     [0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0],
#     [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
#     [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
#     [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]
# ]
# TODO: Fill with 0 and add only ones (sparse)
QUALITY_MATRIX = Dict(
    :Caprylic =>   Dict(:Hardness=>1.0, :Cleansing=>1.0, :Bubbly=>1.0, :Creamy=>0.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Capric =>     Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>0.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Lauric =>     Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>0.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Myristic =>   Dict(:Hardness=>1.0, :Cleansing=>1.0, :Bubbly=>1.0, :Creamy=>0.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Palmitic =>   Dict(:Hardness=>1.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>1.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Stearic =>    Dict(:Hardness=>1.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>1.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Arachidic =>  Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>0.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Behenic =>    Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>0.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Lignoceric => Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>0.0, :Conditioning=>0.0, :Iodine=>0.0, :INS=>0.0),
    :Ricinoleic => Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>1.0, :Creamy=>1.0, :Conditioning=>1.0, :Iodine=>0.0, :INS=>0.0),
    :Oleic =>      Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>0.0, :Conditioning=>1.0, :Iodine=>0.0, :INS=>0.0),
    :Linoleic =>   Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>0.0, :Conditioning=>1.0, :Iodine=>0.0, :INS=>0.0),
    :Linolenic =>  Dict(:Hardness=>0.0, :Cleansing=>0.0, :Bubbly=>0.0, :Creamy=>0.0, :Conditioning=>1.0, :Iodine=>0.0, :INS=>0.0)
)

recommended_qualities()::Dict{Symbol, Range{Float}} = Dict{Symbol, Range{Float}}(
    :Hardness => 29.0..54.0,
    :Cleansing => 2.0..22.0,
    :Bubbly => 14.0..46.0,
    :Creamy => 16.0..48.0,
    :Conditioning => 44.0..69.0,
    :Iodine => 41.0..70.0,
    :INS => 136.0..170.0
)

# https://www.fromnaturewithlove.com/resources/sapon.asp
# http://www.certified-lye.com/lye-soap.html#:~:text=Because%20the%20water%20is%20used,of%20lye%20from%20the%20result
struct Oil
    # name of the oil
    name::String
    # Saponification index range
    sap::Range{Int64}
    # Saponification index when using Lye
    sap_naoh::Float64
    # Saponification index when using KOH
    sap_koh::Float64
    # Iodine index content
    iodine::Float64
    # INS index = overall quality
    ins::Float64
    # Price in €/Kg
    price::Float64
    # Fatty Acid Compostion (sum = 1.0)
    fa_composition::Dict{Symbol, Float64}
    # Is oil available for mix
    available::Bool
end

function load_oils(oil_database::String)::DataFrame

    function default_value(d, k, default = 0.0 )
        return haskey(d, k) ? d[k] : default
    end

    oil_file = joinpath(DATADIR, oil_database)
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
        __fa_compositon = Dict(map(fa -> fa => 0.0, FATTY_ACIDS))
        for (fa, val) in o["fatty-acid-composition"]
            __fa_compositon[Symbol(fa)] = val
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
                __fa_compositon,
                __available
            )
        )
    end
    return to_df(oils)
end