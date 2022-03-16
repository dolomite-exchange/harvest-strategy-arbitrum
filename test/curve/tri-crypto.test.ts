// Utilities
import { BigNumber } from 'ethers';
import { artifacts, ethers, web3 } from 'hardhat';
import { IController, IERC20, IGauge, IVault, TriCryptoStrategyMainnet } from '../../src/types';

import { depositVault, impersonates, setupCoreProtocol } from '../utilities/hardhat-utils';

import * as utils from '../utilities/utils';

const IERC20Artifact = artifacts.require('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20');
const IGaugeArtifact = artifacts.require('IGauge');
const StrategyArtifact = artifacts.require('TriCryptoStrategyMainnet');


// TODO deploy storage, controller, etc. if preset address is 0x00...00 - this will allow me to develop without wasting
//  ETH deploying them. Eventually, when we're live, I can replace them w/ their real addresses

/**
 * This test was developed at blockNumber XYZ
 */
describe('Mainnet TriCrypto', () => {
  let accounts: string[];

  // external contracts
  let underlying: IERC20;

  // external setup
  let underlyingWhale = '0x89515406c15a277F8906090553366219B3639834';
  let hodlVault = '0xF49440C1F012d041802b25A73e5B0B9166a75c02';

  // parties in the protocol
  let governance: string;
  let farmer1: string;

  // numbers used in tests
  let farmerBalance: BigNumber;

  // Core protocol contracts
  let controller: IController;
  let vault: IVault;
  let strategy: TriCryptoStrategyMainnet;
  let gauge: IGauge;

  async function setupExternalContracts() {
    underlying = await IERC20Artifact.at('0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490');
    console.log('Fetching Underlying at: ', underlying.address);
  }

  async function setupBalance() {
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await utils.sendEther(etherGiver, underlyingWhale, ethers.constants.One.mul(ethers.constants.WeiPerEther));

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async () => {
    governance = '0xf00dD244228F51547f0563e60bCa65a30FBF5f7f';
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      shouldAnnounceStrategy: false,
      existingRewardPoolAddress: ethers.constants.AddressZero,
      existingVaultAddress: ethers.constants.AddressZero,
      feeRewardForwarder: ethers.constants.AddressZero,
      governance: governance,
      rewardPool: ethers.constants.AddressZero,
      rewardPoolConfig: {},
      strategyArgs: [],
      strategyArtifact: StrategyArtifact,
      strategyArtifactIsUpgradable: true,
      underlying: underlying,
      upgradeStrategy: true,
      vaultImplementationOverrideAddress: ethers.constants.AddressZero,
    });

    await strategy.setSellFloor(0, { from: governance });

    gauge = await IGaugeArtifact.at('0xF403C135812408BFbE8713b5A23a04b3D48AAE31');

    // whale send underlying to farmers
    await setupBalance();
  });

  describe('Happy path', function () {
    it('Farmer should earn money', async function () {
      let farmerOldBalance = await underlying.balanceOf(farmer1);
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);
      let cvx = await IERC20Artifact.at('0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B');

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 4800;
      let oldSharePrice: BigNumber;
      let newSharePrice: BigNumber;
      let hodlOldBalance: BigNumber = await cvx.balanceOf(hodlVault);
      for (let i = 0; i < hours; i++) {
        console.log('loop ', i);

        oldSharePrice = await vault.getPricePerFullShare();
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = await vault.getPricePerFullShare();

        console.log('old share price: ', oldSharePrice.toString());
        console.log('new share price: ', newSharePrice.toString());
        console.log('growth: ', newSharePrice.div(oldSharePrice).toString());

        const apr = utils.calculateApr(newSharePrice, oldSharePrice);
        const apy = utils.calculateApy(newSharePrice, oldSharePrice);

        console.log('instant APR:', apr.mul(100).toString(), '%');
        console.log('instant APY:', apy.sub(1).mul(100).toString(), '%');

        await utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw(fTokenBalance, { from: farmer1 });
      let farmerNewBalance = await underlying.balanceOf(farmer1);
      utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      let hodlNewBalance = await cvx.balanceOf(hodlVault);
      console.log('CVX before', hodlOldBalance.toString());
      console.log('CVX after ', hodlNewBalance.toString());
      utils.assertBNGt(hodlNewBalance, hodlOldBalance);

      const apr = utils.calculateApr(farmerNewBalance, farmerOldBalance);
      const apy = utils.calculateApy(farmerNewBalance, farmerOldBalance);

      console.log('earned!');
      console.log('overall APR:', apr.mul(100).toString(), '%');
      console.log('overall APY:', apy.sub(1).mul(100).toString(), '%');

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
