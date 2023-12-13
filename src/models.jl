using JuMP, GLPK

mutable struct RecipeOptions
    # in gram
    target_weight::Float64
    # Quality value restriction windows
    quality_restriction::Qualities{Range{Float64}}
    # Min and Max number of different oils to use in the mix
    target_number_of_oils::Range{Int64}
    # Lye percent of water + lye solution
    lye_concentration_percent::Float64
    # In percent of total fat
    super_fat_percent::Float64
    # Ratio total fat (usally 3-4% of total fat weight)
    fragrance_percent::Float64
    # Price range of the Soap (in €/Kg)
    price_range::Range{Float64}
end

function default_options()::RecipeOptions
    return RecipeOptions(
        # target_weight
        1000,
        # target_qualities,
        recommended_qualities(),
        # target_number_of_oils,
        1..1000,
        # lye_concentration_percent
        33.0,
        # super_fat_percent,
        5.0,
        # fragrance_percent
        4.0,
        # price_range
        0.0..100.0
    )
end


struct Recipe 
    # Dataset used to create this recipe
    oils::DataFrame
    # Options used to create this recipe
    options::RecipeOptions
    # All weight and amounts are in grams
    soap_weight::Float64
    # Uids on oils in the mix
    oil_uids::Vector{Int64}
    # Amount (in g) of oil i in the mix
    oil_amounts::Vector{Float64}
    water_amount::Float64
    lye_amount::Float64
    frangrance_amount::Float64
    qualities::Qualities{Float64}
end


# The penalty score of the soap is the total absolute deviation divided by the maximum possible deviation from recommended quality values
# Scaled down to a score out of 100
function score(r::Recipe)::Float64
    # Qualities that are taken into account for the score
    quals = setdiff(qualities(), (:INS, :Iodine))
    recommended = recommended_qualities()
    # Minimal ideal targets
    lowerbounds = [first(getfield(recommended, q)) for q in quals]
    # Ideal targets
    targets = [midpoint(getfield(recommended, q)) for q in quals]
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


function solve(
    oils::TabularData{Oil},
    options::RecipeOptions;
)::Recipe
    recipe = Model(GLPK.Optimizer)
    oils_df_raw = to_df(oils)
    oils_df::DataFrame = sort(
        filter(row -> row.available, oils_df_raw),
        :uid, rev=true
    )

    # --------------------------
    # Sets (values)
    #---------------------------
    # Index to Symbol   
    sv_qualities = qualities()
    sv_fatty_acids = fattyacids()

    # --------------------------
    # Sets (indexes)
    #---------------------------   
    s_oils_set = 1:size(oils_df)[1]
    s_qualtities_set = 1:length(sv_qualities)
    s_fatty_acids_set = 1:length(sv_fatty_acids)

    # --------------------------
    # Constants
    #---------------------------   
    soap_weight = options.target_weight
    min_price = options.price_range.first
    max_price = options.price_range.second
    fragrance_ratio = options.fragrance_percent / 100.0
    super_fat_ratio = options.super_fat_percent / 100.0
    lye_concentration_ratio = options.lye_concentration_percent / 100.0
    qualities_lb = [getfield(options.quality_restriction, sv_qualities[i]).first for i in s_qualtities_set]
    qualities_ub = [getfield(options.quality_restriction, sv_qualities[i]).second for i in s_qualtities_set]
    # Matrix fa_composition[i,j]
    # Proportion of fatty acid j in oil i
    fa_composition = zeros(size(oils_df)[1], length(sv_fatty_acids))
    for i in s_oils_set
        for j in s_fatty_acids_set
            fa_composition[i,j] = oils_df[i, :fa_composition][sv_fatty_acids[j]]
        end
    end
    # Quality Matrix
    # Contribution of fatty acids j in quality i
    quality_matrix = zeros(length(sv_qualities), length(sv_fatty_acids))
    for i in s_qualtities_set
        for j in s_fatty_acids_set
            quality_matrix[i,j] = QUALITY_MATRIX[sv_fatty_acids[j]][sv_qualities[i]]
        end
    end
    # The targeted value of a quality is the midpoint of its recommended range
    qualities_target = [midpoint(getfield(options.quality_restriction, q)) for q in sv_qualities]

    # --------------------------
    # Variables
    #---------------------------
    # Real variables representing masses used in the recipe
    @variable(recipe, v_oil_amounts[i = s_oils_set] >= 0.0) # in grams
    @variable(recipe, v_lye_amounts[i = s_oils_set] >= 0.0) # in grams
    @variable(recipe, v_water_amounts[i = s_oils_set] >= 0.0) # in grams
    # Real variables representing quality values of the recipe
    @variable(recipe, v_qualities[i = s_qualtities_set] >= 0.0)
    # Binary variable telling if an oil is put in the recipe or not
    @variable(recipe, v_is_oil_present[i = s_oils_set], binary = true)
    # Variable representing absolute deviation of a quality value from its recommended target
    # Δq = Δq⁺ - Δq⁻
    @variable(recipe, v_Δq⁺[i = s_qualtities_set] >= 0.0)
    @variable(recipe, v_Δq⁻[i = s_qualtities_set] >= 0.0)

    # --------------------------
    # Constraints
    #---------------------------
    # Binary constraints
    @constraint(recipe, c_oil_taken_up, v_is_oil_present .>= (v_oil_amounts / soap_weight))

    # When a oil is taken, it should represent at least x% of the total soap
    # This is usefull when min number of oil is >= 1, so the solveur does not put 0.0g of some oils in the mix
    @constraint(recipe, c_oil_taken_min_amount, v_oil_amounts .>= 0.1 .* soap_weight .* v_is_oil_present)

    # Number of different oils in the mix is within range
    @constraint(recipe, c_max_oils, options.target_number_of_oils.first <= sum(v_is_oil_present) <= options.target_number_of_oils.second)

    # (Amount of Fat) × (Saponification Value of the Fat) = (Amount of Lye)
    # (Amount of Lye) ÷ 0.3 = (Total Weight of Lye Water Solution)  (if lye+water solution is 30% concentrated)
    # (Total Weight of Lye Water Solution) − (Amount of Lye) = (Amount of Water)
    # Super fat is the percentage of fat we wish to not saponify 
    # So instead of using the amount of lye for the saponification 100% of the oil
    # We will compute lye for x = total_fat_weight * (1 - super_fat_percent/100.0)  grams of fat
    @constraint(recipe, c_total_lye_amount[i = s_oils_set], v_lye_amounts .== v_oil_amounts .* oils_df[!, :sap_naoh] .* (1.0 - super_fat_ratio))
    # Lye amounts calculation
    @constraint(recipe, c_total_water_amount, v_water_amounts .== (v_lye_amounts / lye_concentration_ratio) .- v_lye_amounts) # means water to lye ratio = 2.3333:1
    # Constraint for total weight
    @constraint(recipe, c_total_weight, sum(v_oil_amounts) + sum(v_lye_amounts) + sum(v_water_amounts) + (fragrance_ratio * sum(v_oil_amounts)) == soap_weight)
    # Constraint for price range
    soap_price = sum((v_oil_amounts / 1000.0) .* oils_df[!, :price])
    @constraint(recipe, c_price_range, min_price <= soap_price <= max_price)

    function oil_quality_equation(oil_key, v_oil_amout, quality_key)
        # Iodine and INS are data and not calcutaled quatilies
        # Just give those quality a score
        if sv_qualities[quality_key] == :Iodine
            return v_oil_amout * oils_df[oil_key, :iodine]
        end

        if sv_qualities[quality_key] == :INS
            return v_oil_amout * oils_df[oil_key, :ins]
        end

        # Else
        # In the data the fatty acid content of an oil if given in % (may not add up to 100)
        # The fatty acid contribution to the quality is quality_contribution * fatty_acid_content_%

        # The results here is a quality value in grams as v_oil_amout is in grams and fatty_acid_proportions in per unit
        return sum(v_oil_amout * (quality_matrix[quality_key,:] .* fa_composition[oil_key,:]))
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
        v_qualities[q] == sum([oil_quality_equation(o, v_oil_amounts[o], q) for o = s_oils_set])
    )
    # v_qualities[q] are in p.u and bounds in absolute values
    @constraint(recipe, c_qual_lb[q = s_qualtities_set], v_qualities[q] >= qualities_lb[q] * sum(v_oil_amounts))
    @constraint(recipe, c_qual_ub[q = s_qualtities_set], v_qualities[q] <= qualities_ub[q] * sum(v_oil_amounts))

    # Absolute deviation from (scaled) target constraint
    # Δq = Δq⁺ - Δq⁻ = v - t
    # INS and Iodine does not contribute to the overall score
    @constraint(recipe, c_qual_dev[q = s_qualtities_set], v_Δq⁺[q] - v_Δq⁻[q] == v_qualities[q] - (qualities_target[q] * sum(v_oil_amounts)))
    

    # --------------------------
    # Objective
    #---------------------------
    # Minimize total target deviation
    @objective(recipe, Min, sum(v_Δq⁺ + v_Δq⁻))
    # Minimize price
    #@objective(recipe, Min, soap_price)

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
    oil_amounts = [v for v in value.(v_is_oil_present .* v_oil_amounts) if v != 0.0]
    oil_uids = [oils_df[i, :uid] for i in s_oils_set if value(v_is_oil_present[i]) == 1.0]
    water_amount = sum(value.(v_water_amounts))
    lye_amount = sum(value.(v_lye_amounts))
    frangrance_amount = options.fragrance_percent * 0.01 * sum(oil_amounts)
    return Recipe(
        oils_df_raw,
        options,
        soap_weight,
        oil_uids,
        oil_amounts,
        water_amount,
        lye_amount,
        frangrance_amount,
        # qualities
        Qualities{Float64}((value.(v_qualities) / sum(oil_amounts))...)
    )
end
