const { ethers } = require("hardhat");
const AddressZero = "0x0000000000000000000000000000000000000000";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  // 1. Deploy DiamondCutFacet
  const DiamondCutFacetFactory = await ethers.getContractFactory("DiamondCutFacet");
  const diamondCutFacet = await DiamondCutFacetFactory.deploy();
  await diamondCutFacet.waitForDeployment();
  console.log("DiamondCutFacet deployed at:", diamondCutFacet.target);

  // Prepare initial diamond cut array with DiamondCutFacet
  const initialCut = [
    {
      facetAddress: diamondCutFacet.target,
      action: 0, // Add
      functionSelectors: getSelectors(DiamondCutFacetFactory.interface),
    },
  ];

  // 2. Deploy Diamond with initial cut
  const FortuneNXTDiamondFactory = await ethers.getContractFactory("FortuneNXTDiamond");
  const diamond = await FortuneNXTDiamondFactory.deploy(initialCut);
  await diamond.waitForDeployment();
  console.log("Diamond deployed at:", diamond.target);

  // 3. Deploy other facets
  const facetsToDeploy = [
    "AdminFacet",
    "PurchaseFacet",
    "PriceFeedFacet",
    "RegistrationFacet",
    "LevelIncomeFacet",
    "MatrixFacet",
    "MagicPoolFacet"
  ];

  const facetAddresses = {};
  const facetInterfaces = {};

  for (const facetName of facetsToDeploy) {
    const FacetFactory = await ethers.getContractFactory(facetName);
    const facet = await FacetFactory.deploy();
    await facet.waitForDeployment();
    facetAddresses[facetName] = facet.target;
    facetInterfaces[facetName] = FacetFactory.interface;
    console.log(`${facetName} deployed at:`, facet.target);
  }

  // 4. Prepare diamond cut for additional facets
  const diamondCut = [];
  const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 };

  for (const facetName of facetsToDeploy) {
    const facetAddress = facetAddresses[facetName];
    const functionSelectors = getSelectors(facetInterfaces[facetName]);
    diamondCut.push({
      facetAddress,
      action: FacetCutAction.Add,
      functionSelectors,
    });
  }

  // 5. Verify diamond owner before diamondCut
  const diamondContract = await ethers.getContractAt("FortuneNXTDiamond", diamond.target, deployer);
  const owner = await diamondContract.getOwner();
  console.log("Diamond owner:", owner);
  console.log("Deployer address:", deployer.address);

  if (owner.toLowerCase() !== deployer.address.toLowerCase()) {
    throw new Error("Deployer is not the owner of the diamond. Cannot perform diamondCut.");
  }

  // 6. Execute diamond cut to add facets
  const diamondCutFacetContract = await ethers.getContractAt("IDiamondCut", diamond.target, deployer);
  const tx = await diamondCutFacetContract.diamondCut(diamondCut, AddressZero, "0x");
  console.log("Diamond cut tx submitted:", tx.hash);
  const receipt = await tx.wait();
  if (!receipt.status) {
    throw new Error(`Diamond cut failed: ${tx.hash}`);
  }
  console.log("Diamond cut completed");

  // 7. Set price feed address via AdminFacet
  const adminFacet = await ethers.getContractAt("AdminFacet", diamond.target, deployer);
  const tx2 = await adminFacet.setPriceFeed(facetAddresses["PriceFeedFacet"]);
  await tx2.wait();
  console.log("Price feed address set in diamond storage");

  console.log("Deployment and setup complete");
}

// Helper function to get function selectors from facet interface
function getSelectors(contractInterface) {
  const selectors = [];
  for (const fragment of contractInterface.fragments) {
    if (fragment.type === "function") {
      selectors.push(fragment.selector);
    }
  }
  return selectors;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });