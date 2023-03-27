import os


def main():
    rows = []
    rows.append(["comb",] + ["theo", "schd", "ratio"] *3)
    for model in ["alexnet", "mbnetv2_192", "mbnetv2", "resnet50", "vgg16", "yolov2_448"]:
        for bitwidth in [8, 16]:
            row = [f"{model}_{bitwidth}"]
            for platform in ["ultra96_128", "zcu102_128", "u200_512"]:
                name = f"{platform}_{bitwidth}-{model}"
                csv_path = f"results/{name}/agna-{name}.csv"
                sim_path = f"results/{name}/agna-sim.log"
                try:
                    with open(csv_path, "r") as f:
                        lines = f.readlines()
                        theo_lat = int(lines[-3].split(",")[0])
                except Exception as e:
                    print(f"Exception occurs when extracting {csv_path}:")
                    print(f"    {e}")
                    theo_lat = 1
                try:
                    with open(sim_path, "r") as f:
                        schd_lat = int(f.readlines()[-1].split("@")[-1].split(".")[0])
                except Exception as e:
                    print(f"Exception occurs when extracting {sim_path}:")
                    print(f"    {e}")
                    schd_lat = 1
                row += [theo_lat//1000, schd_lat//1000, f"{schd_lat/theo_lat:.3f}"]
            rows.append(row)
    with open("extract.csv", "w") as f:
        for row in rows:
            f.write(",".join(map(str, row)) + "\n")

if __name__ == "__main__":
    rows = main()