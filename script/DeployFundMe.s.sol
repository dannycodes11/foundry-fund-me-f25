// SPDX-License-Identifier: MIT    
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployFundMe is Script {
    function run() external returns (FundMe) {
        // before startbroadcast not a real transaction
        HelperConfig helperConfig = new HelperConfig();

        // FIX: activeNetworkConfig() already returns the address
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();

        // after startbroadcast is a real transaction
        vm.startBroadcast();

        // deploy FundMe and store the instance
        FundMe fundMe = new FundMe(ethUsdPriceFeed);
        vm.stopBroadcast();

        return fundMe; // return the deployed instance
    }
}