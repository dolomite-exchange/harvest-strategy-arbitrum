pragma solidity ^0.5.16;


interface IGauge {

    function lp_token() external view returns (address);

    function balanceOf(address user) external view returns (uint);

    function claimable_reward(address user, address token) external view returns (uint);

    function claimable_reward_write(address _addr, address _token) external returns (uint256);

    function deposit(uint value) external;

    function withdraw(uint value) external;

    function claim_rewards() external;
}
