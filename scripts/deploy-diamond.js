// scripts/deploy-diamond.js
const hre = require("hardhat");
const { getSelectors } = require("../contracts/utils/diamond-helpers");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  // 1. Deploy DiamondCutFacet
  const DiamondCutFacet = await hre.ethers.getContractFactory("DiamondCutFacet");
  const diamondCutFacet = await DiamondCutFacet.deploy();
  await diamondCutFacet.waitForDeployment();
  console.log("DiamondCutFacet deployed at:", await diamondCutFacet.getAddress());

  // 2. Deploy FortuneNXTDiamond with empty cut
  const FortuneNXTDiamond = await hre.ethers.getContractFactory("FortuneNXTDiamond");
  const diamond = await FortuneNXTDiamond.deploy([]);
  await diamond.waitForDeployment();
  const diamondAddress = await diamond.getAddress();
  console.log("FortuneNXTDiamond deployed at:", diamondAddress);

  // 3. Define facets to deploy and add
  const facetNames = [
    "AdminFacet",
    "MagicPoolFacet",
    "MatrixFacet",   
    "LevelIncomeFacet",
    "PriceFeedFacet",
    "PurchaseFacet",
    "RegistrationFacet",
  
    // Add more facet names if needed
  ];

  const FacetCutActions = { Add: 0, Replace: 1, Remove: 2 };
const diamondCuts = [];

const allSelectors = new Set(); // To track unique function selectors

for (const name of facetNames) {
  const Facet = await hre.ethers.getContractFactory(name);
  const facet = await Facet.deploy();
  await facet.waitForDeployment();
  const facetAddress = await facet.getAddress();
  console.log(`${name} deployed at:`, facetAddress);

  let selectors = getSelectors(facet);

  // Filter out selectors that are already added
  selectors = selectors.filter((selector) => !allSelectors.has(selector));
  selectors.forEach((s) => allSelectors.add(s));

  if (selectors.length === 0) {
    console.log(`⚠️  Skipping ${name} — no new selectors`);
    continue;
  }

  diamondCuts.push({
    facetAddress,
    action: FacetCutActions.Add,
    functionSelectors: selectors,
  });
}


  // 4. Perform diamond cut
  const diamondWithCut = await hre.ethers.getContractAt("FortuneNXTDiamond", diamondAddress);
  const tx = await diamondWithCut.diamondCut(
    diamondCuts,
    hre.ethers.ZeroAddress, // No _init address
    "0x" // No _calldata
  );
  await tx.wait();
  console.log("✅ Diamond cut completed with all facets integrated.");
}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exitCode = 1;
});
