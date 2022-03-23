import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { IGauge, IVault, RenWbtcPoolStrategyMainnet, StrategyProxy, VaultV1 } from '../../../src/types';
import { CRV, CRV_REN_WBTC_POOL, CRV_REN_WBTC_POOL_GAUGE, CrvWhaleAddress, WBTC } from '../../../src/utils/constants';
import {
  checkHardWorkResults,
  CoreProtocol,
  createStrategy,
  createVault,
  DefaultCoreProtocolSetupConfig,
  depositIntoVault,
  doHardWork,
  getReceivedAmountBeforeHardWork,
  logYieldData,
  setupCoreProtocol,
  setupWBTCBalance,
} from '../../../src/utils/harvest-utils';
import { calculateApr, calculateApy, impersonate, revertToSnapshotAndCapture, snapshot } from '../../../src/utils/utils';
import { waitForRewardsToDeplete } from './curve-utils';

const strategyName = 'RenWbtcPoolStrategy';
describe(strategyName, () => {

  let core: CoreProtocol;
  let strategyProxy: StrategyProxy;
  let strategyMainnet: RenWbtcPoolStrategyMainnet;
  let vaultV1: VaultV1;
  let gauge: IGauge;

  let user: SignerWithAddress;

  let snapshotId: string;

  before(async () => {
    core = await setupCoreProtocol(DefaultCoreProtocolSetupConfig);
    [strategyProxy, strategyMainnet] = await createStrategy<RenWbtcPoolStrategyMainnet>('RenWbtcPoolStrategyMainnet');

    const VaultV1Factory = await ethers.getContractFactory('VaultV1');
    const vaultImplementation = await VaultV1Factory.deploy() as IVault;
    [, vaultV1] = await createVault(vaultImplementation, core, CRV_REN_WBTC_POOL);
    await strategyMainnet.connect(core.governance)
      .initializeMainnetStrategy(core.storage.address, vaultV1.address, core.strategist.address);
    await core.controller.connect(core.governance).addVaultAndStrategy(vaultV1.address, strategyProxy.address);

    user = await ethers.getSigner(core.hhUser1.address);
    gauge = CRV_REN_WBTC_POOL_GAUGE.connect(core.governance);

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#deployment', () => {
    it('should work properly', async () => {
      expect(await strategyMainnet.controller()).to.eq(core.controller.address);
      expect(await strategyMainnet.governance()).to.eq(core.governance.address);
      expect(await strategyMainnet.underlying()).to.eq(CRV_REN_WBTC_POOL.address);
      expect(await strategyMainnet.vault()).to.eq(vaultV1.address);
      expect(await strategyMainnet.rewardPool()).to.eq(CRV_REN_WBTC_POOL_GAUGE.address);
      expect(await strategyMainnet.rewardTokens()).to.eql([CRV.address]);
      expect(await strategyMainnet.strategist()).to.eq(core.strategist.address);
      expect(await strategyMainnet.curveDepositPool()).to.eq(CRV_REN_WBTC_POOL.address);
      expect(await strategyMainnet.depositToken()).to.eq(WBTC.address);
      expect(await strategyMainnet.depositArrayPosition()).to.eq(0);
    });
  });

  describe('deposit and compound', () => {
    it('should work', async () => {
      const wbtcAmount = ethers.BigNumber.from('10000000'); // 0.1 WBTC
      await setupWBTCBalance(user, wbtcAmount, CRV_REN_WBTC_POOL);
      await CRV_REN_WBTC_POOL.connect(user).add_liquidity([wbtcAmount, 0], '0');

      const lpBalance1 = await CRV_REN_WBTC_POOL.connect(user).balanceOf(user.address);
      await depositIntoVault(user, CRV_REN_WBTC_POOL, vaultV1, lpBalance1);

      await vaultV1.connect(core.governance).rebalance(); // move funds to the strategy
      await strategyMainnet.connect(core.governance).enterRewardPool(); // deposit strategy funds into CRV

      const lpBalanceAfterFees = lpBalance1.mul('995').div('1000');
      expect(await gauge.balanceOf(strategyProxy.address)).to.eq(lpBalanceAfterFees);

      expect(await strategyMainnet.callStatic.getRewardPoolValues()).to.eql([ethers.constants.Zero]);

      const waitDurationSeconds = await waitForRewardsToDeplete(core);

      const crvReward = (await strategyMainnet.callStatic.getRewardPoolValues())[0];
      const crvWhale = await impersonate(CrvWhaleAddress);
      const receivedWBTC = await getReceivedAmountBeforeHardWork(core, crvWhale, CRV, crvReward);

      await doHardWork(core, vaultV1, strategyProxy);

      const lpBalance2 = await vaultV1.underlyingBalanceWithInvestment();

      const amountHeldInVault = lpBalance1.sub(lpBalance1.mul('995').div('1000'));
      expect(await gauge.balanceOf(strategyProxy.address)).to.eq(lpBalance2.sub(amountHeldInVault));

      logYieldData(strategyName, lpBalance1, lpBalance2, waitDurationSeconds);

      const expectedApr = ethers.BigNumber.from('11100000000000000'); // 1.110%
      const expectedApy = ethers.BigNumber.from('11160000000000000'); // 1.116%

      expect(lpBalance2).to.be.gt(lpBalance1);
      expect(calculateApr(lpBalance2, lpBalance1, waitDurationSeconds)).to.be.gt(expectedApr);
      expect(calculateApy(lpBalance2, lpBalance1, waitDurationSeconds)).to.be.gt(expectedApy);

      // check the platform fee and strategist fees accrued properly
      await checkHardWorkResults(core, receivedWBTC);
    });
  });
});
