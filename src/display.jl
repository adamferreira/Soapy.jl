
include("recipes.jl")

function print_ingredient(name, value, unit = "", tab_lvl = 1)
    tab = ""
    if tab_lvl > 0
        tab = join(["" for i = 0:tab_lvl], "\t")
    end
    println(tab, name, " = ", round(value, digits = 2), unit)
end


function print_recipe(r::Recipe)
    println("Soap composition : ")
    println("\t", "Oils (", length(r.oils_in_recipe) ,") : ")
    [print_ingredient(r.options.oils[i].name, r.oil_amounts[i], "g", 2) for i = r.oils_in_recipe]
    print_ingredient("Total", r.oil_amount, "g", 2)
    print_ingredient("Water", r.water_amount, "g")
    print_ingredient("Lye", r.lye_amount, "g")
    # fragrance_g = fragrance_ratio * sum(value.(v_oil_amounts))
    # fragrance_g_per_kg = fragrance_g * (1.0 / sum(value.(v_oil_amounts) / soap_weight), digits = 2) 
    # fragrance_g_per_kg = (fragrance_ratio * sum(value.(v_oil_amounts))) * (soap_weight / sum(value.(v_oil_amounts)))
    # fragrance_g_per_kg = fragrance_ratio * soap_weight
    print_ingredient("Fragrance", frangrance_amount(r), "g")
    print_ingredient("Super Fat", r.options.super_fat_percent, "%")
    print_ingredient("Total", r.soap_weight, "g")
    println("Soap quality (Recommended) : ")
    for q in qualities()
        q_key = quality_key(q)
        quality_val = r.qualities[q_key]
        recommended_min = r.recommended_qualities_min[q_key]
        recommended_max = r.recommended_qualities_max[q_key]
        warning = ""
        if (quality_val > recommended_max) || (quality_val < recommended_min)
            warning = "*"
        end
        println("\t", q, " = ", Int64(round(quality_val)), " (", Int64(recommended_min), ", ", Int64(recommended_max) ,")", warning)
    end
    println("Total estimated cost of the soap = $(Int64(round(r.soap_price)))€/Kg")
    println("Saopy score =  $(Int64(round(score(r))))/100")
end

Base.show(io::IO, r::Recipe) = print_recipe(r)