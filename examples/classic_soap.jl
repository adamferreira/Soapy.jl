using Soapy

dataset = "oils_aromazone.json"
# Make a soap with most commun oils
opt = default_options(dataset)
# Make a 1kg soap
opt.target_weight = 1000.0
# Use recommended qualities for a balanced soap 
#opt.target_qualities = Soapy.recommended_qualities()
# Maximise the INS (overall) score of the soap
opt.super_fat_percent = 10.0
opt.lye_concentration_percent = 33.0
opt.fragrance_percent = 0.0
@time recipe = find_recipe(opt)
println(recipe)
println("Best possible Soapy score for this dataset = $(Int64(round(best_score(dataset))))")
#display(plot_recipe(recipe))