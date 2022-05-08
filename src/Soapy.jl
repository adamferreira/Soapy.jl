module Soapy

include("recipes.jl")

@time r = RecipeCalculator()
r.target_qualities = recommended_qualities()
r.target_qualities = Dict(
    "Hardness" => (0.0 => 54.0),
    "Cleansing" => (0.0 => 22.0),
    "Conditioning" => (0.0 => 69.0),
    "Bubbly" => (0.0 => 46.0),
    "Creamy" => (0.0 => 48.0),
    "Iodine" => (0.0 => 70.0),
    "INS" => (0.0 => 170.0),
)
@time maximise_quality(r, "INS")
end