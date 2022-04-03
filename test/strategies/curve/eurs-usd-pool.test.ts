import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { EursUsdPoolStrategyMainnet, IGauge, IVault, StrategyProxy, VaultV1 } from '../../../src/types';
import {
  CRV,
  CRV_EURS_USD_POOL,
  CRV_EURS_USD_POOL_GAUGE,
  CRV_EURS_USD_TOKEN,
  CRV_TWO_POOL,
  CrvWhaleAddress,
  USDC,
} from '../../../src/utils/constants';
import {
  checkHardWorkResults,
  CoreProtocol,
  createStrategy,
  createVault,
  CoreProtocolSetupConfigV1,
  depositIntoVault,
  doHardWork,
  getReceivedAmountBeforeHardWork,
  logYieldData,
  setupCoreProtocol,
  setupUSDCBalance,
} from '../../../src/utils/harvest-utils';
import { calculateApr, calculateApy, impersonate, revertToSnapshotAndCapture, snapshot } from '../../../src/utils/utils';
import { waitForRewardsToDeplete } from './curve-utils';

const strategyName = 'EursUsdStrategy';
describe(strategyName, () => {

  let core: CoreProtocol;
  let strategyProxy: StrategyProxy;
  let strategyMainnet: EursUsdPoolStrategyMainnet;
  let vaultV1: VaultV1;
  let gauge: IGauge;

  let user: SignerWithAddress;

  let snapshotId: string;

  before(async () => {
    core = await setupCoreProtocol(CoreProtocolSetupConfigV1);
    [strategyProxy, strategyMainnet] = await createStrategy<EursUsdPoolStrategyMainnet>('EursUsdPoolStrategyMainnet');

    const VaultV1Factory = await ethers.getContractFactory('VaultV1');
    const vaultImplementation = await VaultV1Factory.deploy() as IVault;
    [, vaultV1] = await createVault(vaultImplementation, core, CRV_EURS_USD_TOKEN);
    await strategyMainnet.connect(core.governance)
      .initializeMainnetStrategy(core.storage.address, vaultV1.address, core.strategist.address);
    await core.controller.connect(core.governance).addVaultAndStrategy(vaultV1.address, strategyProxy.address);

    user = await ethers.getSigner(core.hhUser1.address);
    gauge = CRV_EURS_USD_POOL_GAUGE.connect(core.governance);

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#deployment', () => {
    it('should work properly', async () => {
      expect(await strategyMainnet.controller()).to.eq(core.controller.address);
      expect(await strategyMainnet.governance()).to.eq(core.governance.address);
      expect(await strategyMainnet.underlying()).to.eq(CRV_EURS_USD_TOKEN.address);
      expect(await strategyMainnet.vault()).to.eq(vaultV1.address);
      expect(await strategyMainnet.rewardPool()).to.eq(CRV_EURS_USD_POOL_GAUGE.address);
      expect(await strategyMainnet.rewardTokens()).to.eql([CRV.address]);
      expect(await strategyMainnet.strategist()).to.eq(core.strategist.address);
      expect(await strategyMainnet.curveDepositPool()).to.eq(CRV_TWO_POOL.address);
      expect(await strategyMainnet.depositToken()).to.eq(USDC.address);
      expect(await strategyMainnet.depositArrayPosition()).to.eq(0);
      expect(await strategyMainnet.wrapperCurveDepositPool()).to.eq(CRV_EURS_USD_POOL.address);
      expect(await strategyMainnet.wrapperDepositToken()).to.eq(CRV_TWO_POOL.address);
      expect(await strategyMainnet.wrapperDepositArrayPosition()).to.eq(1);
    });
  });

  describe('deposit and compound', () => {
    it('should work', async () => {
      const usdcAmount = ethers.BigNumber.from('5000000000'); // 5,000 USDC
      await setupUSDCBalance(user, usdcAmount, CRV_TWO_POOL);
      await CRV_TWO_POOL.connect(user).add_liquidity([usdcAmount, 0], '0');

      const twoPoolLpBalance = await CRV_TWO_POOL.connect(user).balanceOf(user.address);
      await CRV_TWO_POOL.connect(user).approve(CRV_EURS_USD_POOL.address, ethers.constants.MaxUint256);
      await CRV_EURS_USD_POOL.connect(user).add_liquidity([0, twoPoolLpBalance], '0');

      const lpBalance1 = await CRV_EURS_USD_TOKEN.connect(user).balanceOf(user.address);
      await depositIntoVault(user, CRV_EURS_USD_TOKEN, vaultV1, lpBalance1);

      await vaultV1.connect(core.governance).rebalance(); // move funds to the strategy
      await strategyMainnet.connect(core.governance).enterRewardPool(); // deposit strategy funds into CRV

      const lpBalanceAfterFees = lpBalance1.mul('995').div('1000');
      expect(await gauge.balanceOf(strategyProxy.address)).to.eq(lpBalanceAfterFees);

      expect(await strategyMainnet.callStatic.getRewardPoolValues()).to.eql([ethers.constants.Zero]);

      const waitDurationSeconds = await waitForRewardsToDeplete(core);

      const crvReward = (await strategyMainnet.callStatic.getRewardPoolValues())[0];
      const crvWhale = await impersonate(CrvWhaleAddress);
      const receivedUSDC = await getReceivedAmountBeforeHardWork(core, crvWhale, CRV, crvReward);

      await doHardWork(core, vaultV1, strategyProxy);

      const lpBalance2 = await vaultV1.underlyingBalanceWithInvestment();

      const amountHeldInVault = lpBalance1.sub(lpBalance1.mul('995').div('1000'));
      expect(await gauge.balanceOf(strategyProxy.address)).to.eq(lpBalance2.sub(amountHeldInVault));

      logYieldData(strategyName, lpBalance1, lpBalance2, waitDurationSeconds);

      const expectedApr = ethers.BigNumber.from('65000000000000000'); // 6.50%
      const expectedApy = ethers.BigNumber.from('67000000000000000'); // 6.70%

      expect(lpBalance2).to.be.gt(lpBalance1);
      expect(calculateApr(lpBalance2, lpBalance1, waitDurationSeconds)).to.be.gt(expectedApr);
      expect(calculateApy(lpBalance2, lpBalance1, waitDurationSeconds)).to.be.gt(expectedApy);

      // check the platform fee and strategist fees accrued properly
      await checkHardWorkResults(core, receivedUSDC);
    });
  });
});
