function print_ingredient(name, value, unit = "", tab_lvl = 1)
    tab = ""
    if tab_lvl > 0
        tab = join(["" for i = 0:tab_lvl], "\t")
    end
    println(tab, name, " = ", round(value, digits = 2), unit)
end

# TODO: Macro 'round'
function print_recipe(r::Recipe)
    oil_names = r.oils[r.oil_uids, :name]
    nb_oils = length(r.oil_amounts)
    recommended = recommended_qualities()
    soap_price = sum(r.oils[r.oil_uids, :price] .* (r.oil_amounts ./ 1000))

    println("Soap composition : ")
    println("\t", "Oils ($(nb_oils)) : ")
    [print_ingredient(oil_names[i], r.oil_amounts[i], "g", 2) for i in 1:nb_oils]
    print_ingredient("Total", sum(r.oil_amounts), "g", 2)
    print_ingredient("Water", r.water_amount, "g")
    print_ingredient("Lye", r.lye_amount, "g")
    print_ingredient("Fragrance", r.frangrance_amount, "g")
    print_ingredient("Super Fat", r.options.super_fat_percent, "%")
    print_ingredient("Total", r.soap_weight, "g")
    println("Soap quality (Recommended) : ")
    for q in fieldnames(Qualities)
        quality_val = getfield(r.qualities, q)
        recommended_min = first(getfield(recommended, q))
        recommended_max = last(getfield(recommended, q))
        warning = ""
        if (quality_val > recommended_max) || (quality_val < recommended_min)
            warning = "*"
        end
        println("\t", q, " = ", Int64(round(quality_val)), " (", Int64(recommended_min), ", ", Int64(recommended_max) ,")", warning)
    end
    println("Total estimated cost of the soap = $(Int64(round(soap_price)))€/Kg")
end

Base.show(io::IO, r::Recipe) = print_recipe(r)