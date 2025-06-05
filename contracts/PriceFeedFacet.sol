// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceFeedFacet
 * @dev Handles dynamic pricing for Fortunity NXT slots based on real-time CORE price
 */
contract PriceFeedFacet {
    struct PriceFeedStorage {
        AggregatorV3Interface corePriceFeed;
        uint256[12] slotPricesUSD; // Fixed USD prices for each slot
        uint256 priceUpdateInterval; // Minimum time between price updates
        uint256 lastPriceUpdate;
        uint256 cachedCorePrice; // Cached CORE price in USD (8 decimals)
        bool dynamicPricingEnabled;
        address priceFeedAdmin;
    }

    bytes32 constant PRICE_FEED_STORAGE_POSITION =
        keccak256("fortunity.nxt.pricefeed.storage");

    function priceFeedStorage()
        internal
        pure
        returns (PriceFeedStorage storage ds)
    {
        bytes32 position = PRICE_FEED_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    event PriceUpdated(uint256 newPrice, uint256 timestamp);
    event SlotPriceUpdated(
        uint256 slotId,
        uint256 newPriceInCore,
        uint256 priceInUSD
    );
    event DynamicPricingToggled(bool enabled);

    modifier onlyPriceFeedAdmin() {
        require(
            msg.sender == priceFeedStorage().priceFeedAdmin,
            "Not price feed admin"
        );
        _;
    }

    /**
     * @dev Initialize the price feed system
     * @param _corePriceFeed Address of CORE/USD Chainlink price feed
     * @param _admin Address of price feed administrator
     */
    function initializePriceFeed(
        address _corePriceFeed,
        address _admin
    ) external {
        PriceFeedStorage storage ds = priceFeedStorage();
        require(ds.priceFeedAdmin == address(0), "Already initialized");

        ds.corePriceFeed = AggregatorV3Interface(_corePriceFeed);
        ds.priceFeedAdmin = _admin;
        ds.priceUpdateInterval = 300; // 5 minutes
        ds.dynamicPricingEnabled = true;

        // Set fixed USD prices for each slot ($5 to $10,240)
        ds.slotPricesUSD[0] = 5 * 10 ** 8; // $5 (8 decimals)
        ds.slotPricesUSD[1] = 10 * 10 ** 8; // $10
        ds.slotPricesUSD[2] = 20 * 10 ** 8; // $20
        ds.slotPricesUSD[3] = 40 * 10 ** 8; // $40
        ds.slotPricesUSD[4] = 80 * 10 ** 8; // $80
        ds.slotPricesUSD[5] = 160 * 10 ** 8; // $160
        ds.slotPricesUSD[6] = 320 * 10 ** 8; // $320
        ds.slotPricesUSD[7] = 640 * 10 ** 8; // $640
        ds.slotPricesUSD[8] = 1280 * 10 ** 8; // $1,280
        ds.slotPricesUSD[9] = 2560 * 10 ** 8; // $2,560
        ds.slotPricesUSD[10] = 5120 * 10 ** 8; // $5,120
        ds.slotPricesUSD[11] = 10240 * 10 ** 8; // $10,240

        // Get initial price
        _updateCorePrice();
    }

    /**
     * @dev Get current CORE price from Chainlink
     * @return price CORE price in USD (8 decimals)
     */
    function getCurrentCorePrice() public view returns (uint256 price) {
        PriceFeedStorage storage ds = priceFeedStorage();

        if (!ds.dynamicPricingEnabled) {
            return ds.cachedCorePrice;
        }

        try ds.corePriceFeed.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            require(answer > 0, "Invalid price");
            require(updatedAt > 0, "Price not updated");
            require(block.timestamp - updatedAt < 3600, "Price too old"); // 1 hour max

            return uint256(answer); // Chainlink returns 8 decimals
        } catch {
            // Fallback to cached price if Chainlink fails
            return ds.cachedCorePrice;
        }
    }

    /**
     * @dev Update cached CORE price
     */
    function updateCorePrice() external {
        _updateCorePrice();
    }

    function _updateCorePrice() internal {
        PriceFeedStorage storage ds = priceFeedStorage();

        if (block.timestamp - ds.lastPriceUpdate < ds.priceUpdateInterval) {
            return; // Too soon to update
        }

        uint256 newPrice = getCurrentCorePrice();
        ds.cachedCorePrice = newPrice;
        ds.lastPriceUpdate = block.timestamp;

        emit PriceUpdated(newPrice, block.timestamp);
    }

    /**
     * @dev Get slot price in CORE tokens
     * @param slotId Slot number (1-12)
     * @return priceInCore Price in CORE tokens (18 decimals)
     */
    function getSlotPriceInCore(
        uint256 slotId
    ) public view returns (uint256 priceInCore) {
        require(slotId >= 1 && slotId <= 12, "Invalid slot ID");

        PriceFeedStorage storage ds = priceFeedStorage();
        uint256 slotIndex = slotId - 1;
        uint256 priceInUSD = ds.slotPricesUSD[slotIndex]; // 8 decimals
        uint256 corePrice = getCurrentCorePrice(); // 8 decimals

        require(corePrice > 0, "Invalid CORE price");

        // Calculate: (priceInUSD * 10^18) / corePrice
        // This gives us the price in CORE with 18 decimals
        priceInCore = (priceInUSD * 10 ** 18) / corePrice;

        return priceInCore;
    }

    /**
     * @dev Get slot price in USD
     * @param slotId Slot number (1-12)
     * @return priceInUSD Price in USD (8 decimals)
     */
    function getSlotPriceInUSD(
        uint256 slotId
    ) external view returns (uint256 priceInUSD) {
        require(slotId >= 1 && slotId <= 12, "Invalid slot ID");

        PriceFeedStorage storage ds = priceFeedStorage();
        return ds.slotPricesUSD[slotId - 1];
    }

    /**
     * @dev Get all slot prices in CORE
     * @return prices Array of prices in CORE (18 decimals)
     */
    function getAllSlotPricesInCore()
        external
        view
        returns (uint256[12] memory prices)
    {
        for (uint256 i = 1; i <= 12; i++) {
            prices[i - 1] = getSlotPriceInCore(i);
        }
        return prices;
    }

    /**
     * @dev Get all slot prices in USD
     * @return prices Array of prices in USD (8 decimals)
     */
    function getAllSlotPricesInUSD()
        external
        view
        returns (uint256[12] memory prices)
    {
        PriceFeedStorage storage ds = priceFeedStorage();
        return ds.slotPricesUSD;
    }

    /**
     * @dev Update USD price for a specific slot
     * @param slotId Slot number (1-12)
     * @param newPriceUSD New price in USD (8 decimals)
     */
    function updateSlotPriceUSD(
        uint256 slotId,
        uint256 newPriceUSD
    ) external onlyPriceFeedAdmin {
        require(slotId >= 1 && slotId <= 12, "Invalid slot ID");
        require(newPriceUSD > 0, "Price must be positive");

        PriceFeedStorage storage ds = priceFeedStorage();
        ds.slotPricesUSD[slotId - 1] = newPriceUSD;

        uint256 newPriceInCore = getSlotPriceInCore(slotId);
        emit SlotPriceUpdated(slotId, newPriceInCore, newPriceUSD);
    }

    /**
     * @dev Toggle dynamic pricing on/off
     * @param enabled Whether dynamic pricing should be enabled
     */
    function setDynamicPricingEnabled(
        bool enabled
    ) external onlyPriceFeedAdmin {
        PriceFeedStorage storage ds = priceFeedStorage();
        ds.dynamicPricingEnabled = enabled;
        emit DynamicPricingToggled(enabled);
    }

    /**
     * @dev Set price update interval
     * @param intervalSeconds Minimum seconds between price updates
     */
    function setPriceUpdateInterval(
        uint256 intervalSeconds
    ) external onlyPriceFeedAdmin {
        require(intervalSeconds >= 60, "Interval too short"); // Minimum 1 minute
        PriceFeedStorage storage ds = priceFeedStorage();
        ds.priceUpdateInterval = intervalSeconds;
    }

    /**
     * @dev Set new price feed admin
     * @param newAdmin New admin address
     */
    function setPriceFeedAdmin(address newAdmin) external onlyPriceFeedAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        PriceFeedStorage storage ds = priceFeedStorage();
        ds.priceFeedAdmin = newAdmin;
    }

    /**
     * @dev Emergency function to set manual CORE price
     * @param manualPrice Manual price in USD (8 decimals)
     */
    function setManualCorePrice(
        uint256 manualPrice
    ) external onlyPriceFeedAdmin {
        require(manualPrice > 0, "Invalid price");
        PriceFeedStorage storage ds = priceFeedStorage();
        ds.cachedCorePrice = manualPrice;
        ds.lastPriceUpdate = block.timestamp;
        emit PriceUpdated(manualPrice, block.timestamp);
    }

    /**
     * @dev Get price feed configuration
     */
    function getPriceFeedConfig()
        external
        view
        returns (
            address priceFeed,
            uint256 updateInterval,
            uint256 lastUpdate,
            uint256 cachedPrice,
            bool dynamicEnabled,
            address admin
        )
    {
        PriceFeedStorage storage ds = priceFeedStorage();
        return (
            address(ds.corePriceFeed),
            ds.priceUpdateInterval,
            ds.lastPriceUpdate,
            ds.cachedCorePrice,
            ds.dynamicPricingEnabled,
            ds.priceFeedAdmin
        );
    }

    /**
     * @dev Check if price needs update
     */
    function needsPriceUpdate() external view returns (bool) {
        PriceFeedStorage storage ds = priceFeedStorage();
        return block.timestamp - ds.lastPriceUpdate >= ds.priceUpdateInterval;
    }
}
