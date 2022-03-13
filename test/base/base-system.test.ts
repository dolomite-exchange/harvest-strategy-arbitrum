// Utilities
import { BigNumber } from 'ethers';
import { artifacts, ethers, web3 } from 'hardhat';
import {
  Controller,
  Controller__factory,
  IController,
  IERC20,
  IGauge,
  IVault, RewardForwarder,
  Storage,
  TriCryptoStrategyMainnet,
} from '../../src/types';

import { depositVault, impersonates, setupCoreProtocol } from '../utilities/hh-utils';

import * as utils from '../utilities/utils';

const IERC20Artifact = artifacts.require('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20');
const IGaugeArtifact = artifacts.require('IGauge');
const StrategyArtifact = artifacts.require('TriCryptoStrategyMainnet');

/**
 * Tests deployment of `Storage`, `Controller`, `RewardForwarder`
 */
describe('BaseSystem', () => {
  let accounts: string[];

  // external contracts
  let underlying: IERC20;

  let governance: string;
  let storage: Storage;
  let rewardForwarder: RewardForwarder;
  let controller: Controller;

  let implementationDelaySeconds = 60;

  beforeEach(async () => {
    accounts = await web3.eth.getAccounts();

    const RewardForwarderFactory = await ethers.getContractFactory('RewardForwarder');
    rewardForwarder = await RewardForwarderFactory.deploy();

    const StorageFactory = await ethers.getContractFactory('Storage');
    storage = await StorageFactory.deploy();

    const ControllerFactory = await ethers.getContractFactory('Controller');
    controller = ControllerFactory.deploy(storage.address, rewardForwarder, implementationDelaySeconds);
  })
});
