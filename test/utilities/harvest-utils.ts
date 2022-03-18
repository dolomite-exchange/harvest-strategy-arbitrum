import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BaseContract, BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import {
  ControllerV1,
  IController,
  IController__factory,
  IERC20, IERC4626, IERC4626__factory,
  IProfitSharingReceiver,
  IProfitSharingReceiver__factory,
  IRewardForwarder,
  IRewardForwarder__factory,
  IUniversalLiquidator,
  IUniversalLiquidator__factory,
  IVault,
  PotPool,
  ProfitSharingReceiverV1,
  RewardForwarderV1,
  Storage,
  Storage__factory, StrategyProxy,
  UniversalLiquidatorProxy,
  UniversalLiquidatorProxy__factory,
  UniversalLiquidatorV1, VaultProxy, VaultV1, VaultV1__factory, VaultV2, VaultV2__factory,
} from '../../src/types';
import { DefaultImplementationDelay, USDC } from './constants';
import { impersonateAll, resetFork, setEtherBalance } from './utils';

export interface ExistingCoreAddresses {
  governanceAddress: string
  profitSharingReceiverAddress: string
  controllerAddress: string
  rewardForwarderAddress: string
  storageAddress: string
  universalLiquidatorAddress: string
  vaultImplementation: string
}

export interface StrategyConfig {
  shouldAnnounceStrategy: boolean;
  existingRewardPoolAddress: string | null;
  existingVaultAddress: string;
  rewardForwarder: string;
  governance: string;
  rewardPool: PotPool;
  rewardPoolConfig: Record<string, any>;
  strategyArgs: any[];
  strategyArtifact: any;
  strategyArtifactIsUpgradable: boolean;
  underlying: IERC20;
  upgradeStrategy: string;
  vaultImplementationOverrideAddress: string;
}

/**
 * Config to for setting up tests in the `before` function
 */
export interface CoreProtocolSetupConfig {
  /**
   * The block number at which the tests will be run on Arbitrum
   */
  blockNumber: number;
  /**
   * Leave as undefined to deploy new "Core" contracts
   */
  existingCoreAddresses?: ExistingCoreAddresses;
  strategyConfig?: StrategyConfig;
}

export interface ControllerConfig {
  implementationDelaySeconds: number
}

export interface CoreProtocol {
  controller: IController
  controllerParams: ControllerConfig
  governance: SignerWithAddress
  hhUser1: SignerWithAddress
  hhUser2: SignerWithAddress
  hhUser3: SignerWithAddress
  hhUser4: SignerWithAddress
  hhUser5: SignerWithAddress
  profitSharingReceiver: IProfitSharingReceiver
  rewardForwarder: IRewardForwarder
  storage: Storage
  universalLiquidatorProxy: UniversalLiquidatorProxy
  universalLiquidator: IUniversalLiquidator
}

export async function setupCoreProtocol(config: CoreProtocolSetupConfig): Promise<CoreProtocol> {
  await resetFork(config.blockNumber);

  const [hhUser1, hhUser2, hhUser3, hhUser4, hhUser5] = await ethers.getSigners();
  let governance: SignerWithAddress;
  let profitSharingReceiver: IProfitSharingReceiver;
  let universalLiquidator: IUniversalLiquidator;
  let universalLiquidatorProxy: UniversalLiquidatorProxy;
  let rewardForwarder: IRewardForwarder;
  let controller: IController;
  let storage: Storage;

  let implementationDelaySeconds: number;

  if (config.existingCoreAddresses) {
    await impersonateAll([config.existingCoreAddresses.governanceAddress]);
    governance = await ethers.getSigner(config.existingCoreAddresses.governanceAddress);

    storage = new BaseContract(
      config.existingCoreAddresses.storageAddress,
      Storage__factory.createInterface(),
      governance,
    ) as Storage;

    controller = new BaseContract(
      config.existingCoreAddresses.controllerAddress,
      IController__factory.createInterface(),
      governance,
    ) as IController;

    profitSharingReceiver = new BaseContract(
      config.existingCoreAddresses.profitSharingReceiverAddress,
      IProfitSharingReceiver__factory.createInterface(),
      governance,
    ) as IProfitSharingReceiver

    rewardForwarder = new BaseContract(
      config.existingCoreAddresses.rewardForwarderAddress,
      IRewardForwarder__factory.createInterface(),
      governance,
    ) as IRewardForwarder;

    universalLiquidator = new BaseContract(
      config.existingCoreAddresses.universalLiquidatorAddress,
      IUniversalLiquidator__factory.createInterface(),
      governance,
    ) as IUniversalLiquidator;

    universalLiquidatorProxy = new BaseContract(
      config.existingCoreAddresses.universalLiquidatorAddress,
      UniversalLiquidatorProxy__factory.createInterface(),
      governance,
    ) as UniversalLiquidatorProxy;

    implementationDelaySeconds = (await controller.nextImplementationDelay()).toNumber();
  } else {
    const governanceAddress = '0x4861727665737446696e616E63657633536f6f6e';
    await impersonateAll([governanceAddress]);
    await setEtherBalance(governanceAddress);
    governance = await ethers.getSigner(governanceAddress)

    const StorageFactory = await ethers.getContractFactory('Storage');
    storage = (await StorageFactory.connect(governance).deploy()) as Storage;

    const UniversalLiquidatorFactory = await ethers.getContractFactory('UniversalLiquidatorV1');
    const universalLiquidatorImplementation = await UniversalLiquidatorFactory.connect(governance).deploy() as UniversalLiquidatorV1;

    const UniversalLiquidatorProxyFactory = await ethers.getContractFactory('UniversalLiquidatorProxy');
    universalLiquidatorProxy = await UniversalLiquidatorProxyFactory.connect(governance).deploy(
      universalLiquidatorImplementation.address,
    ) as UniversalLiquidatorProxy;

    universalLiquidator = new BaseContract(
      universalLiquidatorProxy.address,
      IUniversalLiquidator__factory.createInterface(),
      governance,
    ) as IUniversalLiquidator;
    await universalLiquidator.connect(governance).initializeUniversalLiquidator(storage.address);

    const ProfitSharingReceiverV1Factory = await ethers.getContractFactory('ProfitSharingReceiverV1');
    profitSharingReceiver = await ProfitSharingReceiverV1Factory.connect(governance).deploy(
      storage.address,
    ) as IProfitSharingReceiver;

    const RewardForwarderV1Factory = await ethers.getContractFactory('RewardForwarderV1');
    rewardForwarder = await RewardForwarderV1Factory.connect(governance).deploy(
      storage.address,
      USDC.address,
      profitSharingReceiver.address,
    ) as IRewardForwarder;

    implementationDelaySeconds = DefaultImplementationDelay;
    const ControllerV1Factory = await ethers.getContractFactory('ControllerV1');
    controller = await ControllerV1Factory.connect(governance).deploy(
      storage.address,
      rewardForwarder.address,
      universalLiquidator.address,
      implementationDelaySeconds,
    ) as IController;

    const result = await storage.connect(governance).setInitialController(controller.address);
    await expect(result).to.emit(storage, 'ControllerChanged').withArgs(controller.address);

    expect(await controller.nextImplementationDelay()).to.eq(implementationDelaySeconds);
  }

  expect(await storage.governance()).to.eq(governance.address);
  expect(await storage.controller()).to.eq(controller.address);

  expect(await universalLiquidator.governance()).to.eq(governance.address);
  expect(await universalLiquidator.controller()).to.eq(controller.address);

  expect(await rewardForwarder.store()).to.eq(storage.address);
  expect(await rewardForwarder.governance()).to.eq(governance.address);
  expect(await rewardForwarder.targetToken()).to.eq(USDC.address);
  expect(await rewardForwarder.profitSharingPool()).to.eq(profitSharingReceiver.address);

  expect(await controller.governance()).to.eq(governance.address);
  expect(await controller.store()).to.eq(storage.address);
  expect(await controller.rewardForwarder()).to.eq(rewardForwarder.address);

  return {
    controller,
    controllerParams: {
      implementationDelaySeconds,
    },
    governance,
    hhUser1,
    hhUser2,
    hhUser3,
    hhUser4,
    hhUser5,
    profitSharingReceiver,
    rewardForwarder,
    storage,
    universalLiquidator,
    universalLiquidatorProxy,
  }
}

// export async function setupCoreProtocol(config: CoreProtocolConfig) {
//   // Set vault (or Deploy new vault), underlying, underlying Whale,
//   // amount the underlying whale should send to farmers
//   let vault: IVault;
//   if (config.existingVaultAddress != null) {
//     vault = await IVaultArtifact.at(config.existingVaultAddress);
//     console.log('Fetching Vault at: ', vault.address);
//   } else {
//     const implAddress = config.vaultImplementationOverrideAddress || addresses.VaultImplementationV1;
//     vault = await makeVault(implAddress, addresses.Storage, config.underlying.address, 100, 100, {
//       from: config.governance,
//     });
//     console.log('New Vault Deployed: ', vault.address);
//   }
//
//   let controller: IController = await IControllerArtifact.at(addresses.Controller);
//
//   let rewardPool: IPotPool | null = null;
//
//   if (!config.rewardPoolConfig) {
//     config.rewardPoolConfig = {};
//   }
//   // if reward pool is required, then deploy it
//   if (config.rewardPool != null && config.existingRewardPoolAddress == null) {
//     const rewardTokens = config.rewardPoolConfig.rewardTokens || [addresses.FARM];
//     const rewardDistributions = [config.governance];
//     if (config.feeRewardForwarderV1) {
//       rewardDistributions.push(config.feeRewardForwarderV1);
//     }
//
//     if (config.rewardPoolConfig.type === 'PotPool') {
//       console.log('reward pool needs to be deployed');
//       rewardPool = await PotPoolArtifact.new(
//         rewardTokens,
//         vault.address,
//         64800,
//         rewardDistributions,
//         addresses.Storage,
//         'fPool Token',
//         'fPool',
//         18,
//         { from: config.governance },
//       );
//       console.log('New PotPool deployed: ', rewardPool?.address);
//     }
//   } else if (config.existingRewardPoolAddress) {
//     rewardPool = await PotPoolArtifact.at(config.existingRewardPoolAddress);
//     console.log('Fetching Reward Pool deployed: ', rewardPool?.address);
//   }
//
//   let universalLiquidatorRegistry = await IUniversalLiquidatorArtifact.at(addresses.UniversalLiquidatorRegistry);
//
//   // default arguments are storage and vault addresses
//   config.strategyArgs = config.strategyArgs || [
//     addresses.Storage,
//     vault.address,
//   ];
//
//   for (let i = 0; i < config.strategyArgs.length; i++) {
//     if (config.strategyArgs[i] == 'vaultAddr') {
//       config.strategyArgs[i] = vault.address;
//     } else if (config.strategyArgs[i] == 'poolAddr') {
//       config.strategyArgs[i] = rewardPool?.address;
//     } else if (config.strategyArgs[i] == 'universalLiquidatorRegistryAddr') {
//       config.strategyArgs[i] = universalLiquidatorRegistry.address;
//     }
//   }
//
//   let strategyImpl = null;
//
//   let strategy: IMainnetStrategy;
//   if (!config.strategyArtifactIsUpgradable) {
//     strategy = await config.strategyArtifact.new(
//       ...config.strategyArgs,
//       { from: config.governance },
//     );
//   } else {
//     strategyImpl = await config.strategyArtifact.new();
//     const StrategyProxy = artifacts.require('StrategyProxy');
//
//     const strategyProxy = await StrategyProxy.new(strategyImpl.address);
//     strategy = await config.strategyArtifact.at(strategyProxy.address);
//     await strategy.initializeStrategy(
//       config.strategyArgs[0],
//       config.strategyArgs[1],
//       { from: config.governance },
//     );
//   }
//
//   console.log('Strategy Deployed: ', strategy.address);
//
//   if (config.shouldAnnounceStrategy) {
//     // Announce switch, time pass, switch to strategy
//     await vault.announceStrategyUpdate(strategy.address, { from: config.governance });
//     console.log('Strategy switch announced. Waiting...');
//     await utils.waitHours(13);
//     await vault.setStrategy(strategy.address, { from: config.governance });
//     await vault.setVaultFractionToInvest(100, 100, { from: config.governance });
//     console.log('Strategy switch completed.');
//   } else if (config.upgradeStrategy) {
//     // Announce upgrade, time pass, upgrade the strategy
//     const strategyAsUpgradable = await IUpgradeableStrategyArtifact.at(await vault.strategy());
//     await strategyAsUpgradable.scheduleUpgrade(strategyImpl.address, { from: config.governance });
//     console.log('Upgrade scheduled. Waiting...');
//     await utils.waitHours(13);
//     await strategyAsUpgradable.upgrade({ from: config.governance });
//     await vault.setVaultFractionToInvest(100, 100, { from: config.governance });
//     strategy = await config.strategyArtifact.at(await vault.strategy());
//     console.log('Strategy upgrade completed.');
//   } else {
//     await controller.addVaultAndStrategy(
//       vault.address,
//       strategy.address,
//       { from: config.governance },
//     );
//     console.log('Strategy and vault added to Controller.');
//   }
//
//   return [controller, vault, strategy, rewardPool];
// }

/**
 * @param implementation  The implementation contract
 * @return  The deployed strategy proxy and the implementation contract at the proxy's address
 */
export async function createStrategy<T extends BaseContract>(implementation: T): Promise<[StrategyProxy, T]> {
  const StrategyProxyFactory = await ethers.getContractFactory('StrategyProxy');
  const strategyProxy = await StrategyProxyFactory.deploy(implementation.address) as StrategyProxy;
  const strategyImpl = new BaseContract(
    strategyProxy.address,
    implementation.interface,
    implementation.signer,
  ) as T;
  return [strategyProxy, strategyImpl]
}

/**
 * @param implementation  The implementation contract
 * @return  The deployed strategy proxy and the implementation contract at the proxy's address
 */
export async function createVault(implementation: IVault): Promise<[VaultProxy, VaultV1, VaultV2]> {
  const VaultProxyFactory = await ethers.getContractFactory('VaultProxy');
  const vaultProxy = await VaultProxyFactory.deploy(implementation.address) as VaultProxy;
  const vaultImplV1 = new BaseContract(
    vaultProxy.address,
    VaultV1__factory.createInterface(),
    implementation.signer,
  ) as VaultV1;
  const vaultImplV2 = new BaseContract(
    vaultProxy.address,
    VaultV2__factory.createInterface(),
    implementation.signer,
  ) as VaultV2;
  return [vaultProxy, vaultImplV1, vaultImplV2]
}

export async function depositVault(_farmer: string, _underlying: IERC20, _vault: IVault, _amount: BigNumber) {
  await _underlying.approve(_vault.address, _amount, { from: _farmer });
  await _vault.deposit(_amount, { from: _farmer });
}
