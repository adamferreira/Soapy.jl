module Soapy

using DataFrames
using JSON

include("utils.jl")
export type_to_df, to_df

include("oils.jl")
export Oil, load_oils


end