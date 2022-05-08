import csv, json, os
from statistics import quantiles
dir_path = os.path.dirname(os.path.realpath(__file__))


if __name__ == "__main__":
    oils = []
    qualities = {}

    with open(os.path.join(dir_path, "..", "data", "soap_qualities.csv")) as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';')
        header = next(spamreader)
        for row in spamreader:
            qualities[row[0].replace("'", "")] = {}
            qualities[row[0].replace("'", "")]["Iodine"] = float(row[6])
            qualities[row[0].replace("'", "")]["INS"] = float(row[7])

    with open(os.path.join(dir_path, "..", "data", "oils.csv")) as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';')
        for row in spamreader:
            
            oil_name = row[0].replace("'", "")
            iodine = 0.0
            ins = 0.0

            for o in qualities:
                if (oil_name.lower() in o.lower()) or (o.lower() in oil_name.lower()):
                    print("Match ! ", oil_name, "=", o)
                    iodine = qualities[o]["Iodine"]
                    ins = qualities[o]["INS"]


            oils.append({
            "name" : oil_name,
            "saponification" : { "SAP-value" : row[1].replace(" ", ""), "NaOH" : float(row[2]), "KOH" : float(row[3]), "Iodine" : iodine, "INS" : ins },
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