// Utilities
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BaseContract } from 'ethers';
import { ethers } from 'hardhat';
import { IUniversalLiquidatorV1, IUniversalLiquidatorV2, Storage, UniversalLiquidatorProxy } from '../../src/types';
import { BALANCER_VAULT, STG, StgWhaleAddress, USDC, WETH } from '../../src/utils/constants';
import { CoreProtocolSetupConfigV1, setupCoreProtocol } from '../../src/utils/harvest-utils';
import { impersonate, revertToSnapshotAndCapture, snapshot } from '../../src/utils/utils';

/**
 * Tests deployment of `Storage`, `Controller`, `RewardForwarder`, `UniversalLiquidator(Proxy)`
 */
describe('UniversalLiquidatorV2', () => {

  let governance: SignerWithAddress;
  let hhUser1: SignerWithAddress;
  let storage: Storage;
  let universalLiquidatorProxy: UniversalLiquidatorProxy;
  let universalLiquidator: IUniversalLiquidatorV1 | IUniversalLiquidatorV2;

  let snapshotId: string;


  before(async () => {
    const coreProtocol = await setupCoreProtocol({
      ...CoreProtocolSetupConfigV1,
      blockNumber: 8945600,
    });
    governance = coreProtocol.governance;
    hhUser1 = coreProtocol.hhUser1;
    storage = coreProtocol.storage;
    universalLiquidatorProxy = coreProtocol.universalLiquidatorProxy;
    universalLiquidator = coreProtocol.universalLiquidator;

    snapshotId = await snapshot();
  })

  beforeEach(async () => {
    snapshotId = await revertToSnapshotAndCapture(snapshotId);
  });

  describe('#scheduleUpgrade', () => {
    it('should work properly and upgrade to v2', async () => {
      const nextUniversalLiquidator = await performUpgrade();

      expect(await nextUniversalLiquidator.getExtraData(BALANCER_VAULT.address, STG.address, USDC.address))
        .to
        .eq('0x3a4c6d2404b5eb14915041e01f63200a82f4a343000200000000000000000065');

      expect(await nextUniversalLiquidator.getExtraData(BALANCER_VAULT.address, USDC.address, STG.address))
        .to
        .eq('0x');
    });

    it('should fail if not called by governance', async () => {
      expect(await universalLiquidator.nextImplementation()).to.eq(ethers.constants.AddressZero);
      const universalLiquidatorImplementation = await universalLiquidatorProxy.implementation();
      await expect(universalLiquidator.connect(hhUser1).scheduleUpgrade(universalLiquidatorImplementation))
        .to.be.revertedWith('Not governance');
    })
  });

  describe('#swapTokens', () => {
    it('should work for balancer', async () => {
      const liquidatorV2 = await performUpgrade();
      const stgWhale = await impersonate(StgWhaleAddress);
      const amountIn = ethers.BigNumber.from('1000000000000000000');
      const usdcAmountOutMin = '3000000';
      await STG.connect(stgWhale).approve(liquidatorV2.address, amountIn.mul(2));

      const usdcBalanceBefore = await USDC.connect(hhUser1).balanceOf(hhUser1.address);
      await liquidatorV2.connect(stgWhale).swapTokens(
        STG.address,
        USDC.address,
        amountIn,
        usdcAmountOutMin,
        hhUser1.address,
      );

      const usdcBalanceAfter = await USDC.connect(hhUser1).balanceOf(hhUser1.address);
      expect(usdcBalanceAfter.sub(usdcBalanceBefore)).to.be.gt(usdcAmountOutMin);

      // 1 ETH = ~$3400. $3/3400 == ~0.00088
      const wethAmountOutMin = '880000000000000';
      const wethBalanceBefore = await WETH.connect(hhUser1).balanceOf(hhUser1.address);
      await liquidatorV2.connect(stgWhale).swapTokens(
        STG.address,
        WETH.address,
        amountIn,
        wethAmountOutMin,
        hhUser1.address,
      );

      const wethBalanceAfter = await WETH.connect(hhUser1).balanceOf(hhUser1.address);
      expect(wethBalanceAfter.sub(wethBalanceBefore)).to.be.gt(wethAmountOutMin);
    });
  })

  async function performUpgrade(): Promise<IUniversalLiquidatorV2> {
    expect(await universalLiquidator.nextImplementation()).to.eq(ethers.constants.AddressZero);

    const UniversalLiquidatorV2Factory = await ethers.getContractFactory('UniversalLiquidatorV2');
    const universalLiquidatorV2 = await UniversalLiquidatorV2Factory.deploy();
    await universalLiquidator.connect(governance).scheduleUpgrade(universalLiquidatorV2.address);
    expect(await universalLiquidator.nextImplementation()).to.eq(universalLiquidatorV2.address);

    await universalLiquidatorProxy.connect(governance).upgrade();

    expect(await universalLiquidator.nextImplementation()).to.eq(ethers.constants.AddressZero);
    expect(await universalLiquidatorProxy.implementation()).to.eq(universalLiquidatorV2.address);

    return new BaseContract(
      universalLiquidator.address,
      universalLiquidatorV2.interface,
      universalLiquidator.signer,
    ) as IUniversalLiquidatorV2
  }
});
