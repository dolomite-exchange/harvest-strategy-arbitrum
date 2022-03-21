pragma solidity ^0.5.16;


interface CrvRewardNotifier {

    function notify_reward_amount(address _rewardToken) external;
}
