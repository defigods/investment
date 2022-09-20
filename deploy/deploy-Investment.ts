// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const uri = "https://mikelin-api.vercel.app/api/";

async function main() {
  const Investment = await hre.ethers.getContractFactory("Investment");
  const root = await Investment.deploy(uri);

  await root.deployed();

  console.log("Investment deployed to:", root.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
