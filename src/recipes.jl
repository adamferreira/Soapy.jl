using JuMP, GLPK

include("oils.jl")

mutable struct RecipeCalculator
    oils::Vector{Oil}
    target_weight::Pair{Float64, Float64}
    target_qualities::Dict{String, Pair{Float64, Float64}}
    max_oils::Int64

    function RecipeCalculator()
        oils = load_oils() 
        return new(
                oils,
                0.0 => typemax(Float64),
                Dict((q => (0.0 => 100.0) for q in qualities())),
                length(oils)
            )
    end
end

function soap_weight!(r::RecipeCalculator, min::Float64, max::Float64)
    r.target_weight = min => max
end

function simulate(r::RecipeCalculator)
    recipe = Model(GLPK.Optimizer)
    # Oil volumes used in the recipe
    @variable(recipe, oil_vol[i=1:length(r.oils)] >= 0.0, binary = true)
    println(num_variables(recipe))
end