pragma solidity ^0.5.16;


interface ICrvRewardNotifier {

    function notify_reward_amount(address _rewardToken) external;

    function reward_data(address _rewardToken) external view returns (
        address distributor,
        uint256 period_finish,
        uint256 rate,
        uint256 duration,
        uint256 received,
        uint256 paid
    );
}
