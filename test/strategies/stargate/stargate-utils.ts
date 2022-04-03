import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BaseContract, BigNumber, BigNumberish } from 'ethers';
import { IStargateFarmingPool } from '../../../src/types';

export async function rewardPoolBalanceOf(
  rewardPool: IStargateFarmingPool,
  rewardPid: BigNumberish,
  user: BaseContract | SignerWithAddress,
): Promise<BigNumber> {
  return (await rewardPool.userInfo(rewardPid, user.address)).balance
}
