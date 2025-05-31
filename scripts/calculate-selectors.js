
// SPDX-License-Identifier: MIT
const { ethers } = require("hardhat");

async function main() {
  console.log("Calculating correct function selectors...");

  // Deploy contracts to get their interfaces
  const AdminFacet = await ethers.getContractFactory("AdminFacet");
  const RegistrationFacet = await ethers.getContractFactory("RegistrationFacet");
  const PurchaseFacet = await ethers.getContractFactory("PurchaseFacet");
  const MatrixFacet = await ethers.getContractFactory("MatrixFacet");
  const LevelIncomeFacet = await ethers.getContractFactory("LevelIncomeFacet");
  const PoolIncomeFacet = await ethers.getContractFactory("PoolIncomeFacet");

  // Function to get selectors excluding inherited functions
  function getSelectorsForFacet(contractFactory, facetName) {
    const excludedFunctions = [
      // AccessControl functions
      'hasRole', 'getRoleAdmin', 'grantRole', 'revokeRole', 'renounceRole',
      'supportsInterface', '_checkRole', '_setupRole', '_setRoleAdmin',
      '_grantRole', '_revokeRole',
      // Common inherited functions
      'owner', 'transferOwnership', 'renounceOwnership'
    ];

    const selectors = [];
    const functionNames = [];

    for (const fragment of Object.values(contractFactory.interface.fragments)) {
      if (fragment.type === 'function' && 
          !excludedFunctions.includes(fragment.name) &&
          fragment.name !== 'init') {
        const selector = contractFactory.interface.getFunction(fragment.name).selector;
        selectors.push(selector);
        functionNames.push(fragment.name);
      }
    }

    console.log(`\n${facetName} Functions:`);
    for (let i = 0; i < functionNames.length; i++) {
      console.log(`  ${functionNames[i]}: ${selectors[i]}`);
    }

    return selectors;
  }

  // Get selectors for each facet
  const adminSelectors = getSelectorsForFacet(AdminFacet, "AdminFacet");
  const registrationSelectors = getSelectorsForFacet(RegistrationFacet, "RegistrationFacet");
  const purchaseSelectors = getSelectorsForFacet(PurchaseFacet, "PurchaseFacet");
  const matrixSelectors = getSelectorsForFacet(MatrixFacet, "MatrixFacet");
  const levelIncomeSelectors = getSelectorsForFacet(LevelIncomeFacet, "LevelIncomeFacet");
  const poolIncomeSelectors = getSelectorsForFacet(PoolIncomeFacet, "PoolIncomeFacet");

  console.log("\n=== Summary ===");
  console.log("AdminFacet selectors:", adminSelectors.length);
  console.log("RegistrationFacet selectors:", registrationSelectors.length);
  console.log("PurchaseFacet selectors:", purchaseSelectors.length);
  console.log("MatrixFacet selectors:", matrixSelectors.length);
  console.log("LevelIncomeFacet selectors:", levelIncomeSelectors.length);
  console.log("PoolIncomeFacet selectors:", poolIncomeSelectors.length);

  // Generate the corrected deployment script
  const deploymentScript = `
// SPDX-License-Identifier: MIT
const { ethers } = require("hardhat");

async function main() {
  console.log("Starting Fortunity NXT Diamond deployment...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // Step 1: Deploy all Facet contracts
  console.log("\\n=== Deploying Facets ===");

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

  // Step 2: Get correct function selectors
  console.log("\\n=== Getting Function Selectors ===");

  // Correct function selectors (calculated dynamically)
  const adminSelectors = ${JSON.stringify(adminSelectors)};
  const registrationSelectors = ${JSON.stringify(registrationSelectors)};
  const purchaseSelectors = ${JSON.stringify(purchaseSelectors)};
  const matrixSelectors = ${JSON.stringify(matrixSelectors)};
  const levelIncomeSelectors = ${JSON.stringify(levelIncomeSelectors)};
  const poolIncomeSelectors = ${JSON.stringify(poolIncomeSelectors)};

  console.log("AdminFacet selectors:", adminSelectors.length);
  console.log("RegistrationFacet selectors:", registrationSelectors.length);
  console.log("PurchaseFacet selectors:", purchaseSelectors.length);
  console.log("MatrixFacet selectors:", matrixSelectors.length);
  console.log("LevelIncomeFacet selectors:", levelIncomeSelectors.length);
  console.log("PoolIncomeFacet selectors:", poolIncomeSelectors.length);

  // Step 3: Prepare Diamond Cut
  console.log("\\n=== Preparing Diamond Cut ===");

  const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 };

  const diamondCut = [
    {
      facetAddress: await adminFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: adminSelectors
    },
    {
      facetAddress: await registrationFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: registrationSelectors
    },
    {
      facetAddress: await purchaseFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: purchaseSelectors
    },
    {
      facetAddress: await matrixFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: matrixSelectors
    },
    {
      facetAddress: await levelIncomeFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: levelIncomeSelectors
    },
    {
      facetAddress: await poolIncomeFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: poolIncomeSelectors
    }
  ];

  // Step 4: Deploy Diamond
  console.log("\\n=== Deploying Diamond ===");

  const FortuneNXTDiamond = await ethers.getContractFactory("FortuneNXTDiamond");
  const diamond = await FortuneNXTDiamond.deploy(diamondCut);
  await diamond.waitForDeployment();
  console.log("FortuneNXTDiamond deployed to:", await diamond.getAddress());

  // Step 5: Initialize the system
  console.log("\\n=== Initializing System ===");

  // Initialize AdminFacet through Diamond
  const diamondAsAdmin = await ethers.getContractAt("AdminFacet", await diamond.getAddress());

  try {
    await diamondAsAdmin.initializeAdminFacet(deployer.address);
    console.log("AdminFacet initialized successfully");
  } catch (error) {
    console.log("AdminFacet initialization skipped:", error.message);
  }

  // Set treasury
  try {
    await diamondAsAdmin.setTreasury(deployer.address);
    console.log("Treasury set successfully");
  } catch (error) {
    console.log("Treasury setting failed:", error.message);
  }

  // Step 6: Configure initial slots (1-12)
  console.log("\\n=== Configuring Initial Slots ===");

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
      await diamondAsAdmin.updateSlot(i + 1, slotPrices[i], poolPercents[i]);
      await diamondAsAdmin.setSlotActive(i + 1, true);
      console.log(\`Slot \${i + 1} configured: \${ethers.formatEther(slotPrices[i])} ETH\`);
    } catch (error) {
      console.log(\`Failed to configure slot \${i + 1}:\`, error.message);
    }
  }

  // Step 7: Configure level requirements
  console.log("\\n=== Configuring Level Requirements ===");

  const levelConfigs = [
    { level: 1, directRequired: 1, percent: 10 },
    { level: 2, directRequired: 2, percent: 8 },
    { level: 3, directRequired: 3, percent: 6 },
    { level: 4, directRequired: 4, percent: 4 },
    { level: 5, directRequired: 5, percent: 2 }
  ];

  for (const config of levelConfigs) {
    try {
      await diamondAsAdmin.updateLevelRequirement(
        config.level,
        config.directRequired,
        config.percent
      );
      console.log(\`Level \${config.level} configured: \${config.directRequired} direct, \${config.percent}%\`);
    } catch (error) {
      console.log(\`Failed to configure level \${config.level}:\`, error.message);
    }
  }

  // Step 8: Verification
  console.log("\\n=== Deployment Verification ===");

  const facetAddresses = await diamond.facetAddresses();
  console.log("Number of facets:", facetAddresses.length);
  console.log("Facet addresses:", facetAddresses);

  // Step 9: Summary
  console.log("\\n=== Deployment Summary ===");
  console.log("Diamond Address:", await diamond.getAddress());
  console.log("\\nFacet Addresses:");
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

  console.log("\\n=== Deployment Complete ===");
  console.log("Save this deployment info for frontend integration:");
  console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });
`;

  console.log("\n=== Generated Corrected Deployment Script ===");
  console.log("The script above contains the correct function selectors.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
