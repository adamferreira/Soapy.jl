import csv, json, os
dir_path = os.path.dirname(os.path.realpath(__file__))


if __name__ == "__main__":
    oils = []
    with open(os.path.join(dir_path, "..", "data", "oils.csv")) as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';')
        for row in spamreader:
            oils.append({
            "name" : row[0],
            "saponification" : { "value" : row[1].replace(" ", ""), "NaOH" : float(row[2]), "KOH" : float(row[3]) },
            "fatty-acid-composition" : {
                "Lauric" : 0.0,	 
                "Myristic" : 0.0, 
                "Palmitic" : 0.0,
                "Stearic" : 0.0,
                "Ricinoleic" : 0.0,
                "Oleic" : 0.0,
                "Linoleic" : 0.0,
                "Linolenic" : 0.0
            }
            })

    with open(os.path.join(dir_path, "..", "data", "oils.json"), "w+") as f:
        json.dump(oils, f,  indent=4)