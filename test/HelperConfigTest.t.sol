// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfigTest is Test {
    HelperConfig helperConfig;

    // Known addresses for mainnet and sepolia
    address constant SEPOLIA_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant MAINNET_PRICE_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function setUp() external {
        helperConfig = new HelperConfig();
    }

    /*//////////////////////////////////////////////////////////////
                        SEPOLIA NETWORK TESTS
    //////////////////////////////////////////////////////////////*/

    function testSepoliaConfigReturnsCorrectPriceFeed() public view {
        HelperConfig.NetworkConfig memory config = helperConfig.getSepoliaEthConfig();
        assertEq(config.priceFeed, SEPOLIA_PRICE_FEED);
    }

    function testSepoliaNetworkIsDetectedCorrectly() public {
        vm.chainId(11155111);
        HelperConfig sepoliaHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = sepoliaHelper.getActiveNetworkConfig();
        assertEq(activeConfig.priceFeed, SEPOLIA_PRICE_FEED);
    }

    /*//////////////////////////////////////////////////////////////
                        MAINNET NETWORK TESTS
    //////////////////////////////////////////////////////////////*/

    function testMainnetConfigReturnsCorrectPriceFeed() public view {
        HelperConfig.NetworkConfig memory config = helperConfig.getMainnetEthConfig();
        assertEq(config.priceFeed, MAINNET_PRICE_FEED);
    }

    function testMainnetNetworkIsDetectedCorrectly() public {
        vm.chainId(1);
        HelperConfig mainnetHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = mainnetHelper.getActiveNetworkConfig();
        assertEq(activeConfig.priceFeed, MAINNET_PRICE_FEED);
    }

    /*//////////////////////////////////////////////////////////////
                        ANVIL/LOCAL NETWORK TESTS
    //////////////////////////////////////////////////////////////*/

    function testAnvilConfigDeploysMockPriceFeed() public {
        vm.chainId(31337);
        HelperConfig anvilHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = anvilHelper.getActiveNetworkConfig();
        assertTrue(activeConfig.priceFeed != address(0), "Price feed should be deployed");
    }

    function testAnvilMockHasCorrectDecimals() public {
        vm.chainId(31337);
        HelperConfig anvilHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = anvilHelper.getActiveNetworkConfig();

        MockV3Aggregator mockPriceFeed = MockV3Aggregator(activeConfig.priceFeed);
        uint8 decimals = mockPriceFeed.decimals();
        assertEq(decimals, 8);
    }

    function testAnvilMockHasCorrectInitialAnswer() public {
        vm.chainId(31337);
        HelperConfig anvilHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = anvilHelper.getActiveNetworkConfig();

        MockV3Aggregator mockPriceFeed = MockV3Aggregator(activeConfig.priceFeed);
        (, int256 answer,,,) = mockPriceFeed.latestRoundData();
        assertEq(answer, 2000e8);
    }

    function testAnvilMockReturnsCorrectVersion() public {
        vm.chainId(31337);
        HelperConfig anvilHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = anvilHelper.getActiveNetworkConfig();

        MockV3Aggregator mockPriceFeed = MockV3Aggregator(activeConfig.priceFeed);
        uint256 version = mockPriceFeed.version();
        assertEq(version, 4); // MockV3Aggregator returns version 4
    }

    function testGetOrCreateAnvilConfigReturnsSameAddressWhenCalledTwice() public {
        vm.chainId(31337);
        HelperConfig anvilHelper = new HelperConfig();

        HelperConfig.NetworkConfig memory config1 = anvilHelper.getOrCreateAnvilEthConfig();
        HelperConfig.NetworkConfig memory config2 = anvilHelper.getOrCreateAnvilEthConfig();
        assertEq(config1.priceFeed, config2.priceFeed);
    }

    /*//////////////////////////////////////////////////////////////
                        ACTIVE NETWORK CONFIG TESTS
    //////////////////////////////////////////////////////////////*/

    function testActiveNetworkConfigIsSetCorrectlyInConstructor() public view {
        HelperConfig.NetworkConfig memory activeConfig = helperConfig.getActiveNetworkConfig();
        assertTrue(activeConfig.priceFeed != address(0), "Active config should be initialized");
    }

    function testActiveNetworkConfigChangesWithChainId() public {
        // Test Sepolia
        vm.chainId(11155111);
        HelperConfig sepoliaHelper = new HelperConfig();
        assertEq(sepoliaHelper.getActiveNetworkConfig().priceFeed, SEPOLIA_PRICE_FEED);

        // Test Mainnet
        vm.chainId(1);
        HelperConfig mainnetHelper = new HelperConfig();
        assertEq(mainnetHelper.getActiveNetworkConfig().priceFeed, MAINNET_PRICE_FEED);

        // Test Anvil
        vm.chainId(31337);
        HelperConfig anvilHelper = new HelperConfig();
        address anvilPriceFeed = anvilHelper.getActiveNetworkConfig().priceFeed;
        assertTrue(anvilPriceFeed != address(0));
        assertTrue(anvilPriceFeed != SEPOLIA_PRICE_FEED);
        assertTrue(anvilPriceFeed != MAINNET_PRICE_FEED);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstantsAreSetCorrectly() public view {
        assertEq(helperConfig.DECIMALS(), 8);
        assertEq(helperConfig.INITIAL_ANSWER(), 2000e8);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testPriceFeedCanBeUsedToGetPrice() public {
        vm.chainId(31337);
        HelperConfig anvilHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = anvilHelper.getActiveNetworkConfig();
        MockV3Aggregator priceFeed = MockV3Aggregator(activeConfig.priceFeed);

        (, int256 price,,,) = priceFeed.latestRoundData();
        assertGt(price, 0, "Price should be greater than 0");
        assertEq(price, 2000e8, "Price should be $2000 with 8 decimals");
    }

    function testMockPriceFeedCanUpdatePrice() public {
        vm.chainId(31337);
        HelperConfig anvilHelper = new HelperConfig();
        HelperConfig.NetworkConfig memory activeConfig = anvilHelper.getActiveNetworkConfig();
        MockV3Aggregator priceFeed = MockV3Aggregator(activeConfig.priceFeed);

        int256 newPrice = 3000e8;
        priceFeed.updateAnswer(newPrice);

        (, int256 updatedPrice,,,) = priceFeed.latestRoundData();
        assertEq(updatedPrice, newPrice, "Price should be updated to $3000");
    }
}
