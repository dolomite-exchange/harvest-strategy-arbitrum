import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BaseContract, BigNumber, BigNumberish, ContractTransaction, Overrides } from 'ethers';
import { ethers, network } from 'hardhat';
import {
  ControllerV1,
  ERC20Detailed,
  ERC20Detailed__factory,
  IController,
  IController__factory,
  IERC20,
  IERC20__factory,
  IProfitSharingReceiver,
  IProfitSharingReceiver__factory,
  IRewardForwarder,
  IRewardForwarder__factory,
  IUniversalLiquidatorV1,
  IUniversalLiquidatorV1__factory,
  IVault,
  IWETH,
  IPotPool,
  NonUpgradableProxy,
  PotPoolV1,
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
  VaultV2__factory, IUniversalLiquidatorV2, IUniversalLiquidatorV2__factory,
} from '../types';
import {
  ControllerV1Address, DAI, DaiWhaleAddress,
  DefaultImplementationDelay, G_OHM, GOhmWhaleAddress,
  GovernorAddress, MAGIC, MagicWhaleAddress, MIM, MimWhaleAddress,
  ProfitSharingReceiverV1Address,
  RewardForwarderV1Address, SPELL, SpellWhaleAddress,
  StorageAddress, SUSHI, SushiWhaleAddress,
  UniversalLiquidatorAddress,
  USDC, UsdcWhaleAddress, USDT, UsdtWhaleAddress,
  VaultV2ImplementationAddress,
  WBTC, WbtcWhaleAddress1, WbtcWhaleAddress2,
  WETH,
} from './constants';
import { BlockNumberV1, DefaultBlockNumber } from './no-deps-constants';
import { calculateApr, calculateApy, formatNumber, getLatestTimestamp, impersonate, resetFork } from './utils';

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
  rewardPool: IPotPool;
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

export const CoreProtocolSetupConfigV1: CoreProtocolSetupConfig = {
  blockNumber: BlockNumberV1,
  existingCoreAddresses: {
    governanceAddress: GovernorAddress,
    profitSharingReceiverAddress: ProfitSharingReceiverV1Address,
    controllerAddress: ControllerV1Address,
    rewardForwarderAddress: RewardForwarderV1Address,
    storageAddress: StorageAddress,
    universalLiquidatorAddress: UniversalLiquidatorAddress,
    vaultImplementation: VaultV2ImplementationAddress,
  },
}

export const CoreProtocolSetupConfigV2: CoreProtocolSetupConfig = {
  blockNumber: DefaultBlockNumber,
  existingCoreAddresses: {
    governanceAddress: GovernorAddress,
    profitSharingReceiverAddress: ProfitSharingReceiverV1Address,
    controllerAddress: ControllerV1Address,
    rewardForwarderAddress: RewardForwarderV1Address,
    storageAddress: StorageAddress,
    universalLiquidatorAddress: UniversalLiquidatorAddress,
    vaultImplementation: VaultV2ImplementationAddress,
  },
}

export interface ControllerConfig {
  implementationDelaySeconds: number;
  targetToken: TargetToken;
}

export interface CoreProtocol {
  blockNumber: number;
  controller: IController;
  controllerParams: ControllerConfig;
  governance: SignerWithAddress;
  hhUser1: SignerWithAddress;
  hhUser2: SignerWithAddress;
  hhUser3: SignerWithAddress;
  hhUser4: SignerWithAddress;
  hhUser5: SignerWithAddress;
  strategist: SignerWithAddress;
  profitSharingReceiver: IProfitSharingReceiver;
  rewardForwarder: IRewardForwarder;
  storage: Storage;
  universalLiquidatorProxy: UniversalLiquidatorProxy;
  universalLiquidator: IUniversalLiquidatorV1 | IUniversalLiquidatorV2;
}

export async function setupCoreProtocol(
  config: CoreProtocolSetupConfig = CoreProtocolSetupConfigV1,
): Promise<CoreProtocol> {
  if (network.name === 'hardhat') {
    await resetFork(config.blockNumber);
  } else {
    console.log('Skipping forking...');
  }

  const [hhUser1, hhUser2, hhUser3, hhUser4, hhUser5, strategist] = await ethers.getSigners();
  let governance: SignerWithAddress;
  let profitSharingReceiver: IProfitSharingReceiver;
  let universalLiquidator: IUniversalLiquidatorV1 | IUniversalLiquidatorV2;
  let universalLiquidatorProxy: UniversalLiquidatorProxy;
  let rewardForwarder: IRewardForwarder;
  let controller: IController;
  let storage: Storage;

  let implementationDelaySeconds: number;

  if (config.existingCoreAddresses) {
    if (network.name === 'hardhat') {
      governance = await impersonate(config.existingCoreAddresses.governanceAddress, true);
    } else {
      governance = await ethers.getSigner(config.existingCoreAddresses.governanceAddress);
    }

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

    if (config.blockNumber >= 12882300) {
      universalLiquidator = new BaseContract(
        config.existingCoreAddresses.universalLiquidatorAddress,
        IUniversalLiquidatorV2__factory.createInterface(),
        governance,
      ) as IUniversalLiquidatorV2;
    } else {
      universalLiquidator = new BaseContract(
        config.existingCoreAddresses.universalLiquidatorAddress,
        IUniversalLiquidatorV1__factory.createInterface(),
        governance,
      ) as IUniversalLiquidatorV1;
    }

    universalLiquidatorProxy = new BaseContract(
      config.existingCoreAddresses.universalLiquidatorAddress,
      UniversalLiquidatorProxy__factory.createInterface(),
      governance,
    ) as UniversalLiquidatorProxy;

    implementationDelaySeconds = (await controller.nextImplementationDelay()).toNumber();
  } else {
    const governanceAddress = '0x4861727665737446696e616E63657633536f6f6e';
    await impersonate(governanceAddress, true);
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
      IUniversalLiquidatorV1__factory.createInterface(),
      governance,
    ) as IUniversalLiquidatorV1;
    await universalLiquidator.connect(governance).initializeUniversalLiquidator(storage.address);

    const RewardForwarderV1Factory = await ethers.getContractFactory('RewardForwarderV1');
    rewardForwarder = await RewardForwarderV1Factory.connect(governance).deploy(
      storage.address,
    ) as IRewardForwarder;

    const ProfitSharingReceiverV1Factory = await ethers.getContractFactory('ProfitSharingReceiverV1');
    profitSharingReceiver = await ProfitSharingReceiverV1Factory.connect(governance).deploy(
      storage.address,
    ) as IProfitSharingReceiver;

    implementationDelaySeconds = DefaultImplementationDelay;
    const ControllerV1Factory = await ethers.getContractFactory('ControllerV1');
    controller = await ControllerV1Factory.connect(governance).deploy(
      storage.address,
      WETH.address,
      profitSharingReceiver.address,
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

  expect(await controller.governance()).to.eq(governance.address);
  expect(await controller.store()).to.eq(storage.address);
  expect(await controller.profitSharingReceiver()).to.eq(profitSharingReceiver.address);
  expect(await controller.rewardForwarder()).to.eq(rewardForwarder.address);

  return {
    blockNumber: config.blockNumber,
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
 * @param contractName  The name of the implementation contract to be deployed
 * @return  The deployed strategy proxy and the implementation contract at the proxy's address
 */
export async function createStrategy<T extends BaseContract>(contractName: string): Promise<[StrategyProxy, T, T]> {
  const factory = await ethers.getContractFactory(contractName);
  const rawImpl = await factory.deploy() as T;

  const StrategyProxyFactory = await ethers.getContractFactory('StrategyProxy');
  const strategyProxy = await StrategyProxyFactory.deploy(rawImpl.address) as StrategyProxy;
  const strategyImpl = new BaseContract(strategyProxy.address, rawImpl.interface, rawImpl.signer) as T;
  return [strategyProxy, strategyImpl, rawImpl]
}

/**
 * @param implementation  The implementation contract
 * @param core            The `CoreProtocol` used for deployment
 * @param underlying      The underlying token used for the vault
 * @return  The deployed strategy proxy and the implementation contract at the proxy's address
 */
export async function createVault(
  implementation: IVault | VaultV1 | VaultV2,
  core: CoreProtocol,
  underlying: BaseContract,
): Promise<[VaultProxy, VaultV1, VaultV2]> {
  const VaultProxyFactory = await ethers.getContractFactory('VaultProxy');
  const vaultProxy = await VaultProxyFactory.deploy(implementation.address) as VaultProxy;
  const vaultImplV1 = new BaseContract(
    vaultProxy.address,
    VaultV1__factory.createInterface(),
    vaultProxy.signer,
  ) as VaultV1;
  const vaultImplV2 = new BaseContract(
    vaultProxy.address,
    VaultV2__factory.createInterface(),
    vaultProxy.signer,
  ) as VaultV2;

  await vaultImplV1.initializeVault(core.storage.address, underlying.address, '990', '1000');

  return [vaultProxy, vaultImplV1, vaultImplV2]
}

type PotPoolType = IPotPool | PotPoolV1

/**
 * @return  The deployed strategy proxy and the implementation contract at the proxy's address
 */
export async function createPotPool<T extends PotPoolType>(
  implementation: PotPoolType,
  rewardTokens: string[],
  lpToken: string,
  duration: number,
  rewardDistribution: string[],
  storage: string,
): Promise<[NonUpgradableProxy, T]> {
  const NonUpgradableProxyFactory = await ethers.getContractFactory('NonUpgradableProxy');
  const potPoolProxy = await NonUpgradableProxyFactory.deploy(implementation.address) as NonUpgradableProxy;
  const potPoolImpl = new BaseContract(potPoolProxy.address, implementation.interface, potPoolProxy.signer) as T;

  await potPoolImpl.initializePotPool(
    rewardTokens,
    lpToken,
    duration,
    rewardDistribution,
    storage,
  );

  return [potPoolProxy, potPoolImpl]
}

export async function setupDAIBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  const whaleSigner = await impersonate(DaiWhaleAddress);
  await DAI.connect(whaleSigner).transfer(signer.address, amount);
  await DAI.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupGOHMBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  const whaleSigner = await impersonate(GOhmWhaleAddress);
  await G_OHM.connect(whaleSigner).transfer(signer.address, amount);
  await G_OHM.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupMAGICBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  const whaleSigner = await impersonate(MagicWhaleAddress);
  await MAGIC.connect(whaleSigner).transfer(signer.address, amount);
  await MAGIC.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupMIMBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  const whaleSigner = await impersonate(MimWhaleAddress);
  await MIM.connect(whaleSigner).transfer(signer.address, amount);
  await MIM.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupSPELLBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  const whaleSigner = await impersonate(SpellWhaleAddress);
  await SPELL.connect(whaleSigner).transfer(signer.address, amount);
  await SPELL.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupSUSHIBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  const whaleSigner = await impersonate(SushiWhaleAddress);
  await SUSHI.connect(whaleSigner).transfer(signer.address, amount);
  await SUSHI.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupUSDCBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  const whaleSigner = await impersonate(UsdcWhaleAddress);
  await USDC.connect(whaleSigner).transfer(signer.address, amount);
  await USDC.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupUSDTBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  const whaleSigner = await impersonate(UsdtWhaleAddress);
  await USDT.connect(whaleSigner).transfer(signer.address, amount);
  await USDT.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupWBTCBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  let whaleSigner = await impersonate(WbtcWhaleAddress1);
  if ((await WBTC.connect(whaleSigner).balanceOf(whaleSigner.address)).eq('0')) {
    whaleSigner = await impersonate(WbtcWhaleAddress2);
  }
  await WBTC.connect(whaleSigner).transfer(signer.address, amount);
  await WBTC.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

export async function setupWETHBalance(signer: SignerWithAddress, amount: BigNumberish, spender: { address: string }) {
  await WETH.connect(signer).deposit({ value: amount });
  await WETH.connect(signer).approve(spender.address, ethers.constants.MaxUint256);
}

type VaultType = IVault | VaultV1 | VaultV2;

type BaseContractWithApprove = BaseContract & {
  approve: (
    spender: string,
    amount: BigNumberish,
    overrides?: Overrides & { from?: string | Promise<string> },
  ) => Promise<ContractTransaction>
};

export async function depositIntoVault(
  farmer: SignerWithAddress,
  underlying: BaseContractWithApprove,
  vault: VaultType,
  amount: BigNumber,
) {
  const balanceBefore = await vault.underlyingBalanceWithInvestmentForHolder(farmer.address);
  await (underlying.connect(farmer) as BaseContractWithApprove).approve(vault.address, ethers.constants.MaxUint256);
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
  await tokenIn.connect(user).approve(core.universalLiquidator.address, ethers.constants.MaxUint256);
  return core.universalLiquidator.connect(user).callStatic.swapTokens(
    tokenIn.address,
    core.controllerParams.targetToken.address,
    rewardAmount,
    '1',
    core.rewardForwarder.address,
  );
}

export async function doHardWork(
  core: CoreProtocol,
  vault: IVault | VaultV1 | VaultV2,
  strategyProxy: StrategyProxy,
): Promise<ContractTransaction> {
  const vaultERC20 = new BaseContract(vault.address, VaultV1__factory.createInterface(), vault.signer) as VaultV1;
  const hint = ethers.BigNumber.from('10').pow(await vaultERC20.decimals());
  const result = await core.controller.connect(core.governance).doHardWork(
    vault.address,
    hint,
    '101',
    '100',
    { gasLimit: '5000000' }
  );
  await checkSharePriceLogChange(vault, core, result, strategyProxy, hint)

  return result;
}

export async function checkHardWorkResults(
  core: CoreProtocol,
  receivedTargetAmount: BigNumber,
) {
  const target = core.controllerParams.targetToken.connect(core.governance);
  const originalProfitSharingReceiverBalance = await target.balanceOf(
    core.profitSharingReceiver.address,
    { blockTag: core.blockNumber },
  );
  const originalStrategistBalance = await target.balanceOf(
    core.strategist.address,
    { blockTag: core.blockNumber },
  );
  const originalGovernanceBalance = await target.balanceOf(
    core.governance.address,
    { blockTag: core.blockNumber },
  );

  expect(await target.balanceOf(core.profitSharingReceiver.address))
    .to
    .be
    .gte(originalProfitSharingReceiverBalance.add(receivedTargetAmount.mul('15').div('100')));

  expect(await target.balanceOf(core.strategist.address))
    .to
    .be
    .gte(originalStrategistBalance.add(receivedTargetAmount.mul('5').div('100')));

  expect(await target.balanceOf(core.governance.address))
    .to
    .be
    .gte(originalGovernanceBalance.add(receivedTargetAmount.mul('5').div('100')));
}

export function logYieldData(
  strategyName: string,
  lpBalance1: BigNumber,
  lpBalance2: BigNumber,
  waitDurationSeconds: number,
) {
  const balanceDelta = lpBalance2.sub(lpBalance1);
  const apr = calculateApr(lpBalance2, lpBalance1, waitDurationSeconds);
  const apy = calculateApy(lpBalance2, lpBalance1, waitDurationSeconds);

  console.log(`\t${strategyName} Underlying Before`, lpBalance1.toString(), `(${formatNumber(lpBalance1)})`);
  console.log(`\t${strategyName} Underlying After`, lpBalance2.toString(), `(${formatNumber(lpBalance2)})`);
  console.log(`\t${strategyName} Underlying Earned`, balanceDelta.toString(), `(${formatNumber(balanceDelta)})`);
  console.log(`\t${strategyName} Underlying APR`, `${formatNumber(apr.mul(100))}%`);
  console.log(`\t${strategyName} Underlying APY`, `${formatNumber(apy.mul(100))}%`);
}

export async function checkSharePriceLogChange(
  vault: IVault | VaultV1 | VaultV2,
  core: CoreProtocol,
  result: ContractTransaction,
  strategyProxy: StrategyProxy,
  hint: BigNumberish,
) {
  const priceFullShare = await vault.getPricePerFullShare();
  const latestTimestamp = await getLatestTimestamp();

  await expect(result).to.emit(core.controller, 'SharePriceChangeLog')
    .withArgs(vault.address, strategyProxy.address, hint, priceFullShare, latestTimestamp);
  expect(priceFullShare).to.be.gt(hint);
}

