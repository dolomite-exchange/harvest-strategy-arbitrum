// Utilities
import BigNumber from 'bignumber.js';
import { artifacts, ethers, web3 } from 'hardhat';
import { IController } from '../../src/types/IController';
import { IERC20 } from '../../src/types/IERC20';
import { IGauge } from '../../src/types/IGauge';
import { IVault } from '../../src/types/IVault';
import { TriCryptoStrategyMainnet } from '../../src/types/TriCryptoStrategyMainnet';

import { depositVault, impersonates, setupCoreProtocol } from '../utilities/hh-utils';

import * as utils from '../utilities/utils';

const { send } = require('@openzeppelin/test-helpers');
const IERC20Artifact = artifacts.require('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20');
const IGaugeArtifact = artifacts.require('IGauge');
const StrategyArtifact = artifacts.require('TriCryptoStrategyMainnet');


// This test was developed at blockNumber 12690800

describe('Mainnet TriCrypto', function () {
  let accounts: string[];

  // external contracts
  let underlying: any & IERC20;

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
  let vault: any & IVault;
  let strategy: TriCryptoStrategyMainnet;
  let gauge: IGauge;

  async function setupExternalContracts() {
    underlying = await IERC20Artifact.at('0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490');
    console.log('Fetching Underlying at: ', underlying.address);
  }

  async function setupBalance() {
    let etherGiver = accounts[9];
    // Give whale some ether to make sure the following actions are good
    await send.ether(etherGiver, underlyingWhale, ethers.constants.One.mul(ethers.constants.WeiPerEther));

    farmerBalance = await underlying.balanceOf(underlyingWhale);
    await underlying.transfer(farmer1, farmerBalance, { from: underlyingWhale });
  }

  before(async function () {
    governance = '0xf00dD244228F51547f0563e60bCa65a30FBF5f7f';
    accounts = await web3.eth.getAccounts();

    farmer1 = accounts[1];

    // impersonate accounts
    await impersonates([governance, underlyingWhale]);

    await setupExternalContracts();
    [controller, vault, strategy] = await setupCoreProtocol({
      'existingVaultAddress': '0x71B9eC42bB3CB40F017D8AD8011BE8e384a95fa5',
      'strategyArtifact': StrategyArtifact,
      'strategyArtifactIsUpgradable': true,
      'upgradeStrategy': true,
      'underlying': underlying,
      'governance': governance,
    });

    await strategy.setSellFloor(0, { from: governance });

    gauge = await IGaugeArtifact.at('0xF403C135812408BFbE8713b5A23a04b3D48AAE31');

    // whale send underlying to farmers
    await setupBalance();
  });

  describe('Happy path', function () {
    it('Farmer should earn money', async function () {
      let farmerOldBalance = new BigNumber(await underlying.balanceOf(farmer1));
      await depositVault(farmer1, underlying, vault, farmerBalance);
      let fTokenBalance = await vault.balanceOf(farmer1);
      let cvx = await IERC20Artifact.at('0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B');

      // Using half days is to simulate how we doHardwork in the real world
      let hours = 10;
      let blocksPerHour = 4800;
      let oldSharePrice: BigNumber;
      let newSharePrice: BigNumber;
      let hodlOldBalance = new BigNumber(await cvx.balanceOf(hodlVault));
      for (let i = 0; i < hours; i++) {
        console.log('loop ', i);

        oldSharePrice = new BigNumber(await vault.getPricePerFullShare());
        await controller.doHardWork(vault.address, { from: governance });
        newSharePrice = new BigNumber(await vault.getPricePerFullShare());

        console.log('old share price: ', oldSharePrice.toFixed());
        console.log('new share price: ', newSharePrice.toFixed());
        console.log('growth: ', newSharePrice.div(oldSharePrice).toFixed());

        const apr = utils.calculateApr(newSharePrice, oldSharePrice);
        const apy = utils.calculateApy(newSharePrice, oldSharePrice);

        console.log('instant APR:', apr.times(100).toFixed(), '%');
        console.log('instant APY:', apy.minus(1).times(100).toFixed(), '%');

        await utils.advanceNBlock(blocksPerHour);
      }
      await vault.withdraw(fTokenBalance, { from: farmer1 });
      let farmerNewBalance = new BigNumber(await underlying.balanceOf(farmer1));
      utils.assertBNGt(farmerNewBalance, farmerOldBalance);

      let hodlNewBalance = new BigNumber(await cvx.balanceOf(hodlVault));
      console.log('CVX before', hodlOldBalance.toFixed());
      console.log('CVX after ', hodlNewBalance.toFixed());
      utils.assertBNGt(hodlNewBalance, hodlOldBalance);

      const apr = utils.calculateApr(farmerNewBalance, farmerOldBalance);
      const apy = utils.calculateApy(farmerNewBalance, farmerOldBalance);

      console.log('earned!');
      console.log('overall APR:', apr.times(100).toFixed(), '%');
      console.log('overall APY:', apy.minus(1).times(100).toFixed(), '%');

      await strategy.withdrawAllToVault({ from: governance }); // making sure can withdraw all for a next switch
    });
  });
});
