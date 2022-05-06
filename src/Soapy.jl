module Soapy

using JuMP, GLPK

include("oils.jl")

println(load_oils())

end