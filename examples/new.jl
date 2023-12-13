using Soapy

dataset = "oils_aromazone.json"
# Make a soap with most commun oils
opt = default_options()
# Make a 1kg soap
opt.target_weight = 1000.0
# Use recommended qualities for a balanced soap 
opt.quality_restriction = Soapy.recommended_qualities()
opt.quality_restriction.Iodine = 0..0
opt.quality_restriction.INS = 0..0
opt.target_number_of_oils = 1..10
# Maximise the INS (overall) score of the soap
opt.super_fat_percent = 4.0
opt.lye_concentration_percent = 33.0
opt.fragrance_percent = 0.0
opt.price_range = 1.0..200.0

recipe = solve(load_oils(dataset), opt)
println(recipe)