using JuMP, GLPK
# using Ipopt

include("oils.jl")

mutable struct RecipeCalculator
    oils::Vector{Oil}
    target_weight::Float64 # in gram
    target_qualities::Dict{String, Pair{Float64, Float64}}
    c_max_oils::Int64
    water_to_oil_ratio::Pair{Float64, Float64} # In percent of mass (quadratic if variable)
    super_fat::Pair{Float64, Float64} # In ratio of total fat
    fragrance::Pair{Float64, Float64} # Ratio total fat (usally 3-4% of total fat weight)

    function RecipeCalculator()
        oils = load_oils() 
        return new(
                oils,
                1000.0,
                #0.0 => typemax(Float64),
                Dict((q => (0.0 => 100.0) for q in qualities())),
                length(oils),
                (0.3 => 0.3),
                (0.05 => 0.05),
                (0.04 => 0.04)
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

function simulate(r::RecipeCalculator)
    recipe = Model(GLPK.Optimizer)

    soap_weight = r.target_weight
    fragrance_ratio = r.fragrance.first
    super_fat = r.super_fat.first # TODO
    qualities_lb = [q.second.first for q in r.target_qualities]
    qualities_ub = [q.second.second for q in r.target_qualities]

    println("Mixing up to $(r.c_max_oils) oils together out of $(length(r.oils))")
    println("Will keep soap mass at $(soap_weight)g ")

    # --------------------------
    # Sets
    #---------------------------   
    s_oils_set = 1:length(r.oils)
    s_qualtities_set = 1:length(QUALITIES)
    s_fatty_acids_set = 1:length(FATTY_ACIDS)

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
    
    # --------------------------
    # Constraints
    #---------------------------

    # Binary constraints
    @constraint(recipe, c_oil_taken, v_is_oil_present .>= v_oil_amounts / soap_weight)

    # Constraint for maximum value of oil mixing, but art least one oil
    @constraint(recipe, c_max_oils, 1.0 <= sum(v_is_oil_present) <= r.c_max_oils)

    # (Amount of Fat) × (Saponification Value of the Fat) = (Amount of Lye)
    # (Amount of Lye) ÷ 0.3 = (Total Weight of Lye Water Solution)
    # (Total Weight of Lye Water Solution) − (Amount of Lye) = (Amount of Water)
    @constraint(recipe, c_total_lye_amount, v_lye_amounts .== v_oil_amounts .* [o.sap_naoh for o in r.oils])
    # Lye concentration if assumed to be 30%
    @constraint(recipe, c_total_water_amount, v_water_amounts .== (v_lye_amounts / 0.3) .- v_lye_amounts) # means water to lye ratio = 2.3333:1

    # Constraint for total weight
    @constraint(recipe, c_total_weight, sum(v_oil_amounts) + sum(v_lye_amounts) + sum(v_water_amounts) + fragrance_ratio * sum(v_oil_amounts) == soap_weight )

    # Quality constraints
    c_qualities = Vector()
    function oil_quality_equation(oil, v_oil_amout, quality_key)
        # Iodine and INS are data and not calcutaled quatilies
        if quality_key == Int64(Iodine::Quality)
            return v_oil_amout * oil.iodine * 0.01
        end

        if quality_key == Int64(INS::Quality)
            return v_oil_amout * oil.ins * 0.01
        end

        # Else
        # In the data the fatty acid content of an oil if given in % (may not add up to 100)
        # The fatty acid contribution to the quality is (true|false) * fatty_acid_content_%
        fatty_acid_proportions = [ QUALITY_MATRIX[FATTY_ACIDS[f.first]][quality_key] * (f.second * 0.01) for f in oil.fa_composition]
        # The results here is a quality value in grams as v_oil_amout is in grams and fatty_acid_proportions in per unit
        return sum(v_oil_amout * fatty_acid_proportions)
    end

    for q = s_qualtities_set
        quality_value_expr = sum([oil_quality_equation(r.oils[o], v_oil_amounts[o], q) for o = s_oils_set]) # in grams
        # The quality score of an oil mix is computed as follow
        # quality_content_of_the_mix (in grams) / total_amount_of_oils (in grams
        # So whe sould satisfy :
        # min_q_target <= q_amout / fat_amount <= max_q_target
        # min_q_target * fat_amount <= q_amout <= max_q_target * fat_amount
        push!(c_qualities, @constraint(recipe, v_qualities[q] == quality_value_expr))
        @constraint(recipe,  v_qualities[q] >= qualities_lb[q] * sum(v_oil_amounts))
        @constraint(recipe,  v_qualities[q] <= qualities_ub[q] * sum(v_oil_amounts))
    end


    # --------------------------
    # Objective
    #---------------------------
    # Maximise INS score
    @objective(recipe, Max, v_qualities[Int64(INS::Quality)])

    # Solve the problem
    optimize!(recipe)

    # Retrive solution
    oils_in_recipe = Vector{Int64}()
    for i = 1:length(r.oils)
        if value(v_is_oil_present[i]) == 1.0
            push!(oils_in_recipe, i)
        end
    end

    # Display found recipe
    println("Soap composition : ")
    println("\t", "Oils : ")
    for i in oils_in_recipe
        print_ingredient(r.oils[i].name, value(v_oil_amounts[i]), "g", 2)
    end
    print_ingredient("Total", sum(value.(v_oil_amounts)), "g", 2)

    print_ingredient("Water", sum(value.(v_water_amounts)), "g")
    print_ingredient("Lye", sum(value.(v_lye_amounts)), "g")
    print_ingredient("Fragrance", fragrance_ratio * sum(value.(v_oil_amounts)), "g")
    print_ingredient("Total", soap_weight, "g")

    println("Soap quality : ")
    for q in qualities()
        print_ingredient(q, 100.0 * value(v_qualities[quality_key(q)] / sum(value.(v_oil_amounts))))
    end
end