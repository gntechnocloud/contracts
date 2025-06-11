# Fortunity NXT Smart Contracts

This repository contains the Solidity smart contracts and deployment scripts for **Fortunity NXT**, a crypto-based Semi-DAPP MLM platform using a 2x2 Forced Matrix MLM structure. The system includes Matrix Income, Level Income, Pool Income, and automatic Rebirth logic. Users buy progressive slots, each with its own earning and re-entry rules. A 3% admin fee applies to all payouts (not rebirth). Pool Income is distributed on the 5th, 15th, and 25th, among 12 slot sub-pools. The platform uses a Diamond (EIP-2535) proxy pattern for modular upgradeability.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Contracts](#contracts)
<!--
This section of the README provides a link to the "Deployment" section, allowing users to quickly navigate to deployment instructions or related information within the documentation.
-->
- [Deployment](#deployment)
- [Usage](#usage)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

---

## Project Overview

Fortunity NXT is a decentralized MLM platform built on Ethereum-compatible blockchains. It uses a **Diamond Proxy** pattern to enable modular and upgradeable smart contracts. The MLM logic is implemented through multiple facets, each handling a specific part of the system such as registration, purchase, income distribution, matrix management, and price feeds.

---

## Architecture

- **Diamond Proxy (FortuneNXTDiamond.sol):** The main contract that delegates calls to various facets.
- **Facets:** Modular contracts implementing specific features.
- **LibDiamond.sol:** Library managing diamond storage and ownership.
- **IDiamondCut.sol:** Interface defining diamond cut functions.
- **DiamondCutFacet.sol:** Facet implementing diamond cut functionality.
- **AdminFacet.sol:** Admin functions including price feed management.
- **PurchaseFacet.sol:** Handles slot purchases and rebirth logic.
- **PriceFeedFacet.sol:** Integrates Chainlink oracles for price feeds.
- **RegistrationFacet.sol:** User registration and referral management.
- **LevelIncomeFacet.sol:** Level income distribution logic.
- **MatrixFacet.sol:** Forced matrix MLM logic.
- **MagicPoolFacet.sol:** Pool income distribution logic.
- **FortuneNXTStorage.sol:** Centralized storage struct for diamond facets.

---

## Contracts

| Contract Name     | Description                                 |
| ----------------- | ------------------------------------------- |
| FortuneNXTDiamond | Diamond proxy contract managing facets      |
| DiamondCutFacet   | Implements diamond cut (add/replace/remove) |
| AdminFacet        | Admin controls, price feed setup            |
| PurchaseFacet     | Slot purchase, rebirth, and income logic    |
| PriceFeedFacet    | Price feed integration (Chainlink oracles)  |
| RegistrationFacet | User registration and referral system       |
| LevelIncomeFacet  | Level income distribution                   |
| MatrixFacet       | Forced matrix MLM logic                     |
| MagicPoolFacet    | Pool income distribution                    |
| LibDiamond        | Diamond storage and ownership library       |
| IDiamondCut       | Diamond cut interface                       |
| FortuneNXTStorage | Shared storage struct for facets            |

---

## Deployment

### Prerequisites

- Node.js >= 16.x
- Hardhat
- Local Ethereum node or testnet access
- `@nomicfoundation/hardhat-toolbox` installed

### Steps

1. Compile contracts:

```bash
npx hardhat compile
```

2. Start local node (optional):

```bash
npx hardhat node
```

3. Deploy contracts:

```bash
npx hardhat run ./scripts/deploy-diamond.js --network localhost
```

4. The deploy script will:

- Deploy `DiamondCutFacet`
- Deploy the diamond proxy contract with initial cut
- Deploy all other facets
- Perform diamond cut to add facets to diamond
- Set price feed address in admin facet

---

## Usage

- Connect your frontend DApp to the deployed diamond contract address.
- Interact with facets via the diamond proxy.
- Use the ABI files of facets you want to interact with.
- Wallet connection and Web3 provider integration required.

---

## Testing

- Unit tests can be added using Hardhat test framework.
- Use `npx hardhat test` to run tests.
- Test deployment and diamond cut on local or testnet before mainnet.

---

## Contributing

- Fork the repository.
- Create feature branches.
- Submit pull requests with detailed descriptions.
- Follow Solidity best practices and security guidelines.

---

## License

This project is licensed under the MIT License.
