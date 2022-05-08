using Soapy

# Make a soap with most commun oils
recipe = Soapy.RecipeCalculator("oils_basic.json")
# Make a 1kg soap
recipe.target_weight = 1000.0
# Use recommended qualities for a balanced soap
recipe.target_qualities = Soapy.recommended_qualities()
# Maximise the INS (overall) score of the soap
Soapy.maximise_quality(recipe, "INS")