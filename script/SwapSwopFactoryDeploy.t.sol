// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {SwapSwopFactory} from "../src/SwapSwopFactory.sol";

contract SwapSwopFactoryDeploy is Script {
    function run() public {
        uint256 deployPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployPrivateKey);
        SwapSwopFactory swapSwopFactory = new SwapSwopFactory();
        vm.stopBroadcast();

        console.log("SwapSwopFactory deployed to:", address(swapSwopFactory));
    }
}