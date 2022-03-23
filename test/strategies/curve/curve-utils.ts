import { CRV, CRV_REWARD_NOTIFIER } from '../../../src/utils/constants';
import { CoreProtocol } from '../../../src/utils/harvest-utils';
import { getLatestTimestamp, waitTime } from '../../../src/utils/utils';

/**
 * @return The time waited for the rewards to deplete
 */
export async function waitForRewardsToDeplete(core: CoreProtocol): Promise<number> {
  const rewardData = await CRV_REWARD_NOTIFIER.connect(core.hhUser1).reward_data(CRV.address);
  const latestTimestamp = await getLatestTimestamp();
  const waitDurationSeconds = rewardData.period_finish.sub(latestTimestamp).add(1).toNumber();
  await waitTime(waitDurationSeconds);
  return waitDurationSeconds;
}
