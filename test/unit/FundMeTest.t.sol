// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); // Create a test user
    uint256 constant SEND_VALUE = 0.1 ether; // Standard send value
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // Deploy using your script
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        // Give USER some starting balance
        vm.deal(USER, STARTING_BALANCE);
    }
    
    /*//////////////////////////////////////////////////////////////
                        BASIC FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        if (block.chainid == 11155111) {
            uint256 version = fundMe.getVersion();
            assertEq(version, 4);
        } else if (block.chainid == 1) {
            uint256 version = fundMe.getVersion();
            assertEq(version, 6);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            FUNDING TESTS
    //////////////////////////////////////////////////////////////*/

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert("You need to spend more ETH!");
        fundMe.fund(); // Attempt to fund without sending enough ETH
    }

    function testFundSucceedsWithEnoughEth() public {
        // Use USER instead of address(this)
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        
        assertEq(fundMe.getAddressToAmountFunded(USER), SEND_VALUE);
    }

    function testFundUpdateFundedDataStructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testTwoDifferentPeopleCanFund() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);

        vm.prank(alice);
        fundMe.fund{value: SEND_VALUE}();
        
        vm.prank(bob);
        fundMe.fund{value: SEND_VALUE * 2}();

        assertEq(fundMe.getFunder(0), alice);
        assertEq(fundMe.getFunder(1), bob);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testOnlyOwnerCanWithdraw() public funded {
        address notOwner = makeAddr("notOwner");
        
        vm.prank(notOwner);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithSingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(endingOwnerBalance, startingOwnerBalance + startingFundMeBalance);
    }

    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        
        for (uint160 i = startingFunderIndex; i < numberOfFunders + startingFunderIndex; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
    }

    function testOnlyOwnerCanWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;

        for (uint160 i = 1; i <= numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        // Act / Assert
        address notOwner = makeAddr("notOwner");
        vm.prank(notOwner);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawResetsMappingAndArray() public funded {
        // Arrange - already funded by modifier
        
        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        assertEq(fundMe.getAddressToAmountFunded(USER), 0);
        
        vm.expectRevert(); // array is now empty
        fundMe.getFunder(0);
    }

    /*//////////////////////////////////////////////////////////////
                    CHEAPER WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testCheaperWithdrawWorks() public funded {
        // Act
        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        
        // Assert
        assertEq(address(fundMe).balance, 0);
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;
        
        for (uint160 i = startingFunderIndex; i < numberOfFunders + startingFunderIndex; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
    }

    function testOnlyOwnerCanCheaperWithdraw() public funded {
        address notOwner = makeAddr("notOwner");
        
        vm.prank(notOwner);
        vm.expectRevert();
        fundMe.cheaperWithdraw();
    }

    /*//////////////////////////////////////////////////////////////
                        GAS COMPARISON TEST
    //////////////////////////////////////////////////////////////*/

    function testCompareWithdrawGasCosts() public {
        // Setup: Fund with multiple people
        uint160 numberOfFunders = 10;
        
        for (uint160 i = 1; i <= numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        // Snapshot for gas comparison
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();
        uint256 gasEnd = gasleft();
        
        uint256 gasUsedWithdraw = (gasStart - gasEnd) * tx.gasprice;
        console.log("withdraw() gas used:", gasUsedWithdraw);

        // Reset and test cheaperWithdraw
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        
        for (uint160 i = 1; i <= numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();
        gasEnd = gasleft();
        
        uint256 gasUsedCheaperWithdraw = (gasStart - gasEnd) * tx.gasprice;
        console.log("cheaperWithdraw() gas used:", gasUsedCheaperWithdraw);
        console.log("Gas saved:", gasUsedWithdraw - gasUsedCheaperWithdraw);

        // Verify cheaper is actually cheaper
        assert(gasUsedCheaperWithdraw < gasUsedWithdraw);
    }
}