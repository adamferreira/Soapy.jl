using JuMP, GLPK

include("oils.jl")

mutable struct RecipeCalculator
    oils::Vector{Oil}
    target_weight::Float64 # in gram
    target_qualities::Dict{String, Pair{Float64, Float64}}
    max_oils::Int64
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

    sap_naoh_values = [o.sap_naoh for o in r.oils]
    soap_weight = r.target_weight

    println("Mixing up to $(r.max_oils) oils together out of $(length(r.oils))")
    println("Will keep soap mass at $(soap_weight)g ")

    # Real variables representing masses used in the recipe
    @variable(recipe, oil_amounts[i=1:length(r.oils)] >= 0.0) # in per unit
    @variable(recipe, lye_amounts[i=1:length(r.oils)] >= 0.0) # in grams
    @variable(recipe, water_amounts[i=1:length(r.oils)] >= 0.0) # in grams

    # Real variables representing quality values
    @variable(recipe, qual[i=1:length(r.target_qualities)])
    cpt = 1
    for q in r.target_qualities
        set_lower_bound(qual[cpt], q.second.first)
        set_upper_bound(qual[cpt], q.second.second)
        cpt += 1
    end

    # Ratios and compositions
    #@variable(recipe, r.water_to_oil_ratio.first <= water_to_oil_ratio <= r.water_to_oil_ratio.second)
    #@variable(recipe, r.super_fat.first <= super_fat <= r.super_fat.second)
    #@variable(recipe, r.fragrance_weight.first <= fragrance_weight <= r.fragrance_weight.second)
    fragrance_ratio = r.fragrance.first
    #water_to_oil_ratio = r.water_to_oil_ratio.first
    super_fat = r.super_fat.first # TODO

    # Binary variable telling if an oil is put in the recipe
    @variable(recipe, is_oil_present[i=1:length(r.oils)], binary = true)

    # Binary constraints
    @constraint(recipe, oil_taken, is_oil_present .>= oil_amounts)

    # Constraint for maximum value of oil mixing, but art least one oil
    @constraint(recipe, max_oils, 1.0 <= sum(is_oil_present) <= r.max_oils)

    # (Amount of Fat) × (Saponification Value of the Fat) = (Amount of Lye)
    # (Amount of Lye) ÷ 0.3 = (Total Weight of Lye Water Solution)
    # (Total Weight of Lye Water Solution) − (Amount of Lye) = (Amount of Water)
    @constraint(recipe, lye_amount, lye_amounts .== (oil_amounts * soap_weight) .* sap_naoh_values)
    # Lye concentration if assumed to be 30%
    @constraint(recipe, water_amount, water_amounts .== (lye_amounts / 0.3) .- lye_amounts) # means water to lye ratio = 2.3333:1

    # Constraint for total weight
    @constraint(recipe, total_weight, (sum(oil_amounts) * soap_weight) + sum(lye_amounts) + sum(water_amounts) + fragrance_ratio * (sum(oil_amounts) * soap_weight) == soap_weight )

    # Quality constraints
    quality_constraints = Dict()
    # Quality value of a given quality for of a given oil (in per unit)
    function oil_quality_equation(oil, oil_proportion, quality)
        return oil_proportion * sum([quality_contribution(f.first, quality) * (f.second * 0.01) for f in oil.fa_composition])
    end
    
    for q in qualities()
        quality_constraints[q] = @constraint(recipe, r.target_qualities[q].first <= 100.0 * sum([oil_quality_equation(r.oils[i], oil_amounts[i], q) for i = 1:length(r.oils)]) <= r.target_qualities[q].second)
    end

    # Minimizing the number of oil mixed
    @objective(recipe, Max, sum(is_oil_present))
    optimize!(recipe)
    oils_in_recipe = Vector{Int64}()
    for i = 1:length(r.oils)
        if value(is_oil_present[i]) == 1.0
            push!(oils_in_recipe, i)
        end
    end

    println("Soap composition : ")
    println("\t", "Oils : ")
    for i in oils_in_recipe
        print_ingredient(r.oils[i].name, value(oil_amounts[i]) * soap_weight, "g", 2)
    end
    print_ingredient("Total", sum([value(oil_amounts[i]) * soap_weight for i in oils_in_recipe]), "g", 2)

    print_ingredient("Water", sum([value(water_amounts[i]) for i = 1:length(r.oils)]), "g")
    print_ingredient("Lye", sum([value(lye_amounts[i]) for i = 1:length(r.oils)]), "g")
    print_ingredient("Fragrance", fragrance_ratio * soap_weight * sum([value(oil_amounts[i]) for i = 1:length(r.oils)]), "g")
    print_ingredient("Total", soap_weight, "g")

    println("Soap quality : ")
    for q in qualities()
        print_ingredient(q, value(quality_constraints[q]))
    end
end