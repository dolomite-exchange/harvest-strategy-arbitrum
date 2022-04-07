import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { IStargateFarmingPool, IVault, StrategyProxy, UsdcStargateStrategyMainnet, VaultV1 } from '../../../src/types';
import {
  STARGATE_REWARD_POOL,
  STARGATE_ROUTER,
  STARGATE_S_USDC,
  STG,
  StgWhaleAddress,
  USDC,
} from '../../../src/utils/constants';
import {
  checkHardWorkResults,
  CoreProtocol,
  CoreProtocolSetupConfigV2,
  createStrategy,
  createVault,
  depositIntoVault,
  doHardWork,
  getReceivedAmountBeforeHardWork,
  logYieldData,
  setupCoreProtocol,
  setupUSDCBalance,
} from '../../../src/utils/harvest-utils';
import {
  calculateApr,
  calculateApy,
  getLatestBlockNumber,
  impersonate,
  revertToSnapshotAndCapture,
  snapshot,
} from '../../../src/utils/utils';
import { rewardPoolBalanceOf } from './stargate-utils';

const strategyName = 'UsdcStargate';
describe(strategyName, () => {

  let core: CoreProtocol;
  let strategyProxy: StrategyProxy;
  let strategyMainnet: UsdcStargateStrategyMainnet;
  let vaultV1: VaultV1;
  let rewardPool: IStargateFarmingPool;

  let user: SignerWithAddress;

  let snapshotId: string;

  const underlyingToken = STARGATE_S_USDC;
  const poolId = 1;
  const rewardPid = 0;

  before(async () => {
    core = await setupCoreProtocol({
      ...CoreProtocolSetupConfigV2,
      blockNumber: 8958750,
    });
    [strategyProxy, strategyMainnet] = await createStrategy<UsdcStargateStrategyMainnet>('UsdcStargateStrategyMainnet');

    const VaultV1Factory = await ethers.getContractFactory('VaultV1');
    const vaultImplementation = await VaultV1Factory.deploy() as IVault;
    [, vaultV1] = await createVault(vaultImplementation, core, underlyingToken);
    await strategyMainnet.connect(core.governance)
      .initializeMainnetStrategy(core.storage.address, vaultV1.address, core.strategist.address);
    await core.controller.connect(core.governance).addVaultAndStrategy(vaultV1.address, strategyProxy.address);

    user = await ethers.getSigner(core.hhUser1.address);
    rewardPool = STARGATE_REWARD_POOL.connect(core.governance);

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#deployment', () => {
    it('should work properly', async () => {
      expect(await strategyMainnet.controller()).to.eq(core.controller.address);
      expect(await strategyMainnet.governance()).to.eq(core.governance.address);
      expect(await strategyMainnet.underlying()).to.eq(underlyingToken.address);
      expect(await strategyMainnet.vault()).to.eq(vaultV1.address);
      expect(await strategyMainnet.rewardPool()).to.eq(rewardPool.address);
      expect(await strategyMainnet.rewardTokens()).to.eql([STG.address]);
      expect(await strategyMainnet.strategist()).to.eq(core.strategist.address);
      expect(await strategyMainnet.depositToken()).to.eq(USDC.address);
      expect(await strategyMainnet.stargatePoolId()).to.eq(poolId);
      expect(await strategyMainnet.stargateRewardPid()).to.eq(rewardPid);
      expect(await strategyMainnet.stargateRouter()).to.eq(STARGATE_ROUTER.address);
    });
  });

  describe('deposit and compound', () => {
    it('should work', async () => {
      const usdcAmount = ethers.BigNumber.from('5000000000'); // 5,000 USDC
      await setupUSDCBalance(user, usdcAmount, STARGATE_ROUTER);
      await STARGATE_ROUTER.connect(user).addLiquidity(poolId, usdcAmount, user.address);

      const lpBalance1 = await underlyingToken.connect(user).balanceOf(user.address);
      await depositIntoVault(user, underlyingToken, vaultV1, lpBalance1);

      await vaultV1.connect(core.governance).rebalance(); // move funds to the strategy
      await strategyMainnet.connect(core.governance).enterRewardPool(); // deposit strategy funds into the reward pool

      const lpBalanceAfterFees = lpBalance1.mul('990').div('1000');
      expect(await rewardPoolBalanceOf(rewardPool, rewardPid, strategyProxy)).to.eq(lpBalanceAfterFees);

      expect(await strategyMainnet.callStatic.getRewardPoolValues()).to.eql([ethers.constants.Zero]);

      const waitDurationSeconds = 86400; // 1 day in seconds
      const oneDayEthereumBlocks = 7200;

      const latestBlockNumber = await getLatestBlockNumber();

      let poolInfo = await rewardPool.poolInfo(rewardPid);
      const poolInfoStorageSlot = '111414077815863400510004064629973595961579173665589224203503662149373724986687';
      const storageAt = await ethers.provider.send('eth_getStorageAt', [
        rewardPool.address,
        ethers.BigNumber.from(poolInfoStorageSlot).add((rewardPid * 4) + 2).toHexString(),
      ]);
      const storageLastRewardBlock = ethers.BigNumber.from(storageAt.toString());
      expect(poolInfo.lastRewardBlock).to.eq(storageLastRewardBlock);

      // upon hard forking Arbitrum Mainnet, the block # works "normally" so we need to set the value in the mapping to
      // the current block, minus one day, so it moves forward
      await ethers.provider.send('hardhat_setStorageAt', [
        rewardPool.address,
        ethers.BigNumber.from(poolInfoStorageSlot).add((rewardPid * 4) + 2).toHexString(),
        ethers.utils.defaultAbiCoder.encode(['uint256'], [latestBlockNumber - oneDayEthereumBlocks]),
      ]);
      poolInfo = await rewardPool.poolInfo(rewardPid);
      expect(poolInfo.lastRewardBlock).to.eq(latestBlockNumber - oneDayEthereumBlocks);

      const stgReward = (await strategyMainnet.callStatic.getRewardPoolValues())[0];
      const stgWhale = await impersonate(StgWhaleAddress);
      const receivedETH = await getReceivedAmountBeforeHardWork(core, stgWhale, STG, stgReward);

      await doHardWork(core, vaultV1, strategyProxy);

      const lpBalance2 = await vaultV1.underlyingBalanceWithInvestment();

      const amountHeldInVault = lpBalance1.sub(lpBalance1.mul('990').div('1000'));
      expect(await rewardPoolBalanceOf(rewardPool, rewardPid, strategyProxy)).to.eq(lpBalance2.sub(amountHeldInVault));

      logYieldData(strategyName, lpBalance1, lpBalance2, waitDurationSeconds);

      const expectedApr = ethers.BigNumber.from('140000000000000000'); // 14%
      const expectedApy = ethers.BigNumber.from('150000000000000000'); // 15%

      expect(lpBalance2).to.be.gt(lpBalance1);
      expect(calculateApr(lpBalance2, lpBalance1, waitDurationSeconds)).to.be.gt(expectedApr);
      expect(calculateApy(lpBalance2, lpBalance1, waitDurationSeconds)).to.be.gt(expectedApy);

      // check the platform fee and strategist fees accrued properly
      await checkHardWorkResults(core, receivedETH);
    });
  });
});
