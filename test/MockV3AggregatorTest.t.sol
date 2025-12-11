// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract MockV3AggregatorTest is Test {
    MockV3Aggregator public mockAggregator;

    uint8 constant DECIMALS = 8;
    int256 constant INITIAL_ANSWER = 2000e8; // $2000 with 8 decimals

    function setUp() external {
        mockAggregator = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructorSetsDecimalsCorrectly() public view {
        assertEq(mockAggregator.decimals(), DECIMALS);
    }

    function testConstructorSetsInitialAnswerCorrectly() public view {
        assertEq(mockAggregator.latestAnswer(), INITIAL_ANSWER);
    }

    function testConstructorInitializesFirstRound() public view {
        assertEq(mockAggregator.latestRound(), 1, "First round should be 1");
    }

    function testConstructorSetsTimestamp() public view {
        assertEq(mockAggregator.latestTimestamp(), block.timestamp);
    }

    function testConstructorWithDifferentDecimals() public {
        MockV3Aggregator mock18 = new MockV3Aggregator(18, 2000e18);
        assertEq(mock18.decimals(), 18);
        assertEq(mock18.latestAnswer(), 2000e18);
    }

    function testConstructorWithZeroInitialAnswer() public {
        MockV3Aggregator mockZero = new MockV3Aggregator(8, 0);
        assertEq(mockZero.latestAnswer(), 0);
    }

    function testConstructorWithNegativeInitialAnswer() public {
        int256 negativeAnswer = -100e8;
        MockV3Aggregator mockNegative = new MockV3Aggregator(8, negativeAnswer);
        assertEq(mockNegative.latestAnswer(), negativeAnswer);
    }

    /*//////////////////////////////////////////////////////////////
                        VERSION TESTS
    //////////////////////////////////////////////////////////////*/

    function testVersionReturns4() public view {
        assertEq(mockAggregator.version(), 4);
    }

    function testVersionIsConstant() public {
        // Create multiple instances and verify version is always 4
        MockV3Aggregator mock1 = new MockV3Aggregator(8, 1000e8);
        MockV3Aggregator mock2 = new MockV3Aggregator(18, 5000e18);

        assertEq(mock1.version(), 4);
        assertEq(mock2.version(), 4);
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE ANSWER TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpdateAnswerChangesLatestAnswer() public {
        int256 newAnswer = 3000e8;
        mockAggregator.updateAnswer(newAnswer);

        assertEq(mockAggregator.latestAnswer(), newAnswer);
    }

    function testUpdateAnswerIncrementsRound() public {
        uint256 initialRound = mockAggregator.latestRound();

        mockAggregator.updateAnswer(3000e8);

        assertEq(mockAggregator.latestRound(), initialRound + 1);
    }

    function testUpdateAnswerUpdatesTimestamp() public {
        uint256 initialTimestamp = mockAggregator.latestTimestamp();

        vm.warp(block.timestamp + 100); // Move time forward
        mockAggregator.updateAnswer(3000e8);

        assertGt(mockAggregator.latestTimestamp(), initialTimestamp);
        assertEq(mockAggregator.latestTimestamp(), block.timestamp);
    }

    function testUpdateAnswerMultipleTimes() public {
        mockAggregator.updateAnswer(3000e8);
        assertEq(mockAggregator.latestAnswer(), 3000e8);
        assertEq(mockAggregator.latestRound(), 2);

        mockAggregator.updateAnswer(4000e8);
        assertEq(mockAggregator.latestAnswer(), 4000e8);
        assertEq(mockAggregator.latestRound(), 3);

        mockAggregator.updateAnswer(5000e8);
        assertEq(mockAggregator.latestAnswer(), 5000e8);
        assertEq(mockAggregator.latestRound(), 4);
    }

    function testUpdateAnswerWithZero() public {
        mockAggregator.updateAnswer(0);
        assertEq(mockAggregator.latestAnswer(), 0);
    }

    function testUpdateAnswerWithNegativeValue() public {
        int256 negativeAnswer = -500e8;
        mockAggregator.updateAnswer(negativeAnswer);
        assertEq(mockAggregator.latestAnswer(), negativeAnswer);
    }

    function testUpdateAnswerStoresAnswerInMapping() public {
        int256 newAnswer = 3500e8;
        mockAggregator.updateAnswer(newAnswer);

        uint256 currentRound = mockAggregator.latestRound();
        assertEq(mockAggregator.getAnswer(currentRound), newAnswer);
    }

    function testUpdateAnswerStoresTimestampInMapping() public {
        vm.warp(block.timestamp + 200);
        mockAggregator.updateAnswer(3500e8);

        uint256 currentRound = mockAggregator.latestRound();
        assertEq(mockAggregator.getTimestamp(currentRound), block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        LATEST ROUND DATA TESTS
    //////////////////////////////////////////////////////////////*/

    function testLatestRoundDataReturnsCorrectValues() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            mockAggregator.latestRoundData();

        assertEq(roundId, 1);
        assertEq(answer, INITIAL_ANSWER);
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }

    function testLatestRoundDataAfterUpdate() public {
        int256 newAnswer = 3500e8;
        vm.warp(block.timestamp + 100);
        mockAggregator.updateAnswer(newAnswer);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            mockAggregator.latestRoundData();

        assertEq(roundId, 2);
        assertEq(answer, newAnswer);
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 2);
    }

    function testLatestRoundDataReturnsLatestAfterMultipleUpdates() public {
        mockAggregator.updateAnswer(3000e8);
        mockAggregator.updateAnswer(4000e8);
        mockAggregator.updateAnswer(5000e8);

        (, int256 answer,,,) = mockAggregator.latestRoundData();

        assertEq(answer, 5000e8, "Should return the most recent answer");
    }

    /*//////////////////////////////////////////////////////////////
                        GET ROUND DATA TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetRoundDataForSpecificRound() public {
        // Update to create round 2
        vm.warp(block.timestamp + 50);
        mockAggregator.updateAnswer(3000e8);

        // Update to create round 3
        vm.warp(block.timestamp + 100);
        mockAggregator.updateAnswer(4000e8);

        // Get data for round 2
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            mockAggregator.getRoundData(2);

        assertEq(roundId, 2);
        assertEq(answer, 3000e8);
        assertEq(answeredInRound, 2);
    }

    function testGetRoundDataForRound1() public view {
        (uint80 roundId, int256 answer,,,) = mockAggregator.getRoundData(1);

        assertEq(roundId, 1);
        assertEq(answer, INITIAL_ANSWER);
    }

    function testGetRoundDataForNonExistentRound() public view {
        // Should return zero values for rounds that don't exist
        (uint80 roundId, int256 answer,,,) = mockAggregator.getRoundData(999);

        assertEq(roundId, 999);
        assertEq(answer, 0); // No data stored for this round
    }

    /*//////////////////////////////////////////////////////////////
                        UPDATE ROUND DATA TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpdateRoundDataSetsAllValues() public {
        uint80 roundId = 5;
        int256 answer = 6000e8;
        uint256 timestamp = block.timestamp + 1000;
        uint256 startedAt = block.timestamp + 900;

        mockAggregator.updateRoundData(roundId, answer, timestamp, startedAt);

        assertEq(mockAggregator.latestRound(), roundId);
        assertEq(mockAggregator.latestAnswer(), answer);
        assertEq(mockAggregator.latestTimestamp(), timestamp);
    }

    function testUpdateRoundDataCanBeRetrievedWithGetRoundData() public {
        uint80 roundId = 10;
        int256 answer = 7500e8;
        uint256 timestamp = block.timestamp + 500;
        uint256 startedAt = block.timestamp + 400;

        mockAggregator.updateRoundData(roundId, answer, timestamp, startedAt);

        (
            uint80 returnedRoundId,
            int256 returnedAnswer,
            uint256 returnedStartedAt,
            uint256 returnedUpdatedAt,
            uint80 returnedAnsweredInRound
        ) = mockAggregator.getRoundData(roundId);

        assertEq(returnedRoundId, roundId);
        assertEq(returnedAnswer, answer);
        assertEq(returnedStartedAt, startedAt);
        assertEq(returnedUpdatedAt, timestamp);
        assertEq(returnedAnsweredInRound, roundId);
    }

    // function testUpdateRoundDataWithBackdatedRound() public {
    //     // Current round is 1, update to round 5
    //     mockAggregator.updateRoundData(5, 5000e8, block.timestamp, block.timestamp);
    //     assertEq(mockAggregator.latestRound(), 5);

    //     // Update to round 3 (backdated)
    //     mockAggregator.updateRoundData(3, 3000e8, block.timestamp - 100, block.timestamp - 100);

    //     // Latest round should now be 3 (as set by updateRoundData)
    //     assertEq(mockAggregator.latestRound(), 3);
    //     assertEq(mockAggregator.latestAnswer(), 3000e8);
    // }

    /*//////////////////////////////////////////////////////////////
                        DESCRIPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testDescriptionReturnsCorrectString() public view {
        string memory desc = mockAggregator.description();
        assertEq(desc, "v0.6/test/mock/MockV3Aggregator.sol");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testPriceSimulation() public {
        // Simulate a price feed over time
        int256[] memory prices = new int256[](5);
        prices[0] = 2000e8;
        prices[1] = 2100e8;
        prices[2] = 2050e8;
        prices[3] = 2200e8;
        prices[4] = 2150e8;

        for (uint256 i = 1; i < prices.length; i++) {
            vm.warp(block.timestamp + 60); // 1 minute intervals
            mockAggregator.updateAnswer(prices[i]);
        }

        // Verify latest price
        (, int256 latestPrice,,,) = mockAggregator.latestRoundData();
        assertEq(latestPrice, prices[4]);

        // Verify round count
        assertEq(mockAggregator.latestRound(), 5);
    }

    function testHistoricalDataRetrieval() public {
        // Create historical data
        int256[] memory historicalPrices = new int256[](3);
        historicalPrices[0] = INITIAL_ANSWER; // Round 1
        historicalPrices[1] = 3000e8; // Round 2
        historicalPrices[2] = 4000e8; // Round 3

        mockAggregator.updateAnswer(historicalPrices[1]);
        mockAggregator.updateAnswer(historicalPrices[2]);

        // Retrieve historical data
        for (uint80 i = 1; i <= 3; i++) {
            (, int256 answer,,,) = mockAggregator.getRoundData(i);
            assertEq(answer, historicalPrices[i - 1]);
        }
    }

    function testVolatilePriceChanges() public {
        // Test large price swings
        mockAggregator.updateAnswer(10000e8); // +400%
        assertEq(mockAggregator.latestAnswer(), 10000e8);

        mockAggregator.updateAnswer(1000e8); // -90%
        assertEq(mockAggregator.latestAnswer(), 1000e8);

        mockAggregator.updateAnswer(-500e8); // Negative price
        assertEq(mockAggregator.latestAnswer(), -500e8);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzzUpdateAnswer(int256 randomAnswer) public {
        mockAggregator.updateAnswer(randomAnswer);
        assertEq(mockAggregator.latestAnswer(), randomAnswer);
    }

    function testFuzzUpdateAnswerMultipleTimes(int256[5] memory answers) public {
        for (uint256 i = 0; i < answers.length; i++) {
            mockAggregator.updateAnswer(answers[i]);
        }

        assertEq(mockAggregator.latestAnswer(), answers[4]);
        assertEq(mockAggregator.latestRound(), 1 + answers.length);
    }

    function testFuzzUpdateRoundData(uint80 roundId, int256 answer, uint256 timestamp, uint256 startedAt) public {
        mockAggregator.updateRoundData(roundId, answer, timestamp, startedAt);

        assertEq(mockAggregator.latestRound(), roundId);
        assertEq(mockAggregator.latestAnswer(), answer);
        assertEq(mockAggregator.latestTimestamp(), timestamp);
    }
}
