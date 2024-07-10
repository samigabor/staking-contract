# Staking Contract

Basic staking contract where:
- Users stake an ERC20.
- Owner funds the staking contract with ETH to be distributed.
- Users can claim ETH in relation the amount and time staked.

## Improvements

1. Allow anyone to fund the contract to increase reward pool:
   - Remove the onlyOwner modifier from `fundETHRewards` and `receive` functions.
2. Allow users to withdraw partial rewards:
    - if `rewards > address(this).balance` the `claimRewards` function reverts
3. Use SafeERC20 library from OpenZeppelin for safer token transfers:
   - SafeERC20 wraps the standard ERC20 functions (transfer, transferFrom, etc.) to handle the low-level call to the token contract
4. Improve coverage / add invariant testing
5. Implement a more sophisticated reward calculation that takes into account different staking periods and reward multipliers:
   - the current reward calculation is simple and linear, based solely on the amount staked and the time it has been staked
   - a more sophisticated calculation can involve different reward rates for different staking periods. For example, longer staking periods could have higher reward rates to incentivize long-term staking
   - this can be achieved by defining multiple reward tiers, where each tier corresponds to a different staking period and has a different reward rate.
6. Integrate ERC-4626 Tokenized Vault standard:
   - **assets** provided to the vault can be utilized in other yield-generating protocols (e.g. lending platforms, yield farms) to earn additional rewards
   - **tokenized shares** minted to users can be utilized in other DeFi protocols, providing additional yield opportunities or serving as collateral
   - leverage the security audits and community scrutiny of the ERC-4626 standard, reducing the risk of vulnerabilities

## Sepolia Deployment
- MockERC20 - [0xFD97fB4e074F5B5822A0d868093E82D29429d23c](https://sepolia.etherscan.io/address/0xFD97fB4e074F5B5822A0d868093E82D29429d23c#code)
- StakingContract - [0x705b9c2aFd015B1d4fBec7D7a95eedca7b0296E9](https://sepolia.etherscan.io/address/0x705b9c2aFd015B1d4fBec7D7a95eedca7b0296E9#code)

## Sepolia Interaction
- mint some MockERC20 tokens
- approve StakingContract to spend MockERC20 tokens
- stake MockERC20 tokens

**WARNING:**
- the contract has ~0.1ETH available for rewards
- deposit only a few tokens and see how the rewards accumulate (on stake/withdraw)
- depositing too many tokens which result in having the accruedReward > contract balance would make the `claimRewards` function revert (see improvement 2).
