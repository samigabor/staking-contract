// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {StakingContract} from "../src/StakingContract.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

uint256 constant REWARD_RATE = 1e12; // means ~1_000,000 tokens would earn 1 eth/s

contract DeployContracts is Script {

    /**
    @notice Deploy to anvil
        forge script script/DeployContracts.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

    @notice Deploy to sepolia (should verify the contracts automatically)
        forge script script/DeployContracts.s.sol \
        --rpc-url $RPC_URL_SEPOLIA \
        --broadcast \
        --private-key=$PRIVATE_KEY \
        --verify --etherscan-api-key $ETHERSCAN_API_KEY


    @notice Verify MockERC20 on etherscan (manually)
        forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(cast abi-encode "constructor(string,string)" "MockERC20" "ERC20") \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --optimizer-runs 200 \
        0xFD97fB4e074F5B5822A0d868093E82D29429d23c \
        src/MockERC20.sol:MockERC20

    @notice Verify StakingContract on etherscan (manually)
        forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(cast abi-encode "constructor(address,uint256)" 0xFD97fB4e074F5B5822A0d868093E82D29429d23c 1000000000000) \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --optimizer-runs 200 \
        0x705b9c2aFd015B1d4fBec7D7a95eedca7b0296E9 \
        src/StakingContract.sol:StakingContract
     */
    function run() external returns (/*MockERC20, */StakingContract, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        uint256 deployKey = helperConfig.config();

        vm.startBroadcast(deployKey);
        MockERC20 mockERC20 = new MockERC20("MockERC20", "ERC20");
        StakingContract stakingContract = new StakingContract(mockERC20, REWARD_RATE);
        vm.stopBroadcast();

        console.log("MockERC20 deployed at: ", address(mockERC20));
        console.log("StakingContract deployed at: ", address(stakingContract));
        
        return (/*mockERC20, */stakingContract, helperConfig);
    }
}
