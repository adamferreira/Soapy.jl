using PlotlyJS

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

function plot_recipe(r::Recipe)

    function roundint(x)
        return Int64(round(x))
    end

    function summary_to_table()
        total = round(r.options.target_weight, digits = 2)
        oil = round(r.oil_amount, digits = 2)
        water = round(r.water_amount, digits = 2)
        lye = round(r.lye_amount, digits = 2)
        fragrance = round(frangrance_amount(r), digits = 2)
        return PlotlyJS.table(
            header_values=["Total", "$(total)g"],
            cells_values=[
                ["Oil", "Water", "Lye", "Fragrance"],
                [
                    "$(oil)g", "$(water)g", "$(lye)g", "$(fragrance)g"
                ]
            ],
            #domain = attr(row = 1, column = 0),
            domain = attr(x = [0.0, 0.45], y = [0.6 ,0.85])
        )
    end

    function composition_to_chart()
        return PlotlyJS.pie(
            values = [round(r.oil_amounts[i], digits = 2) for i = r.oils_in_recipe], 
            labels = [r.options.oils[i].name for i = r.oils_in_recipe],
            texttemplate = "%{value:.2f}g <br>(%{percent})",
            textposition="inside",
            domain = attr(x = [0.05 ,0.45], y = [0.0, 0.5])
        )
    end

    function score_to_gauge(coord_x, coord_y)
        color = "green"
        if roundint(score(r)) >= 70 
            color = "green" 
        else
            color = "orange"
        end
        if roundint(score(r)) < 30 color = "red" end

        return indicator(
            mode = "gauge+number",
            title_text = "Soapy Score",
            value = roundint(score(r)),
            domain = attr(row = coord_x, column = coord_y),
            gauge=attr(
                bar_color = color,
                axis_range = [0, 100],
            )
        )
    end

    function quality_to_gauge(quality::String, coord_x, coord_y)
        qkey = quality_key(quality)
        max_val = max(r.recommended_qualities_max[qkey], 100)#, r.options.target_qualities[quality].second)
        color = "green"

        if (roundint(r.qualities[qkey]) < roundint(r.recommended_qualities_min[qkey])) || (roundint(r.qualities[qkey]) > roundint(r.recommended_qualities_max[qkey]))
            color = "orange"
        end

        return indicator(
            mode = "number+gauge",
            domain = attr(row = coord_x, column = coord_y),
            #domain = attr(x = coord_x, y = coord_y),
            value = roundint(r.qualities[qkey]),
            title_text = "<b>$(quality)</b>",
            gauge=attr(
                shape="bullet",
                bar_color = color,
                axis_range=[nothing, max_val],
                threshold=attr(
                    line=attr(color="red", width=2),
                    thickness=0.75,
                    value = roundint(r.recommended_qualities_target[qkey])
                ),
                steps=[
                    attr(range=[0, roundint(r.recommended_qualities_min[qkey])], color="lightgray"),
                    attr(range=[roundint(r.recommended_qualities_min[qkey]), roundint(r.recommended_qualities_max[qkey])], color="gray"),
                    attr(range=[roundint(r.recommended_qualities_max[qkey]), max_val], color="lightgray")
                ]
            )
        )
    end

    qualities_layout = Layout(
        grid=attr(rows=length(QUALITIES), columns=2, pattern="independent"),# showlegend=false
        legend=attr(x=0.1, y=0.6)
    )

    qualities_gauges = [ quality_to_gauge(qualities()[i], i - 1, 1) for i = 1:length(QUALITIES)]

    return PlotlyJS.plot(vcat(qualities_gauges, [score_to_gauge(0, 0), summary_to_table(), composition_to_chart()]), qualities_layout)
end

Base.show(io::IO, r::Recipe) = print_recipe(r)