import BigNumber from 'bignumber.js';
import { artifacts, network } from 'hardhat';
import { IController, StrategyProxy, IVault, IMainnetStrategy, IERC20 } from '../../src/types';
import makeVault from './make-vault';
import * as utils from './utils';

import * as addresses from '../test-config';

const IControllerArtifact = artifacts.require('IController');

const IUniversalLiquidatorArtifact = artifacts.require('IUniversalLiquidator');
const IPotPoolArtifact = artifacts.require('IPotPool');
const IUpgradeableStrategyArtifact = artifacts.require('IUpgradeableStrategy');

const IVaultArtifact = artifacts.require('IVault');

export async function impersonates(targetAccounts: string[]) {
  console.log('Impersonating...');
  for (let i = 0; i < targetAccounts.length; i++) {
    console.log(targetAccounts[i]);
    await network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [
        targetAccounts[i],
      ],
    });
  }
}

export interface CoreProtocolConfig {
  existingVaultAddress: string
  feeRewardForwarder: string
  governance
  upgradeStrategy
  strategyArtifact
  strategyArtifactIsUpgradable
  underlying
  vaultImplementationOverride
}

export async function setupCoreProtocol(config: CoreProtocolConfig) {
  // Set vault (or Deploy new vault), underlying, underlying Whale,
  // amount the underlying whale should send to farmers
  let vault: any & IVault;
  if (config.existingVaultAddress != null) {
    vault = await IVaultArtifact.at(config.existingVaultAddress);
    // console.log('Fetching Vault at: ', vault.address);
    console.log('Fetching Vault at: ', vault.address);
  } else {
    const implAddress = config.vaultImplementationOverride || addresses.VaultImplementationV1;
    vault = await makeVault(implAddress, addresses.Storage, config.underlying.address, 100, 100, {
      from: config.governance,
    });
    console.log('New Vault Deployed: ', vault.address);
  }

  let controller = await IControllerArtifact.at(addresses.Controller) as IController;

  let rewardPool = null;

  if (!config.rewardPoolConfig) {
    config.rewardPoolConfig = {};
  }
  // if reward pool is required, then deploy it
  if (config.rewardPool != null && config.existingRewardPoolAddress == null) {
    const rewardTokens = config.rewardPoolConfig.rewardTokens || [addresses.FARM];
    const rewardDistributions = [config.governance];
    if (config.feeRewardForwarder) {
      rewardDistributions.push(config.feeRewardForwarder);
    }

    if (config.rewardPoolConfig.type === 'PotPool') {
      const PotPool = artifacts.require('PotPool');
      console.log('reward pool needs to be deployed');
      rewardPool = await PotPool.new(
        rewardTokens,
        vault.address,
        64800,
        rewardDistributions,
        addresses.Storage,
        'fPool',
        'fPool',
        18,
        { from: config.governance },
      );
      console.log('New PotPool deployed: ', rewardPool.address);
    } else {
      const NoMintRewardPool = artifacts.require('NoMintRewardPool');
      console.log('reward pool needs to be deployed');
      rewardPool = await NoMintRewardPool.new(
        rewardTokens[0],
        vault.address,
        64800,
        rewardDistributions[0],
        addresses.Storage,
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
        { from: config.governance },
      );
      console.log('New NoMintRewardPool deployed: ', rewardPool.address);
    }
  } else if (config.existingRewardPoolAddress != null) {
    const NoMintRewardPool = artifacts.require('NoMintRewardPool');
    rewardPool = await NoMintRewardPool.at(config.existingRewardPoolAddress);
    console.log('Fetching Reward Pool deployed: ', rewardPool.address);
  }

  let universalLiquidatorRegistry = await IUniversalLiquidatorArtifact.at(addresses.UniversalLiquidatorRegistry);

  // default arguments are storage and vault addresses
  config.strategyArgs = config.strategyArgs || [
    addresses.Storage,
    vault.address,
  ];

  for (let i = 0; i < config.strategyArgs.length; i++) {
    if (config.strategyArgs[i] == 'vaultAddr') {
      config.strategyArgs[i] = vault.address;
    } else if (config.strategyArgs[i] == 'poolAddr') {
      config.strategyArgs[i] = rewardPool?.address;
    } else if (config.strategyArgs[i] == 'universalLiquidatorRegistryAddr') {
      config.strategyArgs[i] = universalLiquidatorRegistry.address;
    }
  }

  let strategyImpl = null;

  let strategy: any & IMainnetStrategy;
  if (!config.strategyArtifactIsUpgradable) {
    strategy = await config.strategyArtifact.new(
      ...config.strategyArgs,
      { from: config.governance },
    );
  } else {
    strategyImpl = await config.strategyArtifact.new();
    const StrategyProxy = artifacts.require('StrategyProxy');

    const strategyProxy = await StrategyProxy.new(strategyImpl.address);
    strategy = (await config.strategyArtifact.at(strategyProxy.address)) as IMainnetStrategy;
    await strategy.initializeStrategy(
      config.strategyArgs[0],
      config.strategyArgs[1],
      { from: config.governance },
    );
  }

  console.log('Strategy Deployed: ', strategy.address);

  if (config.announceStrategy === true) {
    // Announce switch, time pass, switch to strategy
    await vault.announceStrategyUpdate(strategy.address, { from: config.governance });
    console.log('Strategy switch announced. Waiting...');
    await utils.waitHours(13);
    await vault.setStrategy(strategy.address, { from: config.governance });
    await vault.setVaultFractionToInvest(100, 100, { from: config.governance });
    console.log('Strategy switch completed.');
  } else if (config.upgradeStrategy) {
    // Announce upgrade, time pass, upgrade the strategy
    const strategyAsUpgradable = await IUpgradeableStrategyArtifact.at(await vault.strategy());
    await strategyAsUpgradable.scheduleUpgrade(strategyImpl.address, { from: config.governance });
    console.log('Upgrade scheduled. Waiting...');
    await utils.waitHours(13);
    await strategyAsUpgradable.upgrade({ from: config.governance });
    await vault.setVaultFractionToInvest(100, 100, { from: config.governance });
    strategy = await config.strategyArtifact.at(await vault.strategy());
    console.log('Strategy upgrade completed.');
  } else {
    await controller.addVaultAndStrategy(
      vault.address,
      strategy.address,
      { from: config.governance },
    );
    console.log('Strategy and vault added to Controller.');
  }

  return [controller, vault, strategy, rewardPool];
}

export async function depositVault(_farmer: string, _underlying: IERC20, _vault: IVault, _amount: BigNumber) {
  await _underlying.approve((_vault as any).address, _amount, { from: _farmer });
  await _vault.deposit(_amount, { from: _farmer });
}
