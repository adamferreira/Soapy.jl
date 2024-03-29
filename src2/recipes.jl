using JuMP, GLPK
# using Ipopt
using DataClasses

include("oils.jl")


# TODO : In DataClasses.jl
function index_mapping(type::Type{T})::Dict{Symbol, UInt32} where T <: AbstractDataClass
    fields = fieldnames(type)
    return Dict{Symbol, UInt32}(
        field => index for (field, index) in zip(fields, 1:length(fields))
    )
end

@mutable_dataclass RecipeOptions begin
    # List of oil to consided for the soap
    oils::Vector{Oil} = []
    # in gram
    target_weight::Float64 = 1000.0
    # Quality value target windows with recommended default values
    target_qualities::Qualities{Range{Float64}} = recommended_qualities()
    # Recommended Soapy qualities
    recommended_qualities::Qualities{Range{Float64}} = recommended_qualities()
    # Min and Max number of different oils to use in the mix
    target_number_of_oils::Range{Int64} = 0..0
    # Lye percent of water + lye solution
    lye_concentration_percent::Float64 = 33.0
    # In percent of total fat
    super_fat_percent::Float64 = 5.0
    # Ratio total fat (usally 3-4% of total fat weight)
    fragrance_percent::Float64 = 4.0
end

function default_options(oil_database::String)::RecipeOptions
    oils = load_oils(oil_database)
    return RecipeOptions(oils = oils, target_number_of_oils = 1..length(oils))
end

# TODO : Make it immutable
@mutable_dataclass Recipe begin
    options::RecipeOptions
    # All weight and amounts are in grams
    soap_weight::Float64
    oil_amounts::Vector{Float64}
    oils_in_recipe::Vector{Int64}
    oil_amount::Float64
    water_amount::Float64
    lye_amount::Float64
    # Prices are in €/kg
    oils_prices::Vector{Float64}
    soap_price::Float64
    qualities::Qualities{Float64}
    # Soapy score
    score::Float64
end

# The penalty score of the soap is the total absolute deviation divided by the maximum possible deviation from target
# Scaled down to a score out of 100
function score(r::Recipe)::Float64
    # Qualities that are taken into account for the score
    quals = setdiff(qualities(), (:INS, :Iodine))
    # Minimal ideal targets
    lowerbounds = [first(getfield(r.options.recommended_qualities, q)) for q in quals]
    # Ideal targets
    targets = [midpoint(getfield(r.options.recommended_qualities, q)) for q in quals]
    # Actual qualities of the recipe
    values = [getfield(r.qualities, q) for q in quals]
    # Worst possible deviation if the qualities where all in recommended range
    # (targets - lowerbounds == upperbounds - target)
    max_deviations = targets - lowerbounds
    # How far are our qualitied from the ideal target (relative in percent)
    deviations = 100. * abs.(values - targets) ./ max_deviations
    # Penalty is the mean of deviation vector; penalty is in [0., 100.]
    penalty = sum(1/length(deviations) .* deviations)
    # Soapy score out of 100
    # A negative Soapy score indicates that some qualities where not in ideal range (custom ranges)
    return 100. - penalty
end

# Best possible Soapy score of the oil database
function best_score(oil_database::String)::Float64
    opt = Soapy.default_options(oil_database)
    # activate all oils in the database for the mix
    for oil in opt.oils
        oil.available = true
    end
    return score(find_recipe(opt))
end

function frangrance_amount(r::Recipe)::Float64
    return r.options.fragrance_percent * 0.01 * r.oil_amount
end

function find_recipe(r::RecipeOptions)::Recipe
    recipe = Model(GLPK.Optimizer)


    println("Mixing $(r.target_number_of_oils.first) to $(r.target_number_of_oils.second) oils together out of $(length(r.oils))")
    println("Will keep soap mass at $(r.target_weight)g")


    # --------------------------
    # Sets (values)
    #---------------------------   
    sv_qualities = qualities()
    sv_fatty_acids = fatty_acids()
    mapping_qualities = index_mapping(Qualities)
    mapping_fatty_acids = index_mapping(FattyAcids)
    # TODO : Model only with available oils
    oils = r.oils#[o for o in r.oils if o.available]

    # --------------------------
    # Sets (indexes)
    #---------------------------   
    s_oils_set = 1:length(oils)#[i for (o,i) in zip(oils, 1:length(oils)) if o.available]
    s_qualtities_set = 1:length(sv_qualities)
    s_fatty_acids_set = 1:length(sv_fatty_acids)


    # --------------------------
    # Constants
    #---------------------------   
    soap_weight = r.target_weight
    fragrance_ratio = r.fragrance_percent / 100.0
    super_fat_ratio = r.super_fat_percent / 100.0
    lye_concentration_ratio = r.lye_concentration_percent / 100.0
    qualities_lb = [0.0 for q in sv_qualities] #[first(getfield(r.target_qualities, q)) for q in sv_qualities]
    qualities_ub = [10000.0 for q in sv_qualities] #[last(getfield(r.target_qualities, q)) for q in sv_qualities]
    # The targeted value of a quality is the midpoint of its recommended range
    qualities_target = [midpoint(getfield(r.recommended_qualities, q)) for q in sv_qualities]
    oil_availabilities = [convert(Float64, oils[i].available) for i in s_oils_set]

    # --------------------------
    # Variables
    #---------------------------
    # Real variables representing masses used in the recipe
    @variable(recipe, v_oil_amounts[i = s_oils_set] >= 0.0) # in grams
    @variable(recipe, v_lye_amounts[i = s_oils_set] >= 0.0) # in grams
    @variable(recipe, v_water_amounts[i = s_oils_set] >= 0.0) # in grams

    # Real variables representing quality values of the recipe
    @variable(recipe, v_qualities[i = s_qualtities_set] >= 0.0)
    # Variable representing absolute deviation of a quality value from its recommended target
    # Δq = Δq⁺ - Δq⁻
    @variable(recipe, v_Δq⁺[i = s_qualtities_set] >= 0.0)
    @variable(recipe, v_Δq⁻[i = s_qualtities_set] >= 0.0)
    

    # Binary variable telling if an oil is put in the recipe or not
    @variable(recipe, v_is_oil_present[i = s_oils_set], binary = true)
    
    # --------------------------
    # Constraints
    #---------------------------

    # Binary constraints
    @constraint(recipe, c_oil_taken_up, v_is_oil_present .>= (v_oil_amounts / soap_weight))
    @constraint(recipe, c_oil_taken_down, v_is_oil_present .<= oil_availabilities)
    
    # When a oil is taken, it should represent at least 3% of the total soap
    # This is usefull when min number of oil is >= 1, so the solveur does not put 0.0g of some oils in the mix
    #@constraint(recipe, c_oil_taken_min_amount, v_oil_amounts .>= 0.03 * soap_weight * v_is_oil_present)

    # Constraint for maximum value of oil mixing, but art least one oil
    @constraint(recipe, c_max_oils, r.target_number_of_oils.first <= sum(v_is_oil_present) <= r.target_number_of_oils.second)

    # (Amount of Fat) × (Saponification Value of the Fat) = (Amount of Lye)
    # (Amount of Lye) ÷ 0.3 = (Total Weight of Lye Water Solution)  (if lye+water solution is 30% concentrated)
    # (Total Weight of Lye Water Solution) − (Amount of Lye) = (Amount of Water)
    # Super fat is the percentage of fat we wish to not saponify 
    # So instead of using the amount of lye for the saponification 100% of the oil
    # We will compute lye for x = total_fat_weight * (1 - super_fat_percent/100.0)  grams of fat
    @constraint(recipe, c_total_lye_amount, v_lye_amounts .== (v_oil_amounts .* [naoh(oils[i]) for i = s_oils_set]) * (1.0 - super_fat_ratio))
    # Lye amounts calculation
    @constraint(recipe, c_total_water_amount, v_water_amounts .== (v_lye_amounts / lye_concentration_ratio) .- v_lye_amounts) # means water to lye ratio = 2.3333:1

    # Constraint for total weight
    @constraint(recipe, c_total_weight, sum(v_oil_amounts) + sum(v_lye_amounts) + sum(v_water_amounts) + fragrance_ratio * sum(v_oil_amounts) == soap_weight )

    function oil_quality_equation(oil, v_oil_amout, quality_key)
        # Iodine and INS are data and not calcutaled quatilies
        # Just give those quality a score
        if sv_qualities[quality_key] == :Iodine
            return v_oil_amout * oil.iodine
        end

        if sv_qualities[quality_key] == :INS
            return v_oil_amout * oil.ins
        end

        # Else
        # In the data the fatty acid content of an oil if given in % (may not add up to 100)
        # The fatty acid contribution to the quality is quality_contribution * fatty_acid_content_%
        fatty_acid_proportions = [QUALITY_MATRIX[mapping_fatty_acids[Symbol(f.first)]][quality_key] * (f.second) for f in oil.fa_composition]
        # The results here is a quality value in grams as v_oil_amout is in grams and fatty_acid_proportions in per unit
        return sum(v_oil_amout * fatty_acid_proportions)
    end

    # Let Q be set the of qualities, O of oils and F of fatty acids
    # Let C(f,q) be the matrix of fatty acids contribution to qualities for f in F, q in Q
    # Let FA(f,o) be the proportion of fatty acid f in oil o (in % with respect to other fatty acid value)
    # The value of a quality q in a oil o is
    # V(q,o) = sum(f in F, 100 * FA(f,o) * C(f,q))
    # Thus the value of a quality q in a mix of oils O is
    # V(q) = sum(o in O, 100 * P(o) * V(q,o))
    # Wiht P(0) = A(0) / sum(o in O, A(o)) the proportion (in %) of the oil o in the mix
    # A(o) begin the absolute amount of oil o in the mix
    # Thus V(q) = sum(o int O, 100 * (A(o) / sum(o in O, A(o))) * V(q,o))
    # V(q) and A(o) are the only variables here, thus is the a quadratic equation
    # V(q) = 1 / sum(o in O, A(o)) * sum(o int O, 100 * A(o) * V(q,o))
    # By scaling V(q) to its per-value system we have:
    # sum(o in O, A(o)) * V(q) = sum(o int O, 100 * A(o) * V(q,o))
    # V(q) will be in p.u at optimality
    # This is now a linear equation
    @constraint(recipe, c_qual_val[q = s_qualtities_set], 
        v_qualities[q] == sum([oil_quality_equation(oils[o], v_oil_amounts[o], q) for o = s_oils_set])
    )
    # v_qualities[q] are in p.u and bounds in absolute values
    @constraint(recipe, c_qual_lb[q = s_qualtities_set], v_qualities[q] >= qualities_lb[q] * sum(v_oil_amounts))
    @constraint(recipe, c_qual_ub[q = s_qualtities_set], v_qualities[q] <= qualities_ub[q] * sum(v_oil_amounts))


    # Absolute deviation from (scaled) target constraint
    # Δq = Δq⁺ - Δq⁻ = v - t
    # INS and Iodine does not contribute to the overall score
    for q = [mapping_qualities[qual] for qual in setdiff(sv_qualities, (:INS, :Iodine))]
        @constraint(recipe, v_Δq⁺[q] - v_Δq⁻[q] == v_qualities[q] - (qualities_target[q] * sum(v_oil_amounts)))
    end
    
    # --------------------------
    # Objective
    #---------------------------
    # Maximise INS score
    #@objective(recipe, Max, v_qualities[quality_key(quality_to_optimize)])
    # Minimize total target deviation
    @objective(recipe, Min, sum(v_Δq⁺ + v_Δq⁻))

    # Solve the problem
    try
        optimize!(recipe)
    catch e
        println("Cannot compute a recipe satisfying your quality requirements")
        return
    end

    # --------------------------
    # Results
    #---------------------------
    optimized = Recipe()
    optimized.options = r
    optimized.soap_weight = soap_weight
    optimized.oils_in_recipe = [i for i = s_oils_set if value(v_is_oil_present[i]) == 1.0]
    optimized.oil_amounts = value.(v_is_oil_present .* v_oil_amounts)
    optimized.oil_amount = sum(optimized.oil_amounts)
    optimized.lye_amount = sum(value.(v_lye_amounts))
    optimized.water_amount = sum(value.(v_water_amounts))
    optimized.oils_prices = [optimized.options.oils[i].price * optimized.oil_amounts[i] / 1000.0 for i = optimized.oils_in_recipe]
    # Rescaling
    optimized.qualities ← value.(v_qualities) / optimized.oil_amount
    optimized.soap_price = sum(optimized.oils_prices) / (optimized.soap_weight / 1000.0) 

    return optimized
end
