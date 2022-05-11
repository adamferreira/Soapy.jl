using JuMP, GLPK
# using Ipopt

include("oils.jl")

mutable struct RecipeCalculator
    oils::Vector{Oil}
    target_weight::Float64 # in gram
    target_qualities::Dict{String, Pair{Float64, Float64}}
    target_number_of_oils::Pair{Int64, Int64}
    lye_concentration_percent::Float64 # Lye percent of water + lye solution
    super_fat_percent::Float64 # In percent of total fat
    fragrance_percent::Float64 # Ratio total fat (usally 3-4% of total fat weight)

    function RecipeCalculator(oil_database::String)
        oils = load_oils(oil_database) 
        return new(
                oils,
                1000.0,
                Dict((q => (0.0 => 1000.0) for q in qualities())),
                1 => length(oils),
                30.0,
                5.0,
                4.0
            )
    end
end

function soap_weight!(r::RecipeCalculator, min::Float64, max::Float64)
    r.target_weight = min => max
end

function print_ingredient(name, value, unit = "", tab_lvl = 1)
    tab = ""
    if tab_lvl > 0
        tab = join(["" for i = 0:tab_lvl], "\t")
    end
    println(tab, name, " = ", round(value, digits = 2), unit)
end

function maximise_quality(r::RecipeCalculator, quality::String)
    return simulate(r, quality)
end

function simulate(r::RecipeCalculator, quality_to_optimize::String = "INS")
    recipe = Model(GLPK.Optimizer)


    println("Mixing $(r.target_number_of_oils.first) to $(r.target_number_of_oils.second) oils together out of $(length(r.oils))")
    println("Will keep soap mass at $(r.target_weight)g ")
    # --------------------------
    # Sets
    #---------------------------   
    s_oils_set = 1:length(r.oils)
    s_qualtities_set = 1:length(QUALITIES)
    s_fatty_acids_set = 1:length(FATTY_ACIDS)


    # --------------------------
    # Constants
    #---------------------------   
    soap_weight = r.target_weight
    fragrance_ratio = r.fragrance_percent / 100.0
    super_fat_ratio = r.super_fat_percent / 100.0
    lye_concentration_ratio = r.lye_concentration_percent / 100.0
    qualities_lb = [r.target_qualities[q].first for q in qualities()]
    qualities_ub = [r.target_qualities[q].second for q in qualities()]
    # the targeted value of a quality is the midpoint of its recommended range
    recommended_q = recommended_qualities()
    qualities_target = [0.5 * (recommended_q[q].first + recommended_q[q].second) for q in qualities()]

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
    @constraint(recipe, c_oil_taken, v_is_oil_present .>= v_oil_amounts / soap_weight)
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
    @constraint(recipe, c_total_lye_amount, v_lye_amounts .== (v_oil_amounts .* [naoh(r.oils[i]) for i = s_oils_set]) * (1.0 - super_fat_ratio))
    # Lye amounts calculation
    @constraint(recipe, c_total_water_amount, v_water_amounts .== (v_lye_amounts / lye_concentration_ratio) .- v_lye_amounts) # means water to lye ratio = 2.3333:1

    # Constraint for total weight
    @constraint(recipe, c_total_weight, sum(v_oil_amounts) + sum(v_lye_amounts) + sum(v_water_amounts) + fragrance_ratio * sum(v_oil_amounts) == soap_weight )

    # Quality constraints
    c_qualities = Vector()
    function oil_quality_equation(oil, v_oil_amout, quality_key)
        # Iodine and INS are data and not calcutaled quatilies
        # Just give those quality a score
        if quality_key == Int64(Iodine::Quality)
            return v_oil_amout * oil.iodine
        end

        if quality_key == Int64(INS::Quality)
            return v_oil_amout * oil.ins
        end

        # Else
        # In the data the fatty acid content of an oil if given in % (may not add up to 100)
        # The fatty acid contribution to the quality is quality_contribution * fatty_acid_content_%
        fatty_acid_proportions = [ QUALITY_MATRIX[FATTY_ACIDS[f.first]][quality_key] * (f.second) for f in oil.fa_composition]
        # The results here is a quality value in grams as v_oil_amout is in grams and fatty_acid_proportions in per unit
        return sum(v_oil_amout * fatty_acid_proportions)
    end

    for q = s_qualtities_set
        quality_value_expr = sum([oil_quality_equation(r.oils[o], v_oil_amounts[o], q) for o = s_oils_set]) # in grams
        # The quality score of an oil mix is computed as follow
        # quality_content_of_the_mix (in grams) / total_amount_of_oils (in grams)
        # So whe sould satisfy :
        # min_q_target <= q_amout / fat_amount <= max_q_target
        # min_q_target * fat_amount <= q_amout <= max_q_target * fat_amount
        push!(c_qualities, @constraint(recipe, v_qualities[q] == quality_value_expr))
        @constraint(recipe, v_qualities[q] >= qualities_lb[q] * sum(v_oil_amounts))
        @constraint(recipe, v_qualities[q] <= qualities_ub[q] * sum(v_oil_amounts))
    end
    # Absolute deviation from (scaled) target constraint
    # Δq = Δq⁺ - Δq⁻ = v - t
    # INS and Iodine does not contribute to the overall score
    for q = setdiff(s_qualtities_set, [Int64(Iodine::Quality), Int64(INS::Quality)])
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

    # Retrive solution
    r_oils_in_recipe = [i for i = s_oils_set if value(v_is_oil_present[i]) == 1.0]
    # oils amount in the soap in grams
    r_oil_amounts = value.(v_is_oil_present .* v_oil_amounts)
    r_total_oil_amount = sum(r_oil_amounts)
    r_total_water_amount = sum(value.(v_water_amounts))
    r_total_lye_amount = sum(value.(v_lye_amounts))
    # Scale down oil amount from g to kg
    r_total_oils_price = sum([r.oils[i].price * r_oil_amounts[i] / 1000.0 for i = r_oils_in_recipe])
    # Qualities value scaled down to their true values
    r_qualities_value = value.(v_qualities) / r_total_oil_amount


    # Display found recipe
    println("Soap composition : ")
    println("\t", "Oils (", length(r_oils_in_recipe) ,") : ")
    [print_ingredient(r.oils[i].name, value(v_oil_amounts[i]), "g", 2) for i = r_oils_in_recipe]
    print_ingredient("Total", r_total_oil_amount, "g", 2)
    print_ingredient("Water", r_total_water_amount, "g")
    print_ingredient("Lye", r_total_lye_amount, "g")
    # fragrance_g = fragrance_ratio * sum(value.(v_oil_amounts))
    # fragrance_g_per_kg = fragrance_g * (1.0 / sum(value.(v_oil_amounts) / soap_weight), digits = 2) 
    # fragrance_g_per_kg = (fragrance_ratio * sum(value.(v_oil_amounts))) * (soap_weight / sum(value.(v_oil_amounts)))
    # fragrance_g_per_kg = fragrance_ratio * soap_weight
    print_ingredient("Fragrance", fragrance_ratio * r_total_oil_amount, "g")
    print_ingredient("Total", soap_weight, "g")

    println("Soap quality (Recommended) : ")
    for q in qualities()
        quality_val = Int64(floor(r_qualities_value[quality_key(q)]))
        recommended_val = recommended_qualities()[q]
        recommended_min = Int64(recommended_val.first)
        recommended_max = Int64(recommended_val.second)
        warning = ""
        if (quality_val > recommended_max) || (quality_val < recommended_min)
            warning = "*"
        end
        println("\t", q, " = ", quality_val, " (", recommended_min, ", ", recommended_max ,")", warning)
    end
    print_ingredient("Super Fat", 100.0 * super_fat_ratio, "%")
    println("Total estimated cost of the soap = $(Int64(round(r_total_oils_price / (soap_weight / 1000.0))))€/Kg")

    # The penalty score of the soap is the total absolute deviation divided by the maximum possible deviation from target
    # Scaled down to a score out of 100
    recommended_qualities_values = recommended_qualities()
    qualities_target = [0.5 * (recommended_q[q].first + recommended_q[q].second) for q in qualities()]
    recommended_qualities_lb = [recommended_q[q].second for q in qualities()]
    recommended_qualities_ub = [recommended_q[q].second for q in qualities()]
    __total_deviatation = 0.0
    __max_deviation = 0.0
    # Total deviation is \sum abs(q-m)
    # Max deviation is max(l-m,u-m) for each quality (not INS and iodine)
    for q = setdiff(s_qualtities_set, [Int64(Iodine::Quality), Int64(INS::Quality)])
        __total_deviatation += abs(r_qualities_value[q] - qualities_target[q])
        __max_deviation += max(qualities_target[q] - recommended_qualities_lb[q], recommended_qualities_ub[q] - qualities_target[q])
    end
    # Scale the score out of 100 points
    println("Saopy score =  $(Int64(round(100 - 100 * (__total_deviatation / __max_deviation))))/100")
end
