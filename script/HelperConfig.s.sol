// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";

contract HelperConfig is Script {
    struct Config {
        uint256 deployKey;
    }

    Config public config;

    constructor() {
        if (block.chainid == 31337) {
            config = Config({
                deployKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 // first account on Anvil
            });
        } else {
            config = Config({ // sepolia chain id = 11155111
                deployKey: vm.envUint("PRIVATE_KEY")
            });
        }
    }
}
