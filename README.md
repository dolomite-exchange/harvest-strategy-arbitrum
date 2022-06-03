# Harvest & Dolomite Strategy Development

This [Hardhat](https://hardhat.org/) environment is configured to use an Arbitrum One fork by default and provides
templates and utilities for strategy development and testing.

Aside from forking Harvest Finance core contracts on Arbitrum One, this repository integrates
the [DolomiteMargin](https://github.com/dolomite-exchange/dolomite-margin) Protocol to enable leveraged yield farming.

## Installation

1. Run `yarn install` to install all the dependencies.
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

2. Run `hardhat test [test file location]`: `hardhat test ./test/strategies/stargate/usdt-stargate.test.ts` (if
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


## Core Arbitrum Deployment
| Name                    | Explorer                                                               |
|-------------------------|------------------------------------------------------------------------|
| ControllerV1            | https://arbiscan.io/address/0xD5C5017659Af1E53b48aE9d55b02756342A7d4fF |
| Governor (owner)        | https://arbiscan.io/address/0xb39710a1309847363b9cBE5085E427cc2cAeE563 |
| ProfitSharingReceiverV1 | https://arbiscan.io/address/0x5F11EfDF4422B548007Cae9919b0b38c35fa6BE7 |
| RewardForwarderV1       | https://arbiscan.io/address/0x26B27e13E38FA8F8e43B8fc3Ff7C601A8aA0D032 |
| Storage                 | https://arbiscan.io/address/0xc1234a98617385D1a4b87274465375409f7E248f |
| UniversalLiquidator     | https://arbiscan.io/address/0xe5dcf0eB836adb04FF58A472B6924fE941c4Fe76 |

## Strategies Arbitrum Deployment

These contract addresses are taken from the [deployments.json](./scripts/deployments.json) file.

| Name                                       | Explorer                                                               |
|--------------------------------------------|------------------------------------------------------------------------|
| EursUsdPoolStrategyMainnet:RewardPool      | https://arbiscan.io/address/0xF20F44cFDa60A85f110e46019E411510b1D25b96 |
| EursUsdPoolStrategyMainnet:Strategy        | https://arbiscan.io/address/0x85b589ed03bFf4969fB821ECd8a61d3e5DfFc0f2 |
| EursUsdPoolStrategyMainnet:Vault           | https://arbiscan.io/address/0x09C29F5e64636487dD1DD851B994fa0AdE73A1bd |
| RenWbtcPoolStrategyMainnet:RewardPool      | https://arbiscan.io/address/0x6770A1c55487595D17383719dcE1Cd80f19D83bB |
| RenWbtcPoolStrategyMainnet:Strategy        | https://arbiscan.io/address/0xECC3CeDA34e3B61Dc6d1d00F69DB1b50d0C62332 |
| RenWbtcPoolStrategyMainnet:Vault           | https://arbiscan.io/address/0xBB9864A9bb3341818F061Cce305aa82b0cF5B3A3 |
| TriCryptoStrategyMainnet:RewardPool        | https://arbiscan.io/address/0x35d528f9255AdD4B02F5443910bbFAE649AE967b |
| TriCryptoStrategyMainnet:Strategy          | https://arbiscan.io/address/0xa603Ee4c897d5C241f22A2541f07415F0d5d0618 |
| TriCryptoStrategyMainnet:Vault             | https://arbiscan.io/address/0xcF1F62c17fcd5027d6810D76697F228FE44074FD |
| TwoPoolStrategyMainnet:RewardPool          | https://arbiscan.io/address/0x5b18B7c36f6B77731e1875159111A5646C1e33Db |
| TwoPoolStrategyMainnet:Strategy            | https://arbiscan.io/address/0xEfcF4AB8298010E1E4059F46a054de5e0f89EE52 |
| TwoPoolStrategyMainnet:Vault               | https://arbiscan.io/address/0x7FEBd439C00339C377031001048B556C085f100E |
| UsdcStargateStrategyMainnet:RewardPool     | https://arbiscan.io/address/0xE956110f4e937d59C2163778c4341D24254d90b0 |
| UsdcStargateStrategyMainnet:Strategy       | https://arbiscan.io/address/0xd6d33AD0504C3767832a96D7e2De088270407E9D |
| UsdcStargateStrategyMainnet:Vault          | https://arbiscan.io/address/0xfC2640ca71B1724B89dc2714E661B0089f8c0EED |
| ~~UsdtStargateStrategyMainnet:RewardPool~~ | https://arbiscan.io/address/0xEcE1821b2c448D472B432C9e9Fd15ECF5FbBE223 |
| ~~UsdtStargateStrategyMainnet:Strategy~~   | https://arbiscan.io/address/0x73FCe9666F2E162Aa7AA99B5F3B0929D2bE28558 |
| ~~UsdtStargateStrategyMainnet:Vault~~      | https://arbiscan.io/address/0x6d8ed5dace7C74e2d83AE09bB29d548c964EEBc5 |
| EthDaiSushiStrategyMainnet:RewardPool      | https://arbiscan.io/address/0xa84ACc69Ee857a5d90ccF8bc82ba5d21b013719f |
| EthDaiSushiStrategyMainnet:Strategy        | https://arbiscan.io/address/0xe77171dcA61bF6b4377ed38ca56Cb70c03a5DAF7 |
| EthDaiSushiStrategyMainnet:Vault           | https://arbiscan.io/address/0xc6f4A360732a53Cec7b7f2eF82F9DB34dF3593A7 |
| EthGOhmSushiStrategyMainnet:RewardPool     | https://arbiscan.io/address/0x19C48D421dD08A90E51Ef0a267472Cdc549636f7 |
| EthGOhmSushiStrategyMainnet:Strategy       | https://arbiscan.io/address/0x676275b94490B7a5E3C7B50d99BEc7D00Df8D450 |
| EthGOhmSushiStrategyMainnet:Vault          | https://arbiscan.io/address/0x49C0658d101b637E23f96b4334aECB193eD3E3d2 |
| EthMagicSushiStrategyMainnet:RewardPool    | https://arbiscan.io/address/0x02E886C2FC510C958b468d85544485DdD9133fC5 |
| EthMagicSushiStrategyMainnet:Strategy      | https://arbiscan.io/address/0x357fCEed8335d4842777796092F76a489b34cbB5 |
| EthMagicSushiStrategyMainnet:Vault         | https://arbiscan.io/address/0x358cDb55B3bc792d51190Cf4D3B6C8ABa450f863 |
| EthMimSushiStrategyMainnet:RewardPool      | https://arbiscan.io/address/0xbE780F8e75a545861AEcE86C18e6653fb3A62E89 |
| EthMimSushiStrategyMainnet:Strategy        | https://arbiscan.io/address/0x495FCc9227Cec435Bfa46714882a7bd0C91239e3 |
| EthMimSushiStrategyMainnet:Vault           | https://arbiscan.io/address/0x53130D60c57D392afAf724239D53Cab9e313c9b7 |
| EthSpellSushiStrategyMainnet:RewardPool    | https://arbiscan.io/address/0x7F6d1e689f960Aea3F1F8599d1EEd9B1e9D09128 |
| EthSpellSushiStrategyMainnet:Strategy      | https://arbiscan.io/address/0x16A8B908ACc7b57756dDF1d2bf4036C74c0e70c3 |
| EthSpellSushiStrategyMainnet:Vault         | https://arbiscan.io/address/0x2A941522475978B40CD09916D860193aD2bE9e88 |
| EthSushiSushiStrategyMainnet:RewardPool    | https://arbiscan.io/address/0x7386Fe6cd870df4ac57877e39796293E9098aef3 |
| EthSushiSushiStrategyMainnet:Strategy      | https://arbiscan.io/address/0x4e4D7899Facd7C2c0486cB31332A48c2fA26c876 |
| EthSushiSushiStrategyMainnet:Vault         | https://arbiscan.io/address/0xd4607317290d2d6F7392bF8c3B353875E127ABd9 |
