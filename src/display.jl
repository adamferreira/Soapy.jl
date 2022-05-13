
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
    [print_ingredient(r.options.oils[i].name, optimized.oil_amounts[i], "g", 2) for i = r.oils_in_recipe]
    print_ingredient("Total", r.oil_amount, "g", 2)
    print_ingredient("Water", r.amount, "g")
    print_ingredient("Lye", r.lye_amount, "g")
end