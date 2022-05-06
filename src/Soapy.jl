module Soapy

include("recipes.jl")

@time r = RecipeCalculator()
@time simulate(r)
end