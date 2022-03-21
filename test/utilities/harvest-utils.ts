import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BaseContract, BigNumber, BigNumberish } from 'ethers';
import { ethers } from 'hardhat';
import {
  ControllerV1,
  IController,
  IController__factory,
  IERC20,
  IERC20__factory,
  IProfitSharingReceiver,
  IProfitSharingReceiver__factory,
  IRewardForwarder,
  IRewardForwarder__factory,
  IUniversalLiquidator,
  IUniversalLiquidator__factory,
  IVault,
  IWETH,
  PotPool,
  ProfitSharingReceiverV1,
  RewardForwarderV1,
  Storage,
  Storage__factory,
  StrategyProxy,
  UniversalLiquidatorProxy,
  UniversalLiquidatorProxy__factory,
  UniversalLiquidatorV1,
  VaultProxy,
  VaultV1,
  VaultV1__factory,
  VaultV2,
  VaultV2__factory,
} from '../../src/types';
import { DefaultImplementationDelay, WETH } from './constants';
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
  implementationDelaySeconds: number;
  targetToken: TargetToken;
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
  strategist: SignerWithAddress
  profitSharingReceiver: IProfitSharingReceiver
  rewardForwarder: IRewardForwarder
  storage: Storage
  universalLiquidatorProxy: UniversalLiquidatorProxy
  universalLiquidator: IUniversalLiquidator
}

export async function setupCoreProtocol(config: CoreProtocolSetupConfig): Promise<CoreProtocol> {
  await resetFork(config.blockNumber);

  const [hhUser1, hhUser2, hhUser3, hhUser4, hhUser5, strategist] = await ethers.getSigners();
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
    const universalLiquidatorImplementation = await UniversalLiquidatorFactory.connect(governance)
      .deploy() as UniversalLiquidatorV1;

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
      profitSharingReceiver.address,
    ) as IRewardForwarder;

    implementationDelaySeconds = DefaultImplementationDelay;
    const ControllerV1Factory = await ethers.getContractFactory('ControllerV1');
    controller = await ControllerV1Factory.connect(governance).deploy(
      storage.address,
      WETH.address,
      rewardForwarder.address,
      universalLiquidator.address,
      implementationDelaySeconds,
    ) as IController;

    const result = await storage.connect(governance).setInitialController(controller.address);
    await expect(result).to.emit(storage, 'ControllerChanged').withArgs(controller.address);

    expect(await controller.nextImplementationDelay()).to.eq(implementationDelaySeconds);
    expect(await controller.targetToken()).to.eq(WETH.address);
  }

  expect(await storage.governance()).to.eq(governance.address);
  expect(await storage.controller()).to.eq(controller.address);

  expect(await universalLiquidator.governance()).to.eq(governance.address);
  expect(await universalLiquidator.controller()).to.eq(controller.address);

  expect(await rewardForwarder.store()).to.eq(storage.address);
  expect(await rewardForwarder.governance()).to.eq(governance.address);
  expect(await rewardForwarder.profitSharingPool()).to.eq(profitSharingReceiver.address);

  expect(await controller.governance()).to.eq(governance.address);
  expect(await controller.store()).to.eq(storage.address);
  expect(await controller.rewardForwarder()).to.eq(rewardForwarder.address);

  return {
    controller,
    controllerParams: {
      implementationDelaySeconds,
      targetToken: new BaseContract(await controller.targetToken(), IERC20__factory.createInterface()) as IERC20,
    },
    governance,
    hhUser1,
    hhUser2,
    hhUser3,
    hhUser4,
    hhUser5,
    strategist,
    profitSharingReceiver,
    rewardForwarder,
    storage,
    universalLiquidator,
    universalLiquidatorProxy,
  }
}

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
 * @param core            The `CoreProtocol` used for deployment
 * @param underlying      The underlying token used for the vault
 * @return  The deployed strategy proxy and the implementation contract at the proxy's address
 */
export async function createVault(
  implementation: IVault,
  core: CoreProtocol,
  underlying: { address: string },
): Promise<[VaultProxy, VaultV1, VaultV2]> {
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

  await vaultImplV1.initializeVault(core.storage.address, underlying.address, '995', '1000');

  return [vaultProxy, vaultImplV1, vaultImplV2]
}

export async function setupWETHBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  await WETH.connect(signer).deposit({ value: amount });
  await WETH.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

type VaultType = IVault | VaultV1 | VaultV2;

export async function depositIntoVault(
  farmer: SignerWithAddress,
  underlying: IERC20,
  vault: VaultType,
  amount: BigNumber,
) {
  const balanceBefore = await vault.underlyingBalanceWithInvestmentForHolder(farmer.address);
  await underlying.connect(farmer).approve(vault.address, amount);
  if ('deposit' in vault) {
    // vault is instance of IVault or VaultV1
    await vault.connect(farmer).deposit(amount);
  } else {
    await vault['deposit(uint256)'](amount);
  }
  expect(await vault.underlyingBalanceWithInvestmentForHolder(farmer.address)).to.eq(balanceBefore.add(amount));
}

type RewardToken = IERC20 | IWETH;
type TargetToken = IERC20 | IWETH;

export async function getReceivedAmountBeforeHardWork(
  core: CoreProtocol,
  user: SignerWithAddress,
  tokenIn: RewardToken,
  rewardAmount: BigNumberish,
): Promise<BigNumber> {
  return core.universalLiquidator.connect(user).callStatic.swapTokens(
    tokenIn.address,
    core.controllerParams.targetToken.address,
    rewardAmount,
    '1',
    core.rewardForwarder.address,
  );
}

export async function checkHardWorkResults(
  core: CoreProtocol,
  receivedTargetAmount: BigNumber,
) {
  const target = core.controllerParams.targetToken.connect(core.governance);
  expect(await target.balanceOf(core.profitSharingReceiver.address))
    .to
    .be
    .gte(receivedTargetAmount.mul('15').div('100'));
  expect(await target.balanceOf(core.strategist.address)).to.be.gte(receivedTargetAmount.mul('5').div('100'));
  expect(await target.balanceOf(core.governance.address)).to.be.gte(receivedTargetAmount.mul('5').div('100'));
}
