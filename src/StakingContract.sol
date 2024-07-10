// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StakingContract
 * @dev This contract allows users to stake an ERC20 token and claim ETH rewards based on the amount and duration of their stake.
 */
contract StakingContract is Ownable {
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 accruedReward;
    }

    ERC20 public immutable s_stakingToken;
    uint256 public s_totalStaked;
    uint256 public s_rewardRatePerTokenPerSecond; // scaled to 18 decimals for precision (e.g. wei amount)
    mapping(address => StakeInfo) public s_stakes;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event EthReceived(address indexed sender, uint256 amount);

    // Custom errors
    error NoActiveStake();
    error InsufficientStake();
    error InsufficientETHRewards();
    error InvalidAmount();
    error TransferFailed();

    /**
     * @dev Check if the user has an active stake.
     */
    modifier hasStake(address _user) {
        if (s_stakes[_user].amount == 0) {
            revert NoActiveStake();
        }
        _;
    }

    /**
     * @dev Initializes the contract with the staking token address and the reward rate.
     * @param _stakingToken Address of the ERC20 token to be staked.
     * @param _rewardRatePerTokenPerSecond Reward rate per token per second (scaled to 18 decimals for precision).
     */
    constructor(ERC20 _stakingToken, uint256 _rewardRatePerTokenPerSecond) Ownable(msg.sender) {
        s_stakingToken = _stakingToken;
        s_rewardRatePerTokenPerSecond = _rewardRatePerTokenPerSecond;
    }

    /**
     * @notice Allows the owner to fund the contract with ETH rewards.
     * @dev This function can only be called by the owner.
     */
    function fundETHRewards() external payable onlyOwner {
        if (msg.value == 0) {
            revert InvalidAmount();
        }
        emit EthReceived(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to stake a specified amount of the ERC20 token.
     * @param _amount Amount of tokens to stake.
     */
    function stake(uint256 _amount) external {
        if (_amount == 0) {
            revert InvalidAmount();
        }

        bool success = s_stakingToken.transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert TransferFailed();
        }

        StakeInfo memory stakeInfo = s_stakes[msg.sender];
        stakeInfo.accruedReward += _calculateNewRewards(msg.sender);
        stakeInfo.amount += _amount;
        stakeInfo.startTime = block.timestamp;

        s_stakes[msg.sender] = stakeInfo;
        s_totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    /**
     * @notice Allows users to withdraw their staked tokens.
     * @param _amount Amount of tokens to withdraw.
     */
    function withdraw(uint256 _amount) external hasStake(msg.sender) {
        StakeInfo memory stakeInfo = s_stakes[msg.sender];
        if (_amount > stakeInfo.amount) {
            revert InsufficientStake();
        }

        stakeInfo.accruedReward += _calculateNewRewards(msg.sender);
        stakeInfo.amount -= _amount;
        if (stakeInfo.amount == 0) {
            stakeInfo.startTime = 0;
        } else {
            stakeInfo.startTime = block.timestamp;
        }

        s_stakes[msg.sender] = stakeInfo;
        s_totalStaked -= _amount;
        bool success = s_stakingToken.transfer(msg.sender, _amount);
        if (!success) {
            revert TransferFailed();
        }

        emit Withdrawn(msg.sender, _amount);
    }

    /**
     * @notice Allows users to claim their accrued ETH rewards.
     */
    function claimRewards() external hasStake(msg.sender) {
        StakeInfo memory stakeInfo = s_stakes[msg.sender];
        uint256 rewards = _calculateNewRewards(msg.sender) + stakeInfo.accruedReward;

        if (rewards > address(this).balance) {
            revert InsufficientETHRewards();
        }

        stakeInfo.accruedReward = 0; // Reset accruedReward after claiming
        stakeInfo.startTime = block.timestamp;
        s_stakes[msg.sender] = stakeInfo;

        (bool success,) = payable(msg.sender).call{value: rewards}("");
        if (!success) {
            revert TransferFailed();
        }

        emit RewardsClaimed(msg.sender, rewards);
    }

    /**
     * @dev Internal function to calculate the new rewards for a user since the last update.
     * @param _user Address of the user to calculate rewards for.
     * @return The newly calculated rewards.
     */
    function _calculateNewRewards(address _user) internal view returns (uint256) {
        StakeInfo memory stakeInfo = s_stakes[_user];
        if (stakeInfo.amount == 0) {
            return 0;
        }

        uint256 stakingDuration = block.timestamp - stakeInfo.startTime;
        return (stakeInfo.amount * stakingDuration * s_rewardRatePerTokenPerSecond) / 1e18;
    }

    /**
     * @notice Fallback function to ensure ETH sent directly to the contract is accounted for.
     * @dev This function can only be called by the owner (e.g. only owner can send eth at this address).
     * ETH can also be sent by using this contract as a destination of a `selfdestruct`
     *  which means the onlyOwner guard will not be enforced and no event will be emitted as well.
     */
    receive() external payable onlyOwner {
        emit EthReceived(msg.sender, msg.value);
    }
}
