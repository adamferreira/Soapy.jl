using Soapy



# Make a soap with most commun oils
opt = Soapy.RecipeOptions("oils_aromazone.json")
# Make a 1kg soap
opt.target_weight = 300.0
# Use recommended qualities for a balanced soap
#opt.target_qualities = Soapy.recommended_qualities()
# Maximise the INS (overall) score of the soap
opt.super_fat_percent = 5.0
opt.lye_concentration_percent = 30.0
opt.fragrance_percent = 0.0
@time recipe = Soapy.find_recipe(opt)
println(recipe)
Soapy.plot_recipe(recipe)