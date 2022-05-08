using Soapy

# Make a soap with most commun oils
recipe = Soapy.RecipeCalculator("oils_basic.json")
# Make a 1kg soap
recipe.target_weight = 750.0
# Use recommended qualities for a balanced soap
recipe.target_qualities = Soapy.recommended_qualities()
# Maximise the INS (overall) score of the soap
recipe.super_fat_percent = 6.0
recipe.lye_concentration_percent = 30.0
recipe.fragrance_percent = 4.0
@time Soapy.maximise_quality(recipe, "INS")