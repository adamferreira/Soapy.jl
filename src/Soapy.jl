module Soapy

using DataFrames
using JSON

include("utils.jl")
export TabularData, Range, .., to_df

include("oils.jl")
export Oil, load_oils

include("models.jl")
export default_options, solve

include("display.jl")
export print_recipe

end