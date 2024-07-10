// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/StakingContract.sol";
import "../src/MockERC20.sol";

contract StakingContractTest is Test {
    StakingContract public stakingContract;
    MockERC20 public stakingToken;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    uint256 public initialRewardRate = 1e18; // 1 token per second

    function setUp() public {
        vm.startPrank(owner);
        stakingToken = new MockERC20("Staking Token", "STK");
        stakingContract = new StakingContract(stakingToken, initialRewardRate);
        vm.stopPrank();

        // Mint 1000 tokens to users
        stakingToken.mint(user1, 1000e18);
        stakingToken.mint(user2, 1000e18);
    }

    function testFundETHRewards() public {
        vm.deal(owner, 10 ether);
        vm.startPrank(owner);
        stakingContract.fundETHRewards{value: 5 ether}();
        assertEq(address(stakingContract).balance, 5 ether);
        vm.stopPrank();
    }

    function testReceiveETH() public {
        vm.deal(owner, 1 ether);
        vm.startPrank(owner);
        (bool success,) = address(stakingContract).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(stakingContract).balance, 1 ether);
        vm.stopPrank();
    }

    function testRevertOnFundETHRewardsWithZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(StakingContract.InvalidAmount.selector);
        stakingContract.fundETHRewards{value: 0}();
    }

    function testStakeTokens() public {
        uint256 stakedAmount = 500e18;
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakedAmount);
        stakingContract.stake(stakedAmount);

        (uint256 amount, uint256 startTime, uint256 accruedReward) = stakingContract.s_stakes(user1);
        assertEq(amount, stakedAmount);
        assertEq(startTime, block.timestamp);
        assertEq(accruedReward, 0);
        vm.stopPrank();
    }

    function testRevertOnStakeZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(StakingContract.InvalidAmount.selector);
        stakingContract.stake(0);
    }

    function testWithdrawTokens() public {
        uint256 stakedAmount = 500e18;

        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakedAmount);
        stakingContract.stake(stakedAmount);
        vm.warp(block.timestamp + 100);

        stakingContract.withdraw(250e18);
        (uint256 amount, uint256 startTime, uint256 accruedReward) = stakingContract.s_stakes(user1);
        assertEq(amount, 250e18);
        assertEq(startTime, block.timestamp);
        assertEq(accruedReward, (stakedAmount * 100 * initialRewardRate) / 1e18);
        vm.stopPrank();
    }

    function testWithdrawAllTokensResetsStartTime() public {
        uint256 stakedAmount1 = 500e18;
        uint256 timePassed = 100;
        uint256 fundedEthRewards = stakedAmount1 * timePassed * initialRewardRate / 1e18;
        vm.deal(owner, fundedEthRewards);
        vm.startPrank(owner);
        stakingContract.fundETHRewards{value: fundedEthRewards}();
        vm.stopPrank();

        // User1 stakes 500 tokens
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakedAmount1);
        stakingContract.stake(stakedAmount1);
        vm.stopPrank();

        // Warp to simulate time passing
        vm.warp(block.timestamp + timePassed);

        // User1 withdraws all staked tokens
        vm.startPrank(user1);
        stakingContract.withdraw(stakedAmount1);
        (uint256 amount1, uint256 startTime1, uint256 accruedReward1) = stakingContract.s_stakes(user1);
        assertEq(amount1, 0);
        assertEq(startTime1, 0);
        assertEq(accruedReward1, (stakedAmount1 * timePassed * initialRewardRate) / 1e18);
        vm.stopPrank();
    }

    function testRevertOnWithdrawMoreThanStaked() public {
        uint256 stakedAmount = 500e18;
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakedAmount);
        stakingContract.stake(stakedAmount);
        vm.expectRevert(StakingContract.InsufficientStake.selector);
        stakingContract.withdraw(stakedAmount + 1);
        vm.stopPrank();
    }

    function testClaimRewards() public {
        uint256 stakedAmount = 500e18;

        vm.deal(owner, 50000 ether);
        vm.startPrank(owner);
        stakingContract.fundETHRewards{value: 50000 ether}();
        vm.stopPrank();

        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakedAmount);
        stakingContract.stake(stakedAmount);
        vm.warp(block.timestamp + 100);

        stakingContract.claimRewards();
        (uint256 amount, uint256 startTime, uint256 accruedReward) = stakingContract.s_stakes(user1);
        assertEq(amount, stakedAmount);
        assertEq(startTime, block.timestamp);
        assertEq(accruedReward, 0);

        uint256 expectedRewards = (stakedAmount * 100 * initialRewardRate) / 1e18; // 50,000 eth at 1 eth per second
        assertEq(user1.balance, expectedRewards);
        vm.stopPrank();
    }

    function testRevertOnClaimRewardsMoreThanEthBalance() public {
        uint256 stakedAmount = 500e18;

        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakedAmount);
        stakingContract.stake(stakedAmount);
        vm.warp(block.timestamp + 100);

        vm.expectRevert(StakingContract.InsufficientETHRewards.selector);
        stakingContract.claimRewards();
        vm.stopPrank();
    }

    function testMultipleUsersStakingDifferentAmountsAtDifferentIntervals() public {
        uint256 stakedAmount1 = 500e18;
        uint256 stakedAmount2 = 1000e18;
        uint256 timePassed1 = 100;
        uint256 timePassed2 = 200;
        uint256 fundedEthRewards =
            ((stakedAmount1 * (timePassed1 + timePassed2)) + (stakedAmount2 * timePassed2)) * initialRewardRate / 1e18;
        vm.deal(owner, fundedEthRewards);
        vm.startPrank(owner);
        stakingContract.fundETHRewards{value: fundedEthRewards}();
        vm.stopPrank();

        // User1 stakes 500 tokens
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakedAmount1);
        stakingContract.stake(stakedAmount1);
        vm.stopPrank();

        // Warp to simulate time passing for User1
        vm.warp(block.timestamp + timePassed1);

        // User2 stakes 1000 tokens
        vm.startPrank(user2);
        stakingToken.approve(address(stakingContract), stakedAmount2);
        stakingContract.stake(stakedAmount2);
        vm.stopPrank();

        // Warp to simulate more time passing for both users
        vm.warp(block.timestamp + timePassed2);

        // User1 claims rewards
        vm.startPrank(user1);
        stakingContract.claimRewards();
        (uint256 amount1, uint256 startTime1, uint256 accruedReward1) = stakingContract.s_stakes(user1);
        assertEq(amount1, stakedAmount1);
        assertEq(startTime1, block.timestamp);
        assertEq(accruedReward1, 0);
        uint256 expectedRewardsUser1 = (stakedAmount1 * (timePassed1 + timePassed2) * initialRewardRate) / 1e18; // 500 * (100 + 200) * 1 = 150,000
        assertEq(user1.balance, expectedRewardsUser1);
        vm.stopPrank();

        // User2 claims rewards
        vm.startPrank(user2);
        stakingContract.claimRewards();
        (uint256 amount2, uint256 startTime2, uint256 accruedReward2) = stakingContract.s_stakes(user2);
        assertEq(amount2, stakedAmount2);
        assertEq(startTime2, block.timestamp);
        assertEq(accruedReward2, 0);
        uint256 expectedRewardsUser2 = (stakedAmount2 * timePassed2 * initialRewardRate) / 1e18; // 1000 * 200 * 1 = 200,000
        assertEq(user2.balance, expectedRewardsUser2);
        vm.stopPrank();
    }
}
