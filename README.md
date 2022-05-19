# Harvest & Dolomite Strategy Development

This [Hardhat](https://hardhat.org/) environment is configured to use an Arbitrum One fork by default and provides
templates and utilities for strategy development and testing.

Aside from forking Harvest Finance core contracts on Arbitrum One, this repository integrates
the [DolomiteMargin](https://github.com/dolomite-exchange/dolomite-margin) Protocol to enable leveraged yield farming.

## Installation

1. Run `npm install` to install all the dependencies.
2. Sign up on [Infura](https://infura.io/register). We recommend using Infura to allow for a reproducible Arbitrum One
   testing environment as well as efficiency due to caching.
3. Create a file `.env`:

  ```
   ETHERSCAN_API_KEY=<YOUR KEY>
   INFURA_API_KEY=<YOUR KEY>
   STRATEGIST=0x123...321
  ```

## Run

All tests are located under the `test` folder.

1. In a desired test file (e.g., `./test/strategies/usdt-stargate.js`), look for the protocol setup:
    ```
   let core: CoreProtocol;
   ...
    core = await setupCoreProtocol({
      ...CoreProtocolSetupConfigV2,
      blockNumber: 8958800, // use the block number applicable to your testing
    });
    ```
   The block number is often necessary because many tests depend on the blockchain state at a given time. For example,
   for using whale accounts that are no longer such at the most recent block, or for time-sensitive activities like
   migrations. In addition, specifying block number speeds up tests due to caching.

2. Run `npx hardhat test [test file location]`: `npx hardhat test ./test/strategies/stargate/usdt-stargate.test.ts` (if
   for some reason the NodeJS heap runs out of memory, make sure to explicitly increase its size
   via `export NODE_OPTIONS=--max_old_space_size=4096`). This will produce output:

## Develop

Under `contracts/strategies`, there are plenty of examples to choose from in the repository already, therefore, creating
a strategy is no longer a complicated task. Copy-pasting existing strategies with minor modifications is acceptable.

Under `contracts/base`, there are existing base interfaces and contracts that can speed up development. To start with
creating a strategy, extend your new strategy from `BaseUpgradeableStrategy.sol`

There are a few abstract functions you need to implement in order to complete your strategy:

```solidity
   /**
     * @dev Called after the upgrade is finalized and `nextImplementation` is set back to null. This function is called
     *      for the sake of clean up, so any new state that needs to be set can be done.
     */
    function _finalizeUpgrade() internal;
```

```solidity
    /**
     * @dev Withdraws all earned rewards from the reward pool(s)
     */
    function _claimRewards() internal;
```

```solidity
    /**
     * @return The balance of `underlying()` in `rewardPool()`
     */
    function _rewardPoolBalance() internal view returns (uint);
```

```solidity
    /**
     * @dev Liquidates reward tokens for `underlying`
     */
    function _liquidateReward() internal;
```

```solidity
    /**
     * @dev Withdraws `_amount` of `underlying()` from the `rewardPool()` to this contract. Does not attempt to claim
     *      any rewards
     */
    function _partialExitRewardPool(uint256 _amount) internal;
```

```solidity
    /**
     * @dev Deposits underlying token into the yield-earning contract.
     */
    function _enterRewardPool() internal;
```

Once the abstract functions are implemented and tested, you're ready to move on to contributing to this GitHub
repository!

**Don't be a hero if you don't need to be!**

There also are some utility functions you should use to speed up development. These functions are well-tested and reduce
the surface area for you tests too. For example:

```solidity
    /**
     * @dev Same as `_notifyProfitAndBuybackInRewardToken` but does not perform a compounding buyback. Just takes fees
     *      instead.
     */
    function _notifyProfitInRewardToken(
        address _rewardToken,
        uint256 _rewardBalance
    ) internal;
```

```solidity
    /**
     * @param _rewardToken      The token that will be sold into `_buybackTokens`
     * @param _rewardBalance    The amount of `_rewardToken` to be sold into `_buybackTokens`
     * @param _buybackTokens    The tokens to be bought back by the protocol and sent back to this strategy contract.
     *                          Calling this function automatically sends the appropriate amounts to the strategist,
     *                          profit share and platform
     * @return The amounts bought back of each buyback token. Each index in the array corresponds with `_buybackTokens`.
     */
    function _notifyProfitAndBuybackInRewardToken(
        address _rewardToken,
        uint256 _rewardBalance,
        address[] memory _buybackTokens
    ) internal returns (uint[] memory);
```

```solidity
    /**
     * @param _rewardToken      The token that will be sold into `_buybackTokens`
     * @param _rewardBalance    The amount of `_rewardToken` to be sold into `_buybackTokens`
     * @param _buybackTokens    The tokens to be bought back by the protocol and sent back to this strategy contract.
     *                          Calling this function automatically sends the appropriate amounts to the strategist,
     *                          profit share and platform
     * @param _weights          The weights to be applied for each buybackToken. For example [100, 300] applies 25% to
     *                          buybackTokens[0] and 75% to buybackTokens[1]
     * @return The amounts bought back of each buyback token. Each index in the array corresponds with `_buybackTokens`.
     */
    function _notifyProfitAndBuybackInRewardTokenWithWeights(
        address _rewardToken,
        uint256 _rewardBalance,
        address[] memory _buybackTokens,
        uint[] memory _weights
    ) internal returns (uint[] memory);
```

## Contribute

When ready, open a pull request with the following information:

- Info about the protocol, including:
    - Live farm page(s)
    - GitHub link(s)
    - Etherscan link(s)
    - Start/end dates for rewards
    - Any limitations (e.g., maximum pool size)
    - Current Uniswap/Sushiswap/etc. pool sizes used for liquidation (to make sure they are not too shallow)
    - The first few items can be omitted for well-known protocols (such as `curve.fi`).
- A description of **potential value** for Harvest: why should your strategy be live? High APYs, decent pool sizes,
  longevity of rewards, well-secured protocols, high-potential collaborations, etc.
- A strategist address that will be used to redirect strategist fees to (currently 5% of compounded yield at the time of
  writing).

## Deployment

If your pull request is merged and given a green light for deployment, the Harvest team will take care of on-chain
deployment. Alternatively, you can deploy the strategy yourself with the strategist address already set. Note, deploying
it yourself is more trustless but may slow down our integration, since we need to check over the on-chain deployment for
any code diffs. If you deploy the strategy yourself, you must also verify the contracts so the source code can be
checked.  
