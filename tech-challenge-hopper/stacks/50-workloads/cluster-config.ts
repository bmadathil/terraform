import * as fs from "fs";
import * as path from "path";

export async function getClusterConfig() {

  if (process.env.CLUSTER_CONFIG_URL) {

    const response = await fetch(process.env.CLUSTER_CONFIG_URL);
    return await response.json();

  } else {

    const config = fs.readFileSync(
      path.resolve(__dirname, `${process.env.CLUSTER_CONFIG_PATH}`),
      "utf-8"
    );

    return JSON.parse(config);

  }

}

export default getClusterConfig;
