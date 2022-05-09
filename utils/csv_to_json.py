import csv, json, os
from statistics import quantiles
dir_path = os.path.dirname(os.path.realpath(__file__))


FATTY_ACIDS = [
    "Lauric",
    "Myristic",
    "Palmitic",
    "Stearic",
    "Ricinoleic",
    "Oleic",
    "Linoleic",
    "Linolenic"
]

def name_match(n1, n2):
    return (n1.lower() in n2.lower()) or (n2.lower() in n1.lower())

# First version joining oils_qualities.csv and oils_compositions.csv from one site with
# (https://www.fromnaturewithlove.com/resources/sapon.asp)
# SAP infos from oils.csv of another site 
# (http://www.certified-lye.com/lye-soap.html#:~:text=Because%20the%20water%20is%20used,of%20lye%20from%20the%20result)
def load_1():
    oils = []
    qualities = {}
    fatty_acids = {}

    with open(os.path.join(dir_path, "oils_qualities.csv")) as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';')
        header = next(spamreader)
        for row in spamreader:
            oil_name = row[0].replace("'", "")
            qualities[oil_name] = {}
            qualities[oil_name]["Iodine"] = float(row[6])
            qualities[oil_name]["INS"] = float(row[7])

    with open(os.path.join(dir_path, "oils_compositions.csv")) as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';')
        header = next(spamreader)
        for row in spamreader:
            oil_name = row[0].replace("'", "")
            fatty_acids[oil_name] = {}
            for i in range(len(FATTY_ACIDS)):
                fatty_acids[oil_name][FATTY_ACIDS[i]] = float(row[i+1])
            

    with open(os.path.join(dir_path, "oils.csv")) as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';')
        for row in spamreader:
            
            oil_name = row[0].replace("'", "")
            iodine = 0.0
            ins = 0.0
            fatty_acid_composition = {fa : 0.0 for fa in FATTY_ACIDS}

            for o in qualities:
                if name_match(oil_name, o):
                    print("Match ! ", oil_name, "=", o)
                    iodine = qualities[o]["Iodine"]
                    ins = qualities[o]["INS"]
                    if o in fatty_acids:
                        fatty_acid_composition = fatty_acids[o]


            oils.append({
            "name" : oil_name,
            "saponification" : { "SAP-value" : row[1].replace(" ", ""), "NaOH" : float(row[2]), "KOH" : float(row[3]), "Iodine" : iodine, "INS" : ins },
            "fatty-acid-composition" : fatty_acid_composition
            })

    with open(os.path.join(dir_path, "oils.json"), "w+") as f:
        json.dump(oils, f,  indent=4)

# Here we assume that oils_qualities.csv and oils_compositions.csv
# Constains the same oils in the same order
def load_2():
    oils = []
    qualities = {}
    compositions = {}

    with open(os.path.join(dir_path, "oils_qualities.csv")) as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';')
        header = next(spamreader)
        for row in spamreader:
            oil_name = row[0].replace("'", "")
            qualities[oil_name] = {}
            qualities[oil_name]["Iodine"] = float(row[6])
            qualities[oil_name]["INS"] = float(row[7])

    with open(os.path.join(dir_path, "oils_compositions.csv")) as csvfile:
        spamreader = csv.reader(csvfile, delimiter=';')
        header = next(spamreader)
        for row in spamreader:
            oil_name = row[0].replace("'", "")
            compositions[oil_name] = {}
            for i in range(len(FATTY_ACIDS)):
                compositions[oil_name][FATTY_ACIDS[i]] = float(row[i+1])
            compositions[oil_name]["NaOH_SAP"] = float(row[len(FATTY_ACIDS) + 1])
            compositions[oil_name]["KOH_SAP"] = float(row[len(FATTY_ACIDS) + 2])


    for oil in qualities:
        iodine = qualities[oil]["Iodine"]
        ins = qualities[oil]["INS"]
        fatty_acid_composition = {fa : 0.0 for fa in FATTY_ACIDS}
        SAP = "0-0"

        if oil in compositions:
            naoh =  compositions[oil]["NaOH_SAP"]
            koh =  compositions[oil]["KOH_SAP"]
            for f in FATTY_ACIDS:
                fatty_acid_composition[f] = compositions[oil][f]

        oils.append({
        "name" : oil,
        "saponification" : { 
            "SAP-value" : SAP, 
            "NaOH" : naoh, 
            "KOH" :koh, 
            "Iodine" : iodine, 
            "INS" : ins },
        "fatty-acid-composition" : fatty_acid_composition
        })
    
    with open(os.path.join(dir_path, "..", "data", "oils.json"), "w+") as f:
        json.dump(oils, f,  indent=4)

if __name__ == "__main__":
    load_2()