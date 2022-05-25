import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BaseContract, BigNumber, BigNumberish } from 'ethers';
import { IMiniChefV2 } from '../../../src/types';

export async function rewardPoolBalanceOf(
  rewardPool: IMiniChefV2,
  pid: BigNumberish,
  user: BaseContract | SignerWithAddress,
): Promise<BigNumber> {
  return (await rewardPool.userInfo(pid, user.address))._balance
}
