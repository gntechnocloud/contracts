
// SPDX-License-Identifier: MIT
const { ethers } = require("hardhat");

async function main() {
  console.log("Starting Fortunity NXT Diamond deployment...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // Helper function to get only real function selectors (excluding variables/constants/inherited)
  function getFacetFunctionSelectors(contractFactory, facetName) {
    const excludedFunctions = [
      // AccessControl inherited functions
      'hasRole', 'getRoleAdmin', 'grantRole', 'revokeRole', 'renounceRole',
      'supportsInterface', '_checkRole', '_setupRole', '_setRoleAdmin',
      '_grantRole', '_revokeRole',
      // Common inherited functions
      'owner', 'transferOwnership', 'renounceOwnership',
      // Storage variables that appear as functions
      'ADMIN_FEE_PERCENT', 'LEVEL_INCOME_PERCENT', 'MATRIX_INCOME_PERCENT',
      'MAX_PAYOUT_PERCENT', 'MAX_PAYOUT_TIME', 'POOL_EXTRA_PERCENT',
      'lastPoolDistributionTime', 'poolDistributionDays', 'totalPoolBalance',
      'totalUsers', 'totalVolume', 'treasury', 'version', 'ADMIN_ROLE',
      'DEFAULT_ADMIN_ROLE'
    ];

    const selectors = [];
    const functionNames = [];

    for (const fragment of Object.values(contractFactory.interface.fragments)) {
      if (
        fragment.type === 'function' &&
        !excludedFunctions.includes(fragment.name) &&
        fragment.name !== 'init' &&
        // Only include functions that are not pure constants
        fragment.stateMutability !== 'pure'
      ) {
        const selector = contractFactory.interface.getFunction(fragment.name).selector;
        selectors.push(selector);
        functionNames.push(fragment.name);
      }
    }

    console.log(`\n${facetName} Functions (${selectors.length}):`);
    for (let i = 0; i < functionNames.length; i++) {
      console.log(`  ${functionNames[i]}: ${selectors[i]}`);
    }

    return selectors;
  }

  // Step 1: Deploy all Facet contracts
  console.log("\n=== Deploying Facets ===");

  const AdminFacet = await ethers.getContractFactory("AdminFacet");
  const adminFacet = await AdminFacet.deploy();
  await adminFacet.waitForDeployment();
  console.log("AdminFacet deployed to:", await adminFacet.getAddress());

  const RegistrationFacet = await ethers.getContractFactory("RegistrationFacet");
  const registrationFacet = await RegistrationFacet.deploy();
  await registrationFacet.waitForDeployment();
  console.log("RegistrationFacet deployed to:", await registrationFacet.getAddress());

  const PurchaseFacet = await ethers.getContractFactory("PurchaseFacet");
  const purchaseFacet = await PurchaseFacet.deploy();
  await purchaseFacet.waitForDeployment();
  console.log("PurchaseFacet deployed to:", await purchaseFacet.getAddress());

  const MatrixFacet = await ethers.getContractFactory("MatrixFacet");
  const matrixFacet = await MatrixFacet.deploy();
  await matrixFacet.waitForDeployment();
  console.log("MatrixFacet deployed to:", await matrixFacet.getAddress());

  const LevelIncomeFacet = await ethers.getContractFactory("LevelIncomeFacet");
  const levelIncomeFacet = await LevelIncomeFacet.deploy();
  await levelIncomeFacet.waitForDeployment();
  console.log("LevelIncomeFacet deployed to:", await levelIncomeFacet.getAddress());

  const PoolIncomeFacet = await ethers.getContractFactory("PoolIncomeFacet");
  const poolIncomeFacet = await PoolIncomeFacet.deploy();
  await poolIncomeFacet.waitForDeployment();
  console.log("PoolIncomeFacet deployed to:", await poolIncomeFacet.getAddress());

  // Step 2: Get function selectors for each facet
  console.log("\n=== Getting Function Selectors ===");

  const adminSelectors = getFacetFunctionSelectors(AdminFacet, "AdminFacet");
  const registrationSelectors = getFacetFunctionSelectors(RegistrationFacet, "RegistrationFacet");
  const purchaseSelectors = getFacetFunctionSelectors(PurchaseFacet, "PurchaseFacet");
  const matrixSelectors = getFacetFunctionSelectors(MatrixFacet, "MatrixFacet");
  const levelIncomeSelectors = getFacetFunctionSelectors(LevelIncomeFacet, "LevelIncomeFacet");
  const poolIncomeSelectors = getFacetFunctionSelectors(PoolIncomeFacet, "PoolIncomeFacet");

  // Check for duplicate selectors
  const allSelectors = [
    ...adminSelectors,
    ...registrationSelectors,
    ...purchaseSelectors,
    ...matrixSelectors,
    ...levelIncomeSelectors,
    ...poolIncomeSelectors
  ];

  const uniqueSelectors = [...new Set(allSelectors)];
  if (allSelectors.length !== uniqueSelectors.length) {
    console.log("\n⚠️  WARNING: Duplicate function selectors detected!");
    const duplicates = allSelectors.filter((item, index) => allSelectors.indexOf(item) !== index);
    console.log("Duplicates:", [...new Set(duplicates)]);
  } else {
    console.log("\n✅ No duplicate selectors found");
  }

  console.log("\nSelector Summary:");
  console.log("- AdminFacet:", adminSelectors.length);
  console.log("- RegistrationFacet:", registrationSelectors.length);
  console.log("- PurchaseFacet:", purchaseSelectors.length);
  console.log("- MatrixFacet:", matrixSelectors.length);
  console.log("- LevelIncomeFacet:", levelIncomeSelectors.length);
  console.log("- PoolIncomeFacet:", poolIncomeSelectors.length);
  console.log("- Total:", allSelectors.length);

  // Step 3: Prepare Diamond Cut
  console.log("\n=== Preparing Diamond Cut ===");

  const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 };

  const diamondCut = [];

  if (adminSelectors.length > 0) {
    diamondCut.push({
      facetAddress: await adminFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: adminSelectors
    });
  }

  if (registrationSelectors.length > 0) {
    diamondCut.push({
      facetAddress: await registrationFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: registrationSelectors
    });
  }

  if (purchaseSelectors.length > 0) {
    diamondCut.push({
      facetAddress: await purchaseFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: purchaseSelectors
    });
  }

  if (matrixSelectors.length > 0) {
    diamondCut.push({
      facetAddress: await matrixFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: matrixSelectors
    });
  }

  if (levelIncomeSelectors.length > 0) {
    diamondCut.push({
      facetAddress: await levelIncomeFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: levelIncomeSelectors
    });
  }

  if (poolIncomeSelectors.length > 0) {
    diamondCut.push({
      facetAddress: await poolIncomeFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: poolIncomeSelectors
    });
  }

  console.log("Diamond cut prepared with", diamondCut.length, "facets");

  // Step 4: Deploy Diamond
  console.log("\n=== Deploying Diamond ===");

  const FortuneNXTDiamond = await ethers.getContractFactory("FortuneNXTDiamond");
  const diamond = await FortuneNXTDiamond.deploy(diamondCut);
  await diamond.waitForDeployment();
  console.log("FortuneNXTDiamond deployed to:", await diamond.getAddress());

  // Step 5: Initialize the system
  console.log("\n=== Initializing System ===");

  // Wait a moment for the deployment to settle
  await new Promise(resolve => setTimeout(resolve, 1000));

  // Initialize AdminFacet through Diamond
  const diamondAsAdmin = await ethers.getContractAt("AdminFacet", await diamond.getAddress());

  try {
    const tx = await diamondAsAdmin.initializeAdminFacet(deployer.address);
    await tx.wait();
    console.log("✅ AdminFacet initialized successfully");
  } catch (error) {
    console.log("❌ AdminFacet initialization failed:", error.message);
  }

  // Set treasury
  try {
    const tx = await diamondAsAdmin.setTreasury(deployer.address);
    await tx.wait();
    console.log("✅ Treasury set successfully");
  } catch (error) {
    console.log("❌ Treasury setting failed:", error.message);
  }

  // Step 6: Configure initial slots (1-12)
  console.log("\n=== Configuring Initial Slots ===");

  const slotPrices = [
    ethers.parseEther("0.01"),  // Slot 1
    ethers.parseEther("0.02"),  // Slot 2
    ethers.parseEther("0.04"),  // Slot 3
    ethers.parseEther("0.08"),  // Slot 4
    ethers.parseEther("0.16"),  // Slot 5
    ethers.parseEther("0.32"),  // Slot 6
    ethers.parseEther("0.64"),  // Slot 7
    ethers.parseEther("1.28"),  // Slot 8
    ethers.parseEther("2.56"),  // Slot 9
    ethers.parseEther("5.12"),  // Slot 10
    ethers.parseEther("10.24"), // Slot 11
    ethers.parseEther("20.48")  // Slot 12
  ];

  const poolPercents = [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10];

  for (let i = 0; i < 12; i++) {
    try {
      const tx1 = await diamondAsAdmin.updateSlot(i + 1, slotPrices[i], poolPercents[i]);
      await tx1.wait();
      const tx2 = await diamondAsAdmin.setSlotActive(i + 1, true);
      await tx2.wait();
      console.log(`✅ Slot ${i + 1} configured: ${ethers.formatEther(slotPrices[i])} ETH`);
    } catch (error) {
      console.log(`❌ Failed to configure slot ${i + 1}:`, error.message);
    }
  }

  // Step 7: Configure level requirements
  console.log("\n=== Configuring Level Requirements ===");

  const levelConfigs = [
    { level: 1, directRequired: 1, percent: 10 },
    { level: 2, directRequired: 2, percent: 8 },
    { level: 3, directRequired: 3, percent: 6 },
    { level: 4, directRequired: 4, percent: 4 },
    { level: 5, directRequired: 5, percent: 2 }
  ];

  for (const config of levelConfigs) {
    try {
      const tx = await diamondAsAdmin.updateLevelRequirement(
        config.level,
        config.directRequired,
        config.percent
      );
      await tx.wait();
      console.log(`✅ Level ${config.level} configured: ${config.directRequired} direct, ${config.percent}%`);
    } catch (error) {
      console.log(`❌ Failed to configure level ${config.level}:`, error.message);
    }
  }

  // Step 8: Verification
  console.log("\n=== Deployment Verification ===");

  try {
    const facetAddresses = await diamond.facetAddresses();
    console.log("Number of facets:", facetAddresses.length);
    console.log("Facet addresses:", facetAddresses);

    // Test a few functions
    if (adminSelectors.length > 0) {
      try {
        const treasury = await diamondAsAdmin.getTreasury();
        console.log("✅ Treasury address:", treasury);
      } catch (error) {
        console.log("❌ Failed to get treasury:", error.message);
      }
    }

    // Test slot info
    try {
      const slotInfo = await diamondAsAdmin.getSlotInfo(1);
      console.log("✅ Slot 1 info:", {
        price: ethers.formatEther(slotInfo[0]),
        poolPercent: slotInfo[1].toString(),
        active: slotInfo[2]
      });
    } catch (error) {
      console.log("❌ Failed to get slot info:", error.message);
    }

  } catch (error) {
    console.log("❌ Verification failed:", error.message);
  }

  // Step 9: Summary
  console.log("\n=== Deployment Summary ===");
  console.log("Diamond Address:", await diamond.getAddress());
  console.log("\nFacet Addresses:");
  console.log("- AdminFacet:", await adminFacet.getAddress());
  console.log("- RegistrationFacet:", await registrationFacet.getAddress());
  console.log("- PurchaseFacet:", await purchaseFacet.getAddress());
  console.log("- MatrixFacet:", await matrixFacet.getAddress());
  console.log("- LevelIncomeFacet:", await levelIncomeFacet.getAddress());
  console.log("- PoolIncomeFacet:", await poolIncomeFacet.getAddress());

  const deploymentInfo = {
    network: "hardhat",
    diamond: await diamond.getAddress(),
    facets: {
      AdminFacet: await adminFacet.getAddress(),
      RegistrationFacet: await registrationFacet.getAddress(),
      PurchaseFacet: await purchaseFacet.getAddress(),
      MatrixFacet: await matrixFacet.getAddress(),
      LevelIncomeFacet: await levelIncomeFacet.getAddress(),
      PoolIncomeFacet: await poolIncomeFacet.getAddress()
    },
    deployer: deployer.address,
    deployedAt: new Date().toISOString()
  };

  console.log("\n=== Deployment Complete ===");
  console.log("Save this deployment info for frontend integration:");
  console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
// This script deploys the Fortunity NXT Diamond contract with all facets and initial configurations.
// It includes detailed logging for each step of the deployment process, handles potential errors,
// and provides feedback on successful or failed operations.
// The deployment info is structured for easy integration with the frontend.
// This script is designed to be run in a Hardhat environment.
// Make sure to have the necessary contracts and their interfaces defined in your Hardhat project.
// This script assumes you have the necessary contracts and their interfaces defined in your Hardhat project.
// Note: Ensure all contracts are compiled before running this script.
// You can run this script using the command:  
// npx hardhat run scripts/deploy-fortunity-nxt.js --network hardhat
// Adjust the network as needed (e.g., mainnet, rinkeby, etc.)
// Make sure to have the necessary contracts in your contracts directory.
// Also, ensure you have the correct Hardhat configuration for the network you are deploying to.
// This script assumes you have the necessary contracts and their interfaces defined in your Hardhat project.
// If you encounter any issues, check the contract names and ensure they match your Solidity files. 
// You may need to adjust the selectors and initialization logic based on your specific contract implementations.
// This script is designed to deploy the Fortunity NXT Diamond contract with all facets and initial configurations.
// It includes detailed logging for each step of the deployment process.
// The script also handles potential errors during deployment and initialization, providing feedback on what was successful or failed.
// The deployment info is saved in a structured format for easy integration with the frontend.
// Make sure to test this script in a local Hardhat network before deploying to a live network.   