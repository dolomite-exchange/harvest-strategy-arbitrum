// Utilities
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { PotPoolV1, TestToken } from '../../src/types';
import { PotPoolV1Implementation, StorageAddress } from '../../src/utils/constants';
import {
  CoreProtocol,
  CoreProtocolSetupConfigV2,
  createPotPool,
  setupCoreProtocol,
} from '../../src/utils/harvest-utils';
import { DefaultBlockNumber } from '../../src/utils/no-deps-constants';
import { getLatestTimestamp, revertToSnapshotAndCapture, snapshot, waitDays } from '../../src/utils/utils';

describe('PotPoolV1', () => {

  let core: CoreProtocol;
  let rewardPool: PotPoolV1;
  let rewardToken1: TestToken;
  let rewardToken2: TestToken;
  let lpToken: TestToken;
  let snapshotId: string;

  const rewardAmount1 = ethers.BigNumber.from('100000000000000000000'); // 100

  before(async () => {
    core = await setupCoreProtocol(CoreProtocolSetupConfigV2);

    rewardToken1 = await (await ethers.getContractFactory('TestToken')).deploy('DAI', 'DAI', 18) as TestToken
    rewardToken2 = await (await ethers.getContractFactory('TestToken')).deploy('FARM', 'FARM', 18) as TestToken
    lpToken = await (await ethers.getContractFactory('TestToken')).deploy('WETH', 'WETH', 18) as TestToken
    [, rewardPool] = await createPotPool<PotPoolV1>(
      PotPoolV1Implementation,
      [rewardToken1.address],
      lpToken.address,
      86400 * 7,
      [core.governance.address],
      StorageAddress,
    );

    await lpToken.connect(core.hhUser1).mint(core.hhUser1.address, '10000000000000000000');
    await lpToken.connect(core.hhUser1).approve(rewardPool.address, ethers.constants.MaxUint256);
    await lpToken.connect(core.hhUser2).mint(core.hhUser2.address, '10000000000000000000');
    await lpToken.connect(core.hhUser2).approve(rewardPool.address, ethers.constants.MaxUint256);

    await rewardToken1.mint(rewardPool.address, rewardAmount1);
    await rewardPool.connect(core.governance).notifyTargetRewardAmount(rewardToken1.address, rewardAmount1);

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#getRewardTokens', () => {
    it('should work', async () => {
      expect(await rewardPool.getRewardTokens()).to.eql([rewardToken1.address])
    });
  });

  describe('#governance', () => {
    it('should work', async () => {
      expect(await rewardPool.governance()).to.eq(core.governance.address)
    });
  });

  describe('#addRewardToken', () => {
    it('should work when called by governance', async () => {
      await rewardPool.connect(core.governance).addRewardToken(rewardToken2.address);
      expect(await rewardPool.getRewardTokenIndex(rewardToken2.address)).to.eq(1)
    });
    it('should not work when not called by governance', async () => {
      await expect(rewardPool.connect(core.hhUser1).addRewardToken(rewardToken2.address))
        .to
        .be
        .revertedWith('Not governance')
    });
    it('should not work when duplicate token is added', async () => {
      await expect(rewardPool.connect(core.governance).addRewardToken(rewardToken1.address))
        .to
        .be
        .revertedWith('Reward token already exists')
    });
  });

  describe('#removeRewardToken', () => {
    it('should work when called by governance', async () => {
      await waitDays(365);
      await rewardPool.connect(core.governance).addRewardToken(rewardToken2.address);
      await rewardPool.connect(core.governance).removeRewardToken(rewardToken1.address);
      expect(await rewardPool.getRewardTokenIndex(rewardToken1.address)).to.eq(ethers.constants.MaxUint256)
    });
    it('should not work when not called by governance', async () => {
      await expect(rewardPool.connect(core.hhUser1).removeRewardToken(rewardToken1.address))
        .to
        .be
        .revertedWith('Not governance')
    });
    it('should not work when token is not already added', async () => {
      await expect(rewardPool.connect(core.governance).removeRewardToken(rewardToken2.address))
        .to
        .be
        .revertedWith('Reward token does not exists')
    });
    it('should not work when token reward period is active', async () => {
      await expect(rewardPool.connect(core.governance).removeRewardToken(rewardToken1.address))
        .to
        .be
        .revertedWith('Can only remove when the reward period has passed')
    });
    it('should not work when token is the last reward token', async () => {
      await waitDays(365);
      await expect(rewardPool.connect(core.governance).removeRewardToken(rewardToken1.address))
        .to
        .be
        .revertedWith('Cannot remove the last reward token')
    });
  });

  describe('#lastTimeRewardApplicable', () => {
    it('should work for default case', async () => {
      await rewardPool.connect(core.governance).addRewardToken(rewardToken2.address);
      expect(await rewardPool['lastTimeRewardApplicable(address)'](rewardToken2.address)).to.eq('0')
      expect(await rewardPool['lastTimeRewardApplicable(uint256)'](1)).to.eq('0')
    });
    it('should work when data is initialized', async () => {
      const lastTimestamp = await getLatestTimestamp();
      expect(await rewardPool['lastTimeRewardApplicable(address)'](rewardToken1.address)).to.eq(lastTimestamp);
      expect(await rewardPool['lastTimeRewardApplicable(uint256)'](0)).to.eq(lastTimestamp);
      await waitDays(365);
      const totalTimestamp = lastTimestamp + (86400 * 7);
      expect(await rewardPool['lastTimeRewardApplicable(address)'](rewardToken1.address)).to.eq(totalTimestamp);
      expect(await rewardPool['lastTimeRewardApplicable(uint256)'](0)).to.eq(totalTimestamp);
    });
  });

  describe('#rewardPerToken', () => {
    it('should work for default case', async () => {
      expect(await rewardPool['rewardPerToken(address)'](rewardToken1.address)).to.eq('0')
      expect(await rewardPool['rewardPerToken(uint256)'](0)).to.eq('0')
    });
  });

  describe('#earned', () => {
    it('should work for default case', async () => {
      expect(await rewardPool['earned(address,address)'](rewardToken1.address, core.hhUser1.address)).to.eq('0')
      expect(await rewardPool['earned(uint256,address)'](0, core.hhUser1.address)).to.eq('0')
    });
  });

  describe('#multiple', () => {
    it('should work for default case', async () => {
      const amount1 = ethers.BigNumber.from('100000000000000000'); // 0.1
      await rewardPool.connect(core.hhUser1).stake(amount1);
      expect(await rewardPool.stakedBalanceOf(core.hhUser1.address)).to.eq(amount1);
      expect(await rewardPool.stakedBalanceOf(core.hhUser2.address)).to.eq(0);
      expect(await rewardPool.totalSupply()).to.eq(amount1);

      await waitDays(1);
      const earned = await rewardPool['earned(uint256,address)'](0, core.hhUser1.address);
      expect(earned).to.eq('14285879629629599915'); // approximately 1/7th of the rewards

      const amount2 = amount1.mul(2); // 0.2
      await rewardPool.connect(core.hhUser2).stake(amount2);
      expect(await rewardPool.stakedBalanceOf(core.hhUser1.address)).to.eq(amount1);
      expect(await rewardPool.stakedBalanceOf(core.hhUser2.address)).to.eq(amount2);
      expect(await rewardPool.totalSupply()).to.eq(amount1.add(amount2));

      await waitDays(2);
      await rewardPool.connect(core.hhUser1).withdraw(amount1);
      expect(await rewardPool.stakedBalanceOf(core.hhUser1.address)).to.eq(0);

      expect(await rewardToken1.balanceOf(core.hhUser1.address)).to.eq(0);
      expect(await rewardToken1.balanceOf(core.hhUser2.address)).to.eq(0);

      await rewardPool.connect(core.hhUser1).getAllRewards();
      expect(await rewardToken1.balanceOf(core.hhUser1.address)).to.not.eq(0);
      expect(await rewardToken1.balanceOf(core.hhUser2.address)).to.eq(0);

      await rewardPool.connect(core.hhUser2).exit();
      expect(await rewardPool.stakedBalanceOf(core.hhUser2.address)).to.eq(0);
      expect(await rewardToken1.balanceOf(core.hhUser2.address)).to.not.eq(0);
    });
  })
});
